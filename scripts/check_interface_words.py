#!/usr/bin/env python3
"""Словарь «Интерфейс приложений» (interface_words.txt): каждая строка «слово|часть речи|перевод»
должна точно совпадать с одной строкой words.csv — иначе слово молча не попадёт в словарь. Код выхода 1 — есть ошибки."""
import csv, sys
from pathlib import Path

root = Path(__file__).resolve().parent.parent
rows = list(csv.DictReader(open(root / "myProject/Resources/words.csv", encoding="utf-8")))
base = {(r["Word"].lower(), r["PoS"], r["Translation"]) for r in rows}

errors, seen, count = [], set(), 0
for n, line in enumerate((root / "myProject/Resources/interface_words.txt").read_text(encoding="utf-8").splitlines(), 1):
    line = line.strip()
    if not line or line.startswith("#"):
        continue
    parts = [p.strip() for p in line.split("|")]
    if len(parts) != 3:
        errors.append(f"строка {n}: нужно «слово|часть речи|перевод» → {line}")
        continue
    key = (parts[0].lower(), parts[1], parts[2])
    if key not in base:
        errors.append(f"строка {n}: нет в words.csv (слово, часть речи и перевод должны совпадать) → {line}")
    if key in seen:
        errors.append(f"строка {n}: повтор → {line}")
    seen.add(key)
    count += 1

print(f"словарь «Интерфейс приложений»: {count} слов")
for e in errors:
    print("  ✗", e)
sys.exit(1 if errors else 0)
