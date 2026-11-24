// Аккаунты WordLearner: почта + пароль. Почту подтверждаем одноразовым кодом из письма.
// POST /auth/request  { email }                    → письмо с 6-значным кодом (ответ всегда один и тот же)
// POST /auth/verify   { email, code }              → { ticket } — разрешение задать пароль, 15 минут, один раз
// POST /auth/password { email, ticket, password }  → задаёт пароль (регистрация или сброс) и входит: { token, email }
// POST /auth/login    { email, password }          → { token, email }
// GET  /me            (Bearer token)               → { email }
// POST /me/password   (Bearer token) { old, password } → смена пароля, другие устройства выходят
// POST /auth/logout   (Bearer token)               → выход на этом устройстве
// Каждый пользователь — своя база (Durable Object по хэшу почты); токен = «id.секрет», в базе только хэш секрета;
// пароль — только хэш PBKDF2 с отдельной солью.
import { DurableObject } from "cloudflare:workers";

const CODE_TTL_MS = 10 * 60 * 1000;
const TICKET_TTL_MS = 15 * 60 * 1000;
const CODE_ATTEMPTS = 5;
const RESEND_GAP_MS = 30 * 1000;
const CODES_PER_HOUR = 5;
const MAX_SESSIONS = 10;
const LOGIN_ATTEMPTS = 5;
const LOGIN_LOCK_MS = 15 * 60 * 1000;
const MIN_PASSWORD = 8;
const MAX_PASSWORD = 200;
/// С одного адреса (IP) в час: письма — защита от рассылки чужим людям, входы — от перебора по многим почтам
const IP_MAIL_PER_HOUR = 20;
const IP_LOGIN_PER_HOUR = 60;
/// Лимит Cloudflare Workers для PBKDF2 — 100 000 итераций
const PBKDF2_ITERATIONS = 100000;

function json(data, status = 200) {
  return new Response(JSON.stringify(data), { status, headers: { "content-type": "application/json" } });
}

function hex(buffer) {
  return [...new Uint8Array(buffer)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

async function sha256(text) {
  return hex(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text)));
}

function randomHex(bytes) {
  return hex(crypto.getRandomValues(new Uint8Array(bytes)));
}

async function hashPassword(password, saltHex) {
  const key = await crypto.subtle.importKey("raw", new TextEncoder().encode(password), "PBKDF2", false, ["deriveBits"]);
  const salt = new Uint8Array(saltHex.match(/../g).map((byte) => parseInt(byte, 16)));
  return hex(await crypto.subtle.deriveBits({ name: "PBKDF2", hash: "SHA-256", salt, iterations: PBKDF2_ITERATIONS }, key, 256));
}

/// Сравнение за одно и то же время, чтобы по скорости ответа нельзя было угадывать хэш
function sameHash(a, b) {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

function normalizeEmail(value) {
  const email = String(value || "").trim().toLowerCase();
  if (email.length > 254 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) return null;
  return email;
}

function validPassword(value) {
  return typeof value === "string" && value.length >= MIN_PASSWORD && value.length <= MAX_PASSWORD;
}

/// Код из 6 цифр без перекоса: отбрасываем значения, на которых остаток давал бы неравные шансы
function randomCode() {
  const limit = 4294967296 - (4294967296 % 1000000);
  const buffer = new Uint32Array(1);
  do { crypto.getRandomValues(buffer); } while (buffer[0] >= limit);
  return String(buffer[0] % 1000000).padStart(6, "0");
}

async function userId(email) {
  return (await sha256(email)).slice(0, 32);
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const path = url.pathname;
    const user = (id) => env.USER.get(env.USER.idFromName(id));
    const ip = request.headers.get("CF-Connecting-IP") || "unknown";
    const allow = (kind, limit) => env.GATE.get(env.GATE.idFromName(`${kind}:${ip}`)).allow(limit);
    const read = () => request.json().catch(() => ({}));

    if (request.method === "POST" && path === "/auth/request") {
      const email = normalizeEmail((await read()).email);
      if (!email) return json({ error: "bad_email" }, 400);
      if (!(await allow("mail", IP_MAIL_PER_HOUR))) return json({ error: "too_many" }, 429);
      if (!env.RESEND_API_KEY) return json({ error: "mail_not_configured" }, 503);
      const result = await user(await userId(email)).requestCode(email);
      if (result.error) return json({ error: result.error, wait: result.wait }, 429);
      if (!(await sendMail(env, email, result.code))) return json({ error: "mail_failed" }, 502);
      return json({ ok: true });
    }

    if (request.method === "POST" && path === "/auth/verify") {
      const body = await read();
      const email = normalizeEmail(body.email);
      const code = String(body.code || "").trim();
      if (!email || !/^\d{6}$/.test(code)) return json({ error: "bad_code" }, 400);
      if (!(await allow("login", IP_LOGIN_PER_HOUR))) return json({ error: "too_many" }, 429);
      const result = await user(await userId(email)).verifyCode(await sha256(`${email}:${code}`));
      return result.ok ? json({ ticket: result.ticket }) : json({ error: result.error }, 401);
    }

    if (request.method === "POST" && path === "/auth/password") {
      const body = await read();
      const email = normalizeEmail(body.email);
      if (!email || typeof body.ticket !== "string") return json({ error: "bad_request" }, 400);
      if (!validPassword(body.password)) return json({ error: "weak_password" }, 400);
      if (!(await allow("login", IP_LOGIN_PER_HOUR))) return json({ error: "too_many" }, 429);
      const id = await userId(email);
      const salt = randomHex(16);
      const result = await user(id).setPassword(await sha256(body.ticket), salt, await hashPassword(body.password, salt), email);
      return result.ok ? json({ token: `${id}.${result.secret}`, email }) : json({ error: result.error }, 401);
    }

    if (request.method === "POST" && path === "/auth/login") {
      const body = await read();
      const email = normalizeEmail(body.email);
      if (!email || typeof body.password !== "string" || body.password.length > MAX_PASSWORD) return json({ error: "bad_request" }, 400);
      if (!(await allow("login", IP_LOGIN_PER_HOUR))) return json({ error: "too_many" }, 429);
      const id = await userId(email);
      const stub = user(id);
      const state = await stub.loginState();
      if (state.locked) return json({ error: "locked", wait: state.locked }, 429);
      // Хэш считаем и для несуществующей почты — по времени ответа не видно, есть ли такой аккаунт
      const salt = state.salt || "00000000000000000000000000000000";
      const check = await hashPassword(body.password, salt);
      const result = await stub.login(check);
      if (result.locked) return json({ error: "locked", wait: result.locked }, 429);
      return result.ok ? json({ token: `${id}.${result.secret}`, email }) : json({ error: "wrong" }, 401);
    }

    const token = (request.headers.get("authorization") || "").replace(/^Bearer /, "");
    const [id, secret] = token.split(".");
    if (path === "/me" || path === "/me/password" || path === "/auth/logout") {
      if (!id || !secret || !/^[0-9a-f]{32}$/.test(id)) return json({ error: "unauthorized" }, 401);
      const stub = user(id);
      const hash = await sha256(secret);
      if (path === "/auth/logout") {
        if (request.method !== "POST") return json({ error: "method" }, 405);
        await stub.logout(hash);
        return json({ ok: true });
      }
      if (path === "/me/password") {
        if (request.method !== "POST") return json({ error: "method" }, 405);
        const body = await read();
        if (!validPassword(body.password)) return json({ error: "weak_password" }, 400);
        if (typeof body.old !== "string" || body.old.length > MAX_PASSWORD) return json({ error: "bad_request" }, 400);
        if (!(await allow("login", IP_LOGIN_PER_HOUR))) return json({ error: "too_many" }, 429);
        const state = await stub.loginState();
        if (state.locked) return json({ error: "locked", wait: state.locked }, 429);
        const check = await hashPassword(body.old, state.salt || "00000000000000000000000000000000");
        const salt = randomHex(16);
        const result = await stub.changePassword(hash, check, salt, await hashPassword(body.password, salt));
        if (result.locked) return json({ error: "locked", wait: result.locked }, 429);
        return result.ok ? json({ ok: true }) : json({ error: result.error }, 401);
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
      subject: `Код WordLearner: ${code}`,
      text: `Ваш код: ${code}\n\nОн действует 10 минут. Если вы не регистрировались и не сбрасывали пароль в WordLearner, просто удалите это письмо.`,
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

/// Один пользователь: коды, пароль, сессии (позже — данные синхронизации)
export class User extends DurableObject {
  constructor(ctx, env) {
    super(ctx, env);
    const sql = ctx.storage.sql;
    sql.exec("CREATE TABLE IF NOT EXISTS codes (hash TEXT, expires INTEGER, attempts INTEGER, created INTEGER)");
    sql.exec("CREATE TABLE IF NOT EXISTS tickets (hash TEXT PRIMARY KEY, expires INTEGER)");
    sql.exec("CREATE TABLE IF NOT EXISTS sessions (hash TEXT PRIMARY KEY, created INTEGER, last INTEGER)");
    sql.exec("CREATE TABLE IF NOT EXISTS profile (key TEXT PRIMARY KEY, value TEXT)");
  }

  value(key) {
    const row = this.ctx.storage.sql.exec("SELECT value FROM profile WHERE key = ?", key).toArray()[0];
    return row ? row.value : null;
  }

  put(key, value) {
    this.ctx.storage.sql.exec("INSERT OR REPLACE INTO profile VALUES (?, ?)", key, String(value));
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
    return { code };
  }

  /// Новый код делает старые недействительными: проверяем только последний, лишние попытки сжигают его
  async verifyCode(hash) {
    const sql = this.ctx.storage.sql;
    const now = Date.now();
    const row = sql.exec("SELECT rowid, hash, expires, attempts FROM codes WHERE expires > ? ORDER BY created DESC LIMIT 1", now).toArray()[0];
    if (!row) return { ok: false, error: "expired" };
    if (row.attempts >= CODE_ATTEMPTS) return { ok: false, error: "too_many" };
    if (!sameHash(row.hash, hash)) {
      sql.exec("UPDATE codes SET attempts = attempts + 1 WHERE rowid = ?", row.rowid);
      return { ok: false, error: "wrong" };
    }
    sql.exec("DELETE FROM codes");
    sql.exec("DELETE FROM tickets WHERE expires < ?", now);
    const ticket = randomHex(24);
    sql.exec("INSERT INTO tickets VALUES (?, ?)", await sha256(ticket), now + TICKET_TTL_MS);
    return { ok: true, ticket };
  }

  /// Задать пароль по разрешению из письма: регистрация или сброс. Сброс закрывает все старые сессии
  async setPassword(ticketHash, salt, hash, email) {
    const sql = this.ctx.storage.sql;
    const now = Date.now();
    const row = sql.exec("SELECT hash FROM tickets WHERE hash = ? AND expires > ?", ticketHash, now).toArray()[0];
    if (!row) return { ok: false, error: "expired" };
    sql.exec("DELETE FROM tickets");
    sql.exec("DELETE FROM sessions");
    this.put("salt", salt);
    this.put("password", hash);
    this.put("email", email);
    this.put("failures", 0);
    this.put("lockedUntil", 0);
    return { ok: true, secret: await this.newSession() };
  }

  /// Сколько секунд ещё закрыт вход; 0 — открыт
  lockedFor() {
    const wait = Math.ceil((Number(this.value("lockedUntil") || 0) - Date.now()) / 1000);
    return wait > 0 ? wait : 0;
  }

  loginState() {
    return { salt: this.value("salt"), locked: this.lockedFor() };
  }

  /// Неверный пароль: после 5 подряд вход закрыт на 15 минут
  countFailure() {
    const failures = Number(this.value("failures") || 0) + 1;
    this.put("failures", failures);
    if (failures >= LOGIN_ATTEMPTS) {
      this.put("failures", 0);
      this.put("lockedUntil", Date.now() + LOGIN_LOCK_MS);
    }
  }

  /// check — хэш введённого пароля с солью аккаунта.
  /// Блокировка проверяется здесь же, в базе пользователя: её вызовы идут строго по очереди,
  /// поэтому пачка одновременных запросов не проскакивает до того, как вход закроется
  async login(check) {
    const locked = this.lockedFor();
    if (locked) return { ok: false, locked };
    const stored = this.value("password");
    if (stored && sameHash(stored, check)) {
      this.put("failures", 0);
      return { ok: true, secret: await this.newSession() };
    }
    this.countFailure();
    return { ok: false };
  }

  async changePassword(sessionHash, oldCheck, salt, hash) {
    const sql = this.ctx.storage.sql;
    if (!sql.exec("SELECT hash FROM sessions WHERE hash = ?", sessionHash).toArray()[0]) return { ok: false, error: "unauthorized" };
    const locked = this.lockedFor();
    if (locked) return { ok: false, locked };
    const stored = this.value("password");
    if (!stored || !sameHash(stored, oldCheck)) {
      this.countFailure();
      return { ok: false, error: "wrong" };
    }
    this.put("salt", salt);
    this.put("password", hash);
    this.put("failures", 0);
    // Остальные устройства входят заново с новым паролем
    sql.exec("DELETE FROM sessions WHERE hash != ?", sessionHash);
    return { ok: true };
  }

  async newSession() {
    const sql = this.ctx.storage.sql;
    const now = Date.now();
    const secret = randomHex(32);
    sql.exec("INSERT INTO sessions VALUES (?, ?, ?)", await sha256(secret), now, now);
    // Старые сессии сверх лимита — выходят сами
    sql.exec("DELETE FROM sessions WHERE hash NOT IN (SELECT hash FROM sessions ORDER BY last DESC LIMIT ?)", MAX_SESSIONS);
    return secret;
  }

  me(hash) {
    const sql = this.ctx.storage.sql;
    if (!sql.exec("SELECT hash FROM sessions WHERE hash = ?", hash).toArray()[0]) return null;
    sql.exec("UPDATE sessions SET last = ? WHERE hash = ?", Date.now(), hash);
    return { email: this.value("email") };
  }

  logout(hash) {
    this.ctx.storage.sql.exec("DELETE FROM sessions WHERE hash = ?", hash);
    return true;
  }
}
