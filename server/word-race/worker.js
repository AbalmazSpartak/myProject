// «Гонка слов» онлайн: комнаты по коду и подбор случайного соперника.
// Сервер только пересылает ходы гонки (start / progress / finished) между игроками комнаты;
// слова и правила — в приложении, у создателя комнаты.
import { DurableObject } from "cloudflare:workers";

const MAX_PLAYERS = 4;
// Без похожих символов: 0/O, 1/I/L
const CODE_ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";

function newCode() {
  let code = "";
  const bytes = crypto.getRandomValues(new Uint8Array(4));
  for (const b of bytes) code += CODE_ALPHABET[b % CODE_ALPHABET.length];
  return code;
}

function json(data, status = 200) {
  return new Response(JSON.stringify(data), { status, headers: { "content-type": "application/json" } });
}

function cleanName(raw) {
  const name = (raw || "").trim().slice(0, 40);
  return name || "Игрок";
}

async function createRoom(env) {
  const code = newCode();
  await env.ROOMS.get(env.ROOMS.idFromName(code)).create();
  return code;
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const parts = url.pathname.split("/").filter(Boolean);

    // POST /room — новая комната, ответ { code }
    if (request.method === "POST" && parts.length === 1 && parts[0] === "room") {
      return json({ code: await createRoom(env) });
    }
    // /room/CODE?name=… — WebSocket комнаты
    if (parts.length === 2 && parts[0] === "room") {
      const code = parts[1].toUpperCase();
      if (!/^[A-Z0-9]{4}$/.test(code)) return json({ error: "Неверный код" }, 400);
      return env.ROOMS.get(env.ROOMS.idFromName(code)).fetch(request);
    }
    // /match?name=… — WebSocket очереди случайного соперника
    if (parts.length === 1 && parts[0] === "match") {
      return env.MATCH.get(env.MATCH.idFromName("global")).fetch(request);
    }
    // POST /report — сообщение об ошибке в слове из встроенного словаря приложения
    if (request.method === "POST" && parts.length === 1 && parts[0] === "report") {
      return env.REPORTS.get(env.REPORTS.idFromName("all")).fetch(request);
    }
    // GET /reports?key=… — все сообщения (для правки words.csv); ключ — секрет REPORTS_KEY
    // POST /signals — сигналы для улучшения словаря (правки, слова из текста, трудные слова) — от приложения
    // GET /signals?key=… — все сигналы; GET /patch?since=N — одобренные правки словаря для всех; POST /patch?key=… — добавить
    const admin = env.REPORTS_KEY && url.searchParams.get("key") === env.REPORTS_KEY;
    if (parts.length === 1 && ["reports", "signals", "patch"].includes(parts[0])) {
      const open = (parts[0] === "signals" && request.method === "POST") || (parts[0] === "patch" && request.method === "GET");
      if (!open && !admin) return json({ error: "Нет доступа" }, 403);
      return env.REPORTS.get(env.REPORTS.idFromName("all")).fetch(request);
    }
    return json({ ok: true, service: "word-race" });
  },
};

/// Сообщения об ошибках в словах: одна таблица SQLite. Повтор с тем же id (очередь приложения отправила дважды) не дублируется
export class Reports extends DurableObject {
  constructor(ctx, env) {
    super(ctx, env);
    ctx.storage.sql.exec(`CREATE TABLE IF NOT EXISTS reports (
      id TEXT PRIMARY KEY, received TEXT, created TEXT, word TEXT, part_of_speech TEXT,
      field TEXT, comment TEXT, current TEXT, app_version TEXT)`);
    // Сигналы: правка встроенного слова (edit), слово из текста (context), слова нет в базе (missing), трудное слово (hard)
    ctx.storage.sql.exec(`CREATE TABLE IF NOT EXISTS signals (
      id TEXT PRIMARY KEY, received TEXT, install TEXT, kind TEXT, word TEXT, part_of_speech TEXT,
      field TEXT, old TEXT, new TEXT, sentence TEXT)`);
    // Патч словаря: одобренные правки, по порядку; приложение берёт новые после своего номера
    ctx.storage.sql.exec(`CREATE TABLE IF NOT EXISTS patch (
      version INTEGER PRIMARY KEY AUTOINCREMENT, created TEXT, word TEXT, part_of_speech TEXT,
      match_russian TEXT, field TEXT, value TEXT)`);
  }

  async fetch(request) {
    const path = new URL(request.url).pathname.split("/").filter(Boolean)[0];
    if (path === "signals") return this.signals(request);
    if (path === "patch") return this.patch(request);
    if (request.method === "GET") {
      const rows = this.ctx.storage.sql.exec("SELECT * FROM reports ORDER BY received DESC").toArray();
      return json({ count: rows.length, reports: rows });
    }
    const text = await request.text();
    if (text.length > 8000) return json({ error: "Слишком длинно" }, 413);
    let body;
    try { body = JSON.parse(text); } catch { return json({ error: "Неверные данные" }, 400); }
    const str = (v, max) => (typeof v === "string" ? v.slice(0, max) : "");
    const id = str(body.id, 64);
    if (!id || !str(body.word, 100)) return json({ error: "Нет слова" }, 400);
    this.ctx.storage.sql.exec(
      "INSERT OR IGNORE INTO reports VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
      id, new Date().toISOString(), str(body.created, 40), str(body.word, 100), str(body.partOfSpeech, 20),
      str(body.field, 40), str(body.comment, 1000), JSON.stringify(body.current ?? {}).slice(0, 3000), str(body.appVersion, 20));
    return json({ ok: true });
  }

  async signals(request) {
    if (request.method === "GET") {
      const rows = this.ctx.storage.sql.exec("SELECT * FROM signals ORDER BY received DESC").toArray();
      return json({ count: rows.length, signals: rows });
    }
    const text = await request.text();
    if (text.length > 60000) return json({ error: "Слишком длинно" }, 413);
    let items;
    try { items = JSON.parse(text); } catch { return json({ error: "Неверные данные" }, 400); }
    if (!Array.isArray(items)) return json({ error: "Нужен список" }, 400);
    const str = (v, max) => (typeof v === "string" ? v.slice(0, max) : "");
    const kinds = ["edit", "context", "missing", "hard"];
    const received = new Date().toISOString();
    let saved = 0;
    for (const item of items.slice(0, 50)) {
      if (!item || !str(item.id, 64) || !str(item.word, 100) || !kinds.includes(item.kind)) continue;
      this.ctx.storage.sql.exec("INSERT OR IGNORE INTO signals VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
        str(item.id, 64), received, str(item.install, 64), item.kind, str(item.word, 100), str(item.partOfSpeech, 20),
        str(item.field, 30), str(item.old, 500), str(item.new, 500), str(item.sentence, 600));
      saved++;
    }
    return json({ ok: true, saved });
  }

  async patch(request) {
    if (request.method === "GET") {
      const since = Number(new URL(request.url).searchParams.get("since") || 0) || 0;
      const rows = this.ctx.storage.sql.exec("SELECT * FROM patch WHERE version > ? ORDER BY version", since).toArray();
      return json({ entries: rows });
    }
    let items;
    try { items = await request.json(); } catch { return json({ error: "Неверные данные" }, 400); }
    if (!Array.isArray(items)) return json({ error: "Нужен список" }, 400);
    const fields = ["russian", "transcription", "example", "cefrLevel", "partOfSpeech"];
    const created = new Date().toISOString();
    let saved = 0;
    for (const e of items) {
      if (!e || typeof e.word !== "string" || !fields.includes(e.field) || typeof e.value !== "string") continue;
      this.ctx.storage.sql.exec("INSERT INTO patch (created, word, part_of_speech, match_russian, field, value) VALUES (?, ?, ?, ?, ?, ?)",
        created, e.word, e.partOfSpeech || "", e.matchRussian || "", e.field, e.value);
      saved++;
    }
    return json({ ok: true, saved });
  }
}

/// Комната гонки: игроки по WebSocket, первый подключившийся с role=host — создатель (задаёт слова и старт)
export class RaceRoom extends DurableObject {
  async create() {
    await this.ctx.storage.put("createdAt", Date.now());
    await this.ctx.storage.put("started", false);
  }

  async fetch(request) {
    if (request.headers.get("Upgrade") !== "websocket") return json({ error: "Нужен WebSocket" }, 426);
    const url = new URL(request.url);
    const name = cleanName(url.searchParams.get("name"));
    const role = url.searchParams.get("role") === "host" ? "host" : "guest";

    const pair = new WebSocketPair();
    const [client, server] = Object.values(pair);

    // Отказ — без входа в комнату: такой игрок не попадает в список и не «уходит» из него
    const refuse = (message) => {
      server.accept();
      server.send(JSON.stringify({ type: "error", error: message }));
      server.close(4000, message);
      return new Response(null, { status: 101, webSocket: client });
    };

    if (!(await this.ctx.storage.get("createdAt"))) return refuse("Комната не найдена — проверьте код");
    const others = this.ctx.getWebSockets();
    if (others.length >= MAX_PLAYERS) return refuse("Комната заполнена");
    if (await this.ctx.storage.get("started")) return refuse("Гонка уже идёт");
    if (others.some((ws) => this.ctx.getTags(ws)[0] === name)) return refuse("Такое имя уже в комнате");

    this.ctx.acceptWebSocket(server, [name, role]);
    this.broadcastRoster();
    return new Response(null, { status: 101, webSocket: client });
  }

  /// Кто в комнате; `gone` — уходящий, его сокет ещё в списке
  sockets(gone) {
    return this.ctx.getWebSockets().filter((ws) => ws !== gone);
  }

  players(gone) {
    return this.sockets(gone).map((ws) => this.ctx.getTags(ws)[0]);
  }

  hostName(gone) {
    const host = this.sockets(gone).find((ws) => this.ctx.getTags(ws)[1] === "host");
    return host ? this.ctx.getTags(host)[0] : null;
  }

  broadcast(data, except) {
    const text = typeof data === "string" ? data : JSON.stringify(data);
    for (const ws of this.ctx.getWebSockets()) {
      if (ws === except) continue;
      try { ws.send(text); } catch {}
    }
  }

  broadcastRoster(gone) {
    this.broadcast({ type: "roster", players: this.players(gone), host: this.hostName(gone) }, gone);
  }

  async webSocketMessage(ws, message) {
    let data;
    try { data = JSON.parse(message); } catch { return; }
    if (!data || typeof data.type !== "string") return;
    const [name, role] = this.ctx.getTags(ws);
    // Имя отправителя — с сервера: подделать ход за другого нельзя
    data.playerName = name;
    if (data.type === "start") {
      if (role !== "host") return;
      await this.ctx.storage.put("started", true);
    }
    this.broadcast(data, ws);
  }

  async webSocketClose(ws) {
    await this.left(ws);
  }

  async webSocketError(ws) {
    await this.left(ws);
  }

  async left(ws) {
    // Закрытие приходит и как close, и как error — уходим один раз
    if (ws.deserializeAttachment()?.left) return;
    ws.serializeAttachment({ left: true });
    const [name, role] = this.ctx.getTags(ws);
    try { ws.close(1000, "bye"); } catch {}
    this.broadcast({ type: "left", playerName: name }, ws);
    // Создатель ушёл до старта — комнату закрываем: начать гонку больше некому
    if (role === "host" && !(await this.ctx.storage.get("started"))) {
      this.broadcast({ type: "closed", error: "Создатель закрыл комнату" }, ws);
    }
    this.broadcastRoster(ws);
  }
}

/// Очередь «Случайный соперник»: двое в очереди — новая комната, первому роль host, второму guest
export class Matchmaker extends DurableObject {
  async fetch(request) {
    if (request.headers.get("Upgrade") !== "websocket") return json({ error: "Нужен WebSocket" }, 426);
    const name = cleanName(new URL(request.url).searchParams.get("name"));
    const pair = new WebSocketPair();
    const [client, server] = Object.values(pair);

    const waiting = this.ctx.getWebSockets("waiting");
    if (waiting.length > 0) {
      const partner = waiting[0];
      this.ctx.acceptWebSocket(server, ["matched", name]);
      const code = await createRoom(this.env);
      try { partner.send(JSON.stringify({ type: "matched", code, role: "host" })); } catch {}
      server.send(JSON.stringify({ type: "matched", code, role: "guest" }));
      try { partner.close(1000, "matched"); } catch {}
      server.close(1000, "matched");
    } else {
      this.ctx.acceptWebSocket(server, ["waiting", name]);
    }
    return new Response(null, { status: 101, webSocket: client });
  }

  async webSocketMessage() {}

  async webSocketClose(ws) {
    try { ws.close(1000, "bye"); } catch {}
  }
}
