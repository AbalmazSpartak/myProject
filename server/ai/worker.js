// ИИ-подсказки WordLearner: значение слова именно в этом предложении.
// Обычная — Claude Haiku, более точная — Claude Sonnet (выбор в настройках приложения).
// Отдельно от word-race: ключ Claude есть только здесь, ошибка тут не заденет «Гонку слов».
// Защита от перерасхода: кэш (повтор — бесплатно), дневной запас кредитов на установку,
// не больше PER_MINUTE запросов в минуту, месячный потолок расходов в долларах.
import { DurableObject } from "cloudflare:workers";
import Anthropic from "@anthropic-ai/sdk";

// cost — сколько кредитов списывается; цены — $ за 1 млн токенов (вход / выход)
const QUALITY = {
  normal: { model: "claude-haiku-5-5", cost: 1 },
  precise: { model: "claude-sonnet-5-5", cost: 3 },
};
const PRICES = {
  "claude-haiku-5-5": [0.10, 0.50],
  "claude-sonnet-5-5": [2.00, 10.00],
};
const DAILY_CREDITS = 30;
const PER_MINUTE = 10;
const DEFAULT_MONTHLY_BUDGET = 5; // $; можно поменять переменной MONTHLY_BUDGET_USD

// Слова из книг: перевод новых слов словаря с учётом предложения из книги — Haiku, пачками.
// Свой дневной запас (в словах, не в кредитах): ~3 книги в день; повтор того же слова в том же предложении —
// из общего кэша, бесплатно и для других читателей этой книги
const WORDS_MODEL = "claude-haiku-5-5";
const WORDS_PER_DAY = 6000;
const WORDS_PER_REQUEST = 50;
const WORDS_REQUESTS_PER_MINUTE = 60;

const WORDS_SYSTEM = `You build an English–Russian learner's dictionary for a novel. Each item has the word as our program extracted it, the part of speech our tagger guessed (often wrong), and the sentence from the book with the word marked <b>…</b>. The book may use 19th-century dialect and colloquial spelling.

For every item return:
- lemma: the dictionary headword in standard English. For dialect or colloquial spellings give the standard word (knowed → know, a-going → go, agin → again). For an inflected form give the base form (waded → wade).
- pos: part of speech in this sentence: n., v., adj., adv., prep., conj., pron., interj., phr. v., idiom.
- ru: Russian translation of the meaning used in THIS sentence, in dictionary form (infinitive for verbs, nominative singular for nouns, masculine for adjectives). 1–3 short variants separated by commas, no explanations. If the word is part of an idiom or a phrasal verb here, translate that meaning.
- kind: word | dialect | name | junk | function. dialect = nonstandard spelling or form of a normal word; name = person or place name; junk = a fragment that is not a word; function = article, pronoun, conjunction and the like.
- note: Russian, at most 8 words, only when the sense in this sentence is unusual (idiom, archaic meaning); otherwise an empty string.

Never use vulgar or obscene Russian words. If the English word itself is vulgar, give a neutral translation and put (груб.) in note.`;

const WORDS_SCHEMA = {
  type: "object",
  properties: {
    items: {
      type: "array",
      items: {
        type: "object",
        properties: {
          id: { type: "integer" },
          lemma: { type: "string" },
          pos: { type: "string" },
          ru: { type: "string" },
          kind: { type: "string", enum: ["word", "dialect", "name", "junk", "function"] },
          note: { type: "string" },
        },
        required: ["id", "lemma", "pos", "ru", "kind", "note"],
        additionalProperties: false,
      },
    },
  },
  required: ["items"],
  additionalProperties: false,
};

const CONTEXT_SYSTEM = `You help a Russian speaker read English.
Given an English word or phrase and the sentence it appears in, pick the meaning used IN THIS SENTENCE.
Answer in exactly two lines, nothing else:
RU: <short Russian translation for this sense, 1-3 variants separated by commas>
EN: <very short English gloss of this sense>`;

function json(data, status = 200) {
  return new Response(JSON.stringify(data), { status, headers: { "content-type": "application/json" } });
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const parts = url.pathname.split("/").filter(Boolean);
    const store = () => env.STORE.get(env.STORE.idFromName("all"));

    // POST /context { word, sentence, install, quality: "normal" | "precise" } → { ru, en, cached, left }
    // POST /words { install, items: [{ word, pos, sentence }] } → { items: [{ lemma, pos, ru, kind, note } | null], cached, left }
    if (request.method === "POST" && parts.length === 1 && (parts[0] === "context" || parts[0] === "words")) {
      return store().fetch(request);
    }
    // GET /stats?key=… — расходы и кэш (секрет ADMIN_KEY)
    if (request.method === "GET" && parts.length === 1 && parts[0] === "stats") {
      if (!env.ADMIN_KEY || url.searchParams.get("key") !== env.ADMIN_KEY) return json({ error: "Нет доступа" }, 403);
      return store().fetch(request);
    }
    return json({ ok: true, service: "wordlearner-ai" });
  },
};

/// Одна база SQLite на всех: кэш ответов, кредиты по установкам за день, расходы по месяцам
export class Store extends DurableObject {
  constructor(ctx, env) {
    super(ctx, env);
    this.env = env;
    /// Запросы за последнюю минуту по установкам — в памяти, этого достаточно
    this.recent = new Map();
    ctx.storage.sql.exec(`CREATE TABLE IF NOT EXISTS cache (
      key TEXT PRIMARY KEY, word TEXT, sentence TEXT, ru TEXT, en TEXT, created TEXT, hits INTEGER DEFAULT 0)`);
    ctx.storage.sql.exec(`CREATE TABLE IF NOT EXISTS credits (
      install TEXT, day TEXT, used INTEGER, PRIMARY KEY (install, day))`);
    ctx.storage.sql.exec(`CREATE TABLE IF NOT EXISTS spend (
      month TEXT PRIMARY KEY, dollars REAL, requests INTEGER)`);
    ctx.storage.sql.exec(`CREATE TABLE IF NOT EXISTS words_cache (
      key TEXT PRIMARY KEY, lemma TEXT, pos TEXT, ru TEXT, kind TEXT, note TEXT, created TEXT, hits INTEGER DEFAULT 0)`);
    ctx.storage.sql.exec(`CREATE TABLE IF NOT EXISTS words_quota (
      install TEXT, day TEXT, used INTEGER, PRIMARY KEY (install, day))`);
    /// Пачки слов за последнюю минуту по установкам
    this.recentWords = new Map();
  }

  async fetch(request) {
    if (request.method === "GET") return this.stats();
    if (new URL(request.url).pathname === "/words") return this.words(request);
    return this.context(request);
  }

  stats() {
    const sql = this.ctx.storage.sql;
    const spend = sql.exec("SELECT * FROM spend ORDER BY month DESC").toArray();
    const cache = sql.exec("SELECT count(*) AS rows, sum(hits) AS hits FROM cache").one();
    const today = new Date().toISOString().slice(0, 10);
    const installs = sql.exec("SELECT count(*) AS n, sum(used) AS used FROM credits WHERE day = ?", today).one();
    const words = sql.exec("SELECT count(*) AS rows, sum(hits) AS hits FROM words_cache").one();
    const wordsToday = sql.exec("SELECT count(*) AS n, sum(used) AS used FROM words_quota WHERE day = ?", today).one();
    return json({ budget: this.budget(), spend, cache, today: installs, words, wordsToday });
  }

  budget() {
    return Number(this.env.MONTHLY_BUDGET_USD) || DEFAULT_MONTHLY_BUDGET;
  }

  async context(request) {
    const text = await request.text();
    if (text.length > 4000) return json({ error: "Слишком длинно" }, 413);
    let body;
    try { body = JSON.parse(text); } catch { return json({ error: "Неверные данные" }, 400); }
    const str = (v, max) => (typeof v === "string" ? v.trim().replace(/\s+/g, " ").slice(0, max) : "");
    const word = str(body.word, 60);
    const sentence = str(body.sentence, 600);
    const install = str(body.install, 64);
    if (!word || !sentence || !install) return json({ error: "Нет слова или предложения" }, 400);
    const quality = body.quality === "precise" ? "precise" : "normal";
    const { model, cost } = QUALITY[quality];

    const sql = this.ctx.storage.sql;
    const day = new Date().toISOString().slice(0, 10);
    const used = sql.exec("SELECT used FROM credits WHERE install = ? AND day = ?", install, day).toArray()[0]?.used ?? 0;
    const left = DAILY_CREDITS - used;

    // Кэш: этот вопрос уже задавали — бесплатно и без кредитов. Точный ответ годится и для обычного запроса
    const keyFor = (q) => `${q}|${word.toLowerCase()}|${sentence}`;
    const key = keyFor(quality);
    for (const k of quality === "normal" ? [keyFor("precise"), key] : [key]) {
      const hit = sql.exec("SELECT ru, en FROM cache WHERE key = ?", k).toArray()[0];
      if (hit) {
        sql.exec("UPDATE cache SET hits = hits + 1 WHERE key = ?", k);
        return json({ ru: hit.ru, en: hit.en, cached: true, left });
      }
    }

    if (left < cost) return json({ error: "limit", left }, 429);
    const now = Date.now();
    const times = (this.recent.get(install) || []).filter((t) => now - t < 60_000);
    if (times.length >= PER_MINUTE) return json({ error: "rate", left }, 429);
    const month = day.slice(0, 7);
    const spent = sql.exec("SELECT dollars FROM spend WHERE month = ?", month).toArray()[0]?.dollars ?? 0;
    if (spent >= this.budget()) return json({ error: "budget", left }, 503);
    times.push(now);
    this.recent.set(install, times);

    let response;
    try {
      const client = new Anthropic({ apiKey: this.env.ANTHROPIC_API_KEY });
      const params = {
        model,
        max_tokens: 1000,
        system: CONTEXT_SYSTEM,
        output_config: { effort: "low" },
        messages: [{ role: "user", content: `Word: "${word}"\nSentence: ${sentence}` }],
      };
      // Sonnet: если фильтры безопасности откажут, сервер Anthropic сам повторит запрос на другой модели
      response = quality === "precise"
        ? await client.beta.messages.create({ ...params, betas: ["server-side-fallback-2026-07-01"], fallbacks: "default" })
        : await client.messages.create(params);
    } catch (e) {
      const status = e instanceof Anthropic.APIError ? e.status : undefined;
      console.log("claude error", status, String(e).slice(0, 300));
      return json({ error: "ai" }, 502);
    }

    const [pin, pout] = PRICES[response.model] ?? PRICES["claude-sonnet-5-5"];
    const dollars = (response.usage.input_tokens * pin + response.usage.output_tokens * pout) / 1e6;
    sql.exec(`INSERT INTO spend VALUES (?, ?, 1) ON CONFLICT(month) DO UPDATE
      SET dollars = dollars + excluded.dollars, requests = requests + 1`, month, dollars);

    if (response.stop_reason === "refusal") return json({ error: "ai" }, 502);
    const answer = response.content.filter((b) => b.type === "text").map((b) => b.text).join("\n");
    const line = (prefix) => answer.split("\n").find((l) => l.trim().startsWith(prefix))?.trim().slice(prefix.length).trim() ?? "";
    const ru = line("RU:");
    const en = line("EN:");
    if (!ru) return json({ error: "ai" }, 502);

    sql.exec(`INSERT INTO credits VALUES (?, ?, ?) ON CONFLICT(install, day) DO UPDATE
      SET used = used + excluded.used`, install, day, cost);
    sql.exec("INSERT OR IGNORE INTO cache (key, word, sentence, ru, en, created) VALUES (?, ?, ?, ?, ?, ?)",
      key, word, sentence, ru, en, new Date().toISOString());
    return json({ ru, en, cached: false, left: left - cost });
  }

  /// Новые слова словаря из книги: перевод по предложению, словарная форма, часть речи, вид (обычное, диалект, имя…).
  /// Сначала общий кэш, остальное — одним запросом к Haiku. Дневной запас считается в переведённых словах
  async words(request) {
    const text = await request.text();
    if (text.length > 60_000) return json({ error: "Слишком длинно" }, 413);
    let body;
    try { body = JSON.parse(text); } catch { return json({ error: "Неверные данные" }, 400); }
    const str = (v, max) => (typeof v === "string" ? v.trim().replace(/\s+/g, " ").slice(0, max) : "");
    const install = str(body.install, 64);
    const items = Array.isArray(body.items) ? body.items.slice(0, WORDS_PER_REQUEST) : [];
    if (!install || items.length === 0) return json({ error: "Нет слов" }, 400);
    const words = items.map((item) => ({ word: str(item?.word, 60), pos: str(item?.pos, 12), sentence: str(item?.sentence, 400) }));

    const sql = this.ctx.storage.sql;
    const day = new Date().toISOString().slice(0, 10);
    const used = sql.exec("SELECT used FROM words_quota WHERE install = ? AND day = ?", install, day).toArray()[0]?.used ?? 0;
    const left = WORDS_PER_DAY - used;

    // Кэш — по слову и предложению: одна и та же книга у разных читателей даёт те же пары
    const keyOf = (w) => `${w.word.toLowerCase()}|${w.sentence}`;
    const results = words.map(() => null);
    const missing = [];
    words.forEach((w, index) => {
      if (!w.word) return;
      const hit = sql.exec("SELECT lemma, pos, ru, kind, note FROM words_cache WHERE key = ?", keyOf(w)).toArray()[0];
      if (hit) {
        sql.exec("UPDATE words_cache SET hits = hits + 1 WHERE key = ?", keyOf(w));
        results[index] = hit;
      } else {
        missing.push(index);
      }
    });
    const cached = words.length - missing.length;
    if (missing.length === 0) return json({ items: results, cached, left });

    if (left < missing.length) return json({ error: "limit", left }, 429);
    const now = Date.now();
    const times = (this.recentWords.get(install) || []).filter((t) => now - t < 60_000);
    if (times.length >= WORDS_REQUESTS_PER_MINUTE) return json({ error: "rate", left }, 429);
    const month = day.slice(0, 7);
    const spent = sql.exec("SELECT dollars FROM spend WHERE month = ?", month).toArray()[0]?.dollars ?? 0;
    if (spent >= this.budget()) return json({ error: "budget", left }, 503);
    times.push(now);
    this.recentWords.set(install, times);

    const lines = missing.map((index) => JSON.stringify({ id: index, word: words[index].word, pos: words[index].pos, sentence: words[index].sentence }));
    let response;
    try {
      const client = new Anthropic({ apiKey: this.env.ANTHROPIC_API_KEY });
      response = await client.messages.create({
        model: WORDS_MODEL,
        max_tokens: 16000,
        system: WORDS_SYSTEM,
        output_config: { effort: "low", format: { type: "json_schema", schema: WORDS_SCHEMA } },
        messages: [{ role: "user", content: lines.join("\n") }],
      });
    } catch (e) {
      const status = e instanceof Anthropic.APIError ? e.status : undefined;
      console.log("claude error (words)", status, String(e).slice(0, 300));
      return json({ error: "ai" }, 502);
    }

    const [pin, pout] = PRICES[WORDS_MODEL];
    const dollars = (response.usage.input_tokens * pin + response.usage.output_tokens * pout) / 1e6;
    sql.exec(`INSERT INTO spend VALUES (?, ?, 1) ON CONFLICT(month) DO UPDATE
      SET dollars = dollars + excluded.dollars, requests = requests + 1`, month, dollars);
    if (response.stop_reason !== "end_turn") return json({ error: "ai" }, 502);

    let answer;
    try {
      answer = JSON.parse(response.content.find((b) => b.type === "text")?.text ?? "");
    } catch {
      return json({ error: "ai" }, 502);
    }
    let translated = 0;
    const created = new Date().toISOString();
    for (const item of answer.items ?? []) {
      if (!missing.includes(item.id) || results[item.id] || !item.ru) continue;
      const entry = { lemma: item.lemma, pos: item.pos, ru: item.ru, kind: item.kind, note: item.note };
      results[item.id] = entry;
      translated += 1;
      sql.exec("INSERT OR IGNORE INTO words_cache (key, lemma, pos, ru, kind, note, created) VALUES (?, ?, ?, ?, ?, ?, ?)",
        keyOf(words[item.id]), entry.lemma, entry.pos, entry.ru, entry.kind, entry.note, created);
    }
    sql.exec(`INSERT INTO words_quota VALUES (?, ?, ?) ON CONFLICT(install, day) DO UPDATE
      SET used = used + excluded.used`, install, day, translated);
    return json({ items: results, cached, left: left - translated });
  }
}
