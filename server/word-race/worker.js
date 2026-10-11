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
    return json({ ok: true, service: "word-race" });
  },
};

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
