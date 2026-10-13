#!/usr/bin/env python3
"""Сигналы для улучшения встроенного словаря (из приложения) → отчёт; одобренные правки → патч для всех и words.csv.

  python3 scripts/dictionary_feedback.py report                 — сводка: правки, трудные слова, чего нет в базе
  python3 scripts/dictionary_feedback.py publish approved.json  — правки в патч (придут всем без обновления) и в words.csv

approved.json — список {"word", "partOfSpeech", "matchRussian", "field", "value"};
field: russian | transcription | example | cefrLevel | partOfSpeech.
Ключ доступа к серверу — ~/.wordlearner_reports_key (только на этом Mac).
"""
import csv, json, sys, urllib.request
from collections import defaultdict
from pathlib import Path

BASE = "https://word-race.abalmazspartak.workers.dev"
KEY = Path.home().joinpath(".wordlearner_reports_key").read_text().strip()
CSV = Path(__file__).resolve().parent.parent / "myProject/Resources/words.csv"
COLUMNS = {"russian": "Translation", "transcription": "IPA", "example": "Example", "cefrLevel": "Level", "partOfSpeech": "PoS"}


# Cloudflare не пускает запросы с подписью Python-urllib
HEADERS = {"User-Agent": "WordLearner-tools/1.0", "Content-Type": "application/json"}


def get(path):
    req = urllib.request.Request(f"{BASE}/{path}{'&' if '?' in path else '?'}key={KEY}", headers=HEADERS)
    with urllib.request.urlopen(req) as r:
        return json.load(r)


def report():
    signals = [s for s in get("signals")["signals"] if s["install"] != "test"]
    print(f"Сигналов: {len(signals)}, установок: {len({s['install'] for s in signals})}\n")

    def grouped(kind, key):
        groups = defaultdict(lambda: {"installs": set(), "items": []})
        for s in signals:
            if s["kind"] == kind:
                g = groups[key(s)]
                g["installs"].add(s["install"])
                g["items"].append(s)
        return sorted(groups.items(), key=lambda kv: -len(kv[1]["installs"]))

    print("## Правки встроенных слов (сколько разных людей)")
    for (word, pos, field, old, new), g in grouped("edit", lambda s: (s["word"], s["part_of_speech"], s["field"], s["old"], s["new"])):
        print(f"- {len(g['installs'])}× **{word}** ({pos}) {field}: «{old}» → «{new}»")

    print("\n## Трудные слова (3 раза «Снова»)")
    for (word, pos, old), g in grouped("hard", lambda s: (s["word"], s["part_of_speech"], s["old"])):
        print(f"- {len(g['installs'])}× **{word}** ({pos}) — «{old}»")

    print("\n## Нет в базе (добавляли из книг)")
    for (word,), g in grouped("missing", lambda s: (s["word"].lower(),)):
        sample = g["items"][0]
        print(f"- {len(g['installs'])}× **{word}** ({sample['part_of_speech']}) — «{sample['new']}» · {sample['sentence'][:100]}")

    print("\n## Слова из книг — в каком значении (для проверки перевода)")
    for (word, pos, old), g in grouped("context", lambda s: (s["word"], s["part_of_speech"], s["old"]))[:40]:
        print(f"- {len(g['installs'])}× **{word}** ({pos}) «{old}» · {g['items'][0]['sentence'][:100]}")

    reports = get("reports")["reports"]
    reports = [r for r in reports if r["id"] != "test-1"]
    print(f"\n## Сообщения об ошибках: {len(reports)}")
    for r in reports:
        print(f"- **{r['word']}** ({r['part_of_speech']}) {r['field']}: {r['comment']} · сейчас {r['current']}")


def publish(path):
    entries = json.loads(Path(path).read_text())
    for e in entries:
        assert e["field"] in COLUMNS, e
    # words.csv — та же правка, чтобы следующая версия приложения пришла уже с ней
    with CSV.open(newline="", encoding="utf-8") as f:
        rows = list(csv.reader(f))
    header = rows[0]
    col = {name: i for i, name in enumerate(header)}
    changed = 0
    for e in entries:
        for row in rows[1:]:
            if row[col["Word"]] == e["word"] and row[col["PoS"]] == e.get("partOfSpeech", "") \
                    and (not e.get("matchRussian") or row[col["Translation"]] == e["matchRussian"]):
                row[col[COLUMNS[e["field"]]]] = e["value"]
                changed += 1
    with CSV.open("w", newline="", encoding="utf-8") as f:
        csv.writer(f, lineterminator="\n").writerows(rows)
    req = urllib.request.Request(f"{BASE}/patch?key={KEY}", data=json.dumps(entries).encode(), method="POST", headers=HEADERS)
    with urllib.request.urlopen(req) as r:
        print("сервер:", json.load(r), "· строк words.csv изменено:", changed)
    print("Дальше: python3 scripts/validate_words.py && python3 scripts/export_word_list.py")


if __name__ == "__main__":
    {"report": lambda: report(), "publish": lambda: publish(sys.argv[2])}[sys.argv[1]]()
