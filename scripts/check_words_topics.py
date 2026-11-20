#!/usr/bin/env python3
"""Темы и теги words.csv: все темы из утверждённых 48 (TopicSections.swift), в каждой не меньше 28 слов,
теги только Oxford и Extra. Код выхода 1 — есть ошибки."""
import collections, csv, re, sys
from pathlib import Path

root = Path(__file__).resolve().parent.parent
sections = (root / "myProject/Views/Dictionary/TopicSections.swift").read_text(encoding="utf-8")
body = sections.split("static let all")[1].split("static let topicNames")[0]
section_titles = re.findall(r'\("([^"]+)", \[', body)
topics = set(re.findall(r'"([^"]+)"', body))
for title in section_titles:
    # название раздела может совпадать с названием темы («Общество»): тогда это и тема
    if len(re.findall(rf'"{re.escape(title)}"', body)) < 2:
        topics.discard(title)
rows = list(csv.DictReader(open(root / "myProject/Resources/words.csv", encoding="utf-8")))
errors = []
count = collections.Counter(r["Topic"] for r in rows)
for topic in sorted(set(count) - topics): errors.append(f"тема «{topic}» ({count[topic]} слов) не из списка 48")
for topic in sorted(topics - set(count)): errors.append(f"тема «{topic}» из списка 48 не встречается в words.csv")
for topic, n in sorted(count.items()):
    if n < 28: errors.append(f"в теме «{topic}» всего {n} слов (нужно не меньше 28)")
for tag, n in collections.Counter(r["Tags"] for r in rows).items():
    if tag not in ("Oxford", "Extra"): errors.append(f"неизвестный тег «{tag}» у {n} слов")
print(f"тем: {len(count)}, слов: {len(rows)}, Oxford {sum(1 for r in rows if r['Tags']=='Oxford')}, Extra {sum(1 for r in rows if r['Tags']=='Extra')}")
for e in errors: print("  ✗", e)
sys.exit(1 if errors else 0)
