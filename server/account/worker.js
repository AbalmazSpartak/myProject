// Аккаунты WordLearner: вход по почте с одноразовым кодом, без пароля.
// POST /auth/request { email }        → письмо с 6-значным кодом (ответ всегда один и тот же)
// POST /auth/verify  { email, code }  → { token, email }
// GET  /me            (Bearer token)  → { email }
// POST /auth/logout   (Bearer token)  → выход на этом устройстве
// Каждый пользователь — своя база (Durable Object по хэшу почты); токен = «id.секрет», в базе только хэш секрета.
import { DurableObject } from "cloudflare:workers";

const CODE_TTL_MS = 10 * 60 * 1000;
const CODE_ATTEMPTS = 5;
const RESEND_GAP_MS = 30 * 1000;
const CODES_PER_HOUR = 5;
const MAX_SESSIONS = 10;
/// С одного адреса (IP) — не больше столько запросов кода в час: защита от рассылки чужим людям
const IP_PER_HOUR = 20;

function json(data, status = 200) {
  return new Response(JSON.stringify(data), { status, headers: { "content-type": "application/json" } });
}

async function sha256(text) {
  const bytes = new TextEncoder().encode(text);
  const hash = await crypto.subtle.digest("SHA-256", bytes);
  return [...new Uint8Array(hash)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

function randomHex(bytes) {
  return [...crypto.getRandomValues(new Uint8Array(bytes))].map((b) => b.toString(16).padStart(2, "0")).join("");
}

function normalizeEmail(value) {
  const email = String(value || "").trim().toLowerCase();
  if (email.length > 254 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) return null;
  return email;
}

/// Код из 6 цифр без перекоса: отбрасываем значения, на которых остаток давал бы неравные шансы
function randomCode() {
  const limit = 4294967296 - (4294967296 % 1000000);
  const buffer = new Uint32Array(1);
  do { crypto.getRandomValues(buffer); } while (buffer[0] >= limit);
  return String(buffer[0] % 1000000).padStart(6, "0");
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const path = url.pathname;
    const user = (id) => env.USER.get(env.USER.idFromName(id));

    if (request.method === "POST" && path === "/auth/request") {
      const body = await request.json().catch(() => ({}));
      const email = normalizeEmail(body.email);
      if (!email) return json({ error: "bad_email" }, 400);
      const ip = request.headers.get("CF-Connecting-IP") || "unknown";
      const gate = env.GATE.get(env.GATE.idFromName(ip));
      if (!(await gate.allow(IP_PER_HOUR))) return json({ error: "too_many" }, 429);
      if (!env.RESEND_API_KEY) return json({ error: "mail_not_configured" }, 503);
      const id = (await sha256(email)).slice(0, 32);
      const result = await user(id).requestCode(email);
      if (result.error) return json({ error: result.error, wait: result.wait }, 429);
      const sent = await sendMail(env, email, result.code);
      if (!sent) return json({ error: "mail_failed" }, 502);
      return json({ ok: true });
    }

    if (request.method === "POST" && path === "/auth/verify") {
      const body = await request.json().catch(() => ({}));
      const email = normalizeEmail(body.email);
      const code = String(body.code || "").trim();
      if (!email || !/^\d{6}$/.test(code)) return json({ error: "bad_code" }, 400);
      const id = (await sha256(email)).slice(0, 32);
      const result = await user(id).verify(await sha256(`${email}:${code}`));
      if (!result.ok) return json({ error: result.error }, 401);
      return json({ token: `${id}.${result.secret}`, email });
    }

    const token = (request.headers.get("authorization") || "").replace(/^Bearer /, "");
    const [id, secret] = token.split(".");
    if (path === "/me" || path === "/auth/logout") {
      if (!id || !secret || !/^[0-9a-f]{32}$/.test(id)) return json({ error: "unauthorized" }, 401);
      const stub = user(id);
      const hash = await sha256(secret);
      if (path === "/auth/logout") {
        if (request.method !== "POST") return json({ error: "method" }, 405);
        await stub.logout(hash);
        return json({ ok: true });
      }
      const me = await stub.me(hash);
      return me ? json(me) : json({ error: "unauthorized" }, 401);
    }
    return json({ ok: true, service: "wordlearner-account" });
  },
};

async function sendMail(env, email, code) {
  const response = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: { authorization: `Bearer ${env.RESEND_API_KEY}`, "content-type": "application/json" },
    body: JSON.stringify({
      from: env.MAIL_FROM,
      to: [email],
      subject: `Код входа WordLearner: ${code}`,
      text: `Ваш код входа: ${code}\n\nОн действует 10 минут. Если вы не входили в WordLearner, просто удалите это письмо.`,
    }),
  });
  return response.ok;
}

/// Счётчик запросов с одного адреса за час
export class Gate extends DurableObject {
  async allow(limit) {
    const now = Date.now();
    const stored = (await this.ctx.storage.get("hits")) || [];
    const hits = stored.filter((time) => now - time < 3600 * 1000);
    if (hits.length >= limit) return false;
    hits.push(now);
    await this.ctx.storage.put("hits", hits);
    return true;
  }
}

/// Один пользователь: коды входа и сессии (позже — данные синхронизации)
export class User extends DurableObject {
  constructor(ctx, env) {
    super(ctx, env);
    ctx.storage.sql.exec("CREATE TABLE IF NOT EXISTS codes (hash TEXT, expires INTEGER, attempts INTEGER, created INTEGER)");
    ctx.storage.sql.exec("CREATE TABLE IF NOT EXISTS sessions (hash TEXT PRIMARY KEY, created INTEGER, last INTEGER)");
    ctx.storage.sql.exec("CREATE TABLE IF NOT EXISTS profile (key TEXT PRIMARY KEY, value TEXT)");
  }

  async requestCode(email) {
    const sql = this.ctx.storage.sql;
    const now = Date.now();
    sql.exec("DELETE FROM codes WHERE expires < ?", now);
    const recent = sql.exec("SELECT created FROM codes WHERE created > ? ORDER BY created DESC", now - 3600 * 1000).toArray();
    if (recent.length >= CODES_PER_HOUR) return { error: "too_many" };
    if (recent[0] && now - recent[0].created < RESEND_GAP_MS) {
      return { error: "wait", wait: Math.ceil((RESEND_GAP_MS - (now - recent[0].created)) / 1000) };
    }
    const code = randomCode();
    sql.exec("INSERT INTO codes VALUES (?, ?, 0, ?)", await sha256(`${email}:${code}`), now + CODE_TTL_MS, now);
    sql.exec("INSERT OR REPLACE INTO profile VALUES ('email', ?)", email);
    return { code };
  }

  /// Новый код делает старые недействительными: проверяем только последний, лишние попытки сжигают его
  async verify(hash) {
    const sql = this.ctx.storage.sql;
    const now = Date.now();
    const row = sql.exec("SELECT rowid, hash, expires, attempts FROM codes WHERE expires > ? ORDER BY created DESC LIMIT 1", now).toArray()[0];
    if (!row) return { ok: false, error: "expired" };
    if (row.attempts >= CODE_ATTEMPTS) return { ok: false, error: "too_many" };
    if (row.hash !== hash) {
      sql.exec("UPDATE codes SET attempts = attempts + 1 WHERE rowid = ?", row.rowid);
      return { ok: false, error: "wrong" };
    }
    sql.exec("DELETE FROM codes");
    const secret = randomHex(32);
    sql.exec("INSERT INTO sessions VALUES (?, ?, ?)", await sha256(secret), now, now);
    // Старые сессии сверх лимита — выходят сами
    sql.exec("DELETE FROM sessions WHERE hash NOT IN (SELECT hash FROM sessions ORDER BY last DESC LIMIT ?)", MAX_SESSIONS);
    return { ok: true, secret };
  }

  me(hash) {
    const sql = this.ctx.storage.sql;
    const session = sql.exec("SELECT hash FROM sessions WHERE hash = ?", hash).toArray()[0];
    if (!session) return null;
    sql.exec("UPDATE sessions SET last = ? WHERE hash = ?", Date.now(), hash);
    const email = sql.exec("SELECT value FROM profile WHERE key = 'email'").toArray()[0];
    return { email: email ? email.value : null };
  }

  logout(hash) {
    this.ctx.storage.sql.exec("DELETE FROM sessions WHERE hash = ?", hash);
    return true;
  }
}
