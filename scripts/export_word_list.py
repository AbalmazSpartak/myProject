#!/usr/bin/env python3
"""Список слов мастер-базы для сверки новых слов из интернета.

Пишет existing_words.txt: одна строка на значение, по алфавиту —
«слово | часть речи | уровень | перевод». Запускать после каждого изменения words.csv:
    python3 scripts/export_word_list.py
"""
import csv
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "myProject" / "Resources" / "words.csv"
TARGET = ROOT / "existing_words.txt"


def main():
    with SOURCE.open(encoding="utf-8-sig", newline="") as f:
        rows = list(csv.DictReader(f))

    rows.sort(key=lambda r: (r["Word"].lower(), r["PoS"], r["Level"]))
    levels = Counter(r["Level"] for r in rows)
    unique_words = len({r["Word"].lower() for r in rows})

    lines = [
        "# Слова мастер-базы (myProject/Resources/words.csv) — для сверки новых слов",
        "# Обновить: python3 scripts/export_word_list.py",
        f"# Значений: {len(rows)}, разных слов: {unique_words}; "
        + ", ".join(f"{level} {levels[level]}" for level in sorted(levels)),
        "# слово | часть речи | уровень | перевод",
        "",
    ]
    lines += [f'{r["Word"]} | {r["PoS"]} | {r["Level"]} | {r["Translation"]}' for r in rows]
    TARGET.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"{TARGET.relative_to(ROOT)}: {len(rows)} значений, {unique_words} слов")


if __name__ == "__main__":
    main()
