#!/usr/bin/env python3
"""Проверка мастер-базы слов (myProject/Resources/words.csv).

Запуск из корня репозитория:
    python3 scripts/validate_words.py                 # проверить words.csv
    python3 scripts/validate_words.py path/to/new.csv # проверить другой файл (например, новый уровень)
    python3 scripts/validate_words.py --strict        # предупреждения тоже считаются ошибками

Ошибки ломают загрузку или карточки — код выхода 1.
Предупреждения — нарушения стандарта мастер-базы, которые стоит поправить.
"""
import argparse
import collections
import csv
import re
import sys
from pathlib import Path

DEFAULT_PATH = Path(__file__).resolve().parent.parent / "myProject" / "Resources" / "words.csv"
HEADER = ["Word", "PoS", "IPA", "Translation", "Example", "Level", "Topic", "Tags"]
LEVELS = {"A1", "A2", "B1", "B2", "C1", "C2"}
# Должно совпадать с группами в StudyScope.partOfSpeechGroups
KNOWN_POS = {"n.", "v.", "modal v.", "phr. v.", "adj.", "adv.", "pron.", "prep.", "conj.",
             "det.", "art.", "num.", "part.", "excl.", "exclam.", "phr."}
CAPITALIZED = set("""january february march april may june july august september october november december
monday tuesday wednesday thursday friday saturday sunday""".split())


def word_forms(word):
    """Формы слова, которые считаются «тем же словом» в примере."""
    w = word.lower()
    forms = {w, w + "s", w + "es", w + "ed", w + "d", w + "ing"}
    if w.endswith("e"):
        forms |= {w[:-1] + "ing", w[:-1] + "ed"}
    if w.endswith("y"):
        forms |= {w[:-1] + "ies", w[:-1] + "ied"}
    return forms


def check(path):
    errors, warnings = [], []
    text = path.read_text(encoding="utf-8-sig")
    rows = list(csv.reader(text.splitlines()))
    if not rows:
        return ["файл пустой"], [], [], []

    start = 1 if [c.strip() for c in rows[0]] == HEADER else 0
    if start == 0:
        warnings.append("нет строки заголовков: " + ",".join(HEADER))

    good_rows = []
    for line_no, row in enumerate(rows[start:], start=start + 1):
        where = f"строка {line_no}"
        if not any(cell.strip() for cell in row):
            continue
        if len(row) != 8:
            errors.append(f"{where}: {len(row)} колонок вместо 8 (склеенные строки или лишняя запятая?) → {','.join(row)[:80]}")
            continue
        word, pos, ipa, translation, example, level, topic, tags = row
        where = f"строка {line_no} «{word}» ({pos})"

        if any('"' in cell for cell in row):
            errors.append(f"{where}: кавычка внутри поля — скорее всего, забыта открывающая кавычка")
        for name, value in (("Word", word), ("PoS", pos), ("Translation", translation), ("Level", level), ("Topic", topic)):
            if not value.strip():
                errors.append(f"{where}: пустое обязательное поле {name}")
        if any(cell != cell.strip() for cell in row):
            warnings.append(f"{where}: пробелы в начале или конце поля")

        if level and level not in LEVELS:
            errors.append(f"{where}: неизвестный уровень «{level}»")
        if pos and pos not in KNOWN_POS:
            warnings.append(f"{where}: неизвестная часть речи «{pos}» — добавьте её в StudyScope и в этот скрипт")
        if word.lower() in CAPITALIZED and word[:1].islower() and pos == "n.":
            warnings.append(f"{where}: месяцы и дни недели пишутся с заглавной")
        if ipa and (ipa[0] in "[/" or ipa[-1] in "]/"):
            warnings.append(f"{where}: транскрипция без скобок — приложение добавит /.../ само")
        if " / " in translation:
            warnings.append(f"{where}: варианты перевода разделяются запятой, а не « / »")

        # Пример: ровно одно выделенное слово, ответ не виден в остальной части
        if example:
            opens, closes = example.count("<b>"), example.count("</b>")
            if opens == 0:
                errors.append(f"{where}: в примере нет <b>слово</b> — карточка «Слово в контексте» не построится")
            elif opens != closes:
                errors.append(f"{where}: незакрытый тег <b> в примере")
            else:
                if opens > 1:
                    warnings.append(f"{where}: в примере несколько <b>, пропуск будет только на месте первого")
                m = re.search(r"<b>(.*?)</b>", example)
                rest = (example[:m.start()] + " " + example[m.end():]).replace("<b>", "").replace("</b>", "")
                rest_words = set(re.findall(r"[a-z']+", rest.lower()))
                if word_forms(word) & rest_words:
                    warnings.append(f"{where}: ответ виден в остальной части примера → {example}")
                if m.group(1).lower() not in word_forms(word) and word.lower() not in m.group(1).lower():
                    warnings.append(f"{where}: выделено «{m.group(1)}», это не форма слова «{word}» — проверьте")
        else:
            warnings.append(f"{where}: нет примера")

        good_rows.append((line_no, row))

    # Повторы
    exact = collections.defaultdict(list)
    by_sense = collections.defaultdict(list)
    for line_no, row in good_rows:
        exact[(row[0].lower(), row[1], row[3].lower())].append(line_no)
        by_sense[(row[0].lower(), row[1])].append((line_no, row[5], row[3]))
    for (word, pos, tr), lines in exact.items():
        if len(lines) > 1:
            errors.append(f"повтор «{word}» ({pos}) «{tr}» в строках {lines}")
    senses = []
    for (word, pos), items in by_sense.items():
        if len({lvl for _, lvl, _ in items}) < 2:
            continue
        listed = "; ".join(f"{lvl}: {tr} (стр. {n})" for n, lvl, tr in items)
        # Пересекающиеся переводы — почти наверняка повтор; непересекающиеся — отдельные значения (bank: банк / берег)
        translations = [translation_words(tr) for _, _, tr in items]
        if any(a & b for i, a in enumerate(translations) for b in translations[i + 1:]):
            warnings.append(f"«{word}» ({pos}) повторяется на разных уровнях с похожим переводом: {listed}")
        else:
            senses.append(f"«{word}» ({pos}): {listed}")

    return errors, warnings, [row for _, row in good_rows], senses


def translation_words(translation):
    cleaned = re.sub(r"\(.*?\)", "", translation.lower().replace("ё", "е"))
    return {part.strip() for part in re.split(r"[,;/]", cleaned) if part.strip()}


def main():
    parser = argparse.ArgumentParser(description="Проверка мастер-базы слов")
    parser.add_argument("path", nargs="?", type=Path, default=DEFAULT_PATH)
    parser.add_argument("--strict", action="store_true", help="считать предупреждения ошибками")
    parser.add_argument("--senses", action="store_true", help="показать слова, разделённые на значения по уровням")
    args = parser.parse_args()

    if not args.path.exists():
        print(f"Файл не найден: {args.path}")
        return 1

    errors, warnings, rows, senses = check(args.path)

    for message in errors:
        print(f"❌ {message}")
    for message in warnings:
        print(f"⚠️  {message}")

    if args.senses:
        for message in senses:
            print(f"ℹ️  {message}")

    levels = collections.Counter(row[5] for row in rows)
    topics = {row[6] for row in rows}
    summary = ", ".join(f"{lvl} {levels[lvl]}" for lvl in sorted(levels))
    print(f"\n{args.path.name}: {len(rows)} слов ({summary}), тем: {len(topics)}")
    print(f"Отдельных значений одного слова на разных уровнях: {len(senses)}" + ("" if args.senses else " (список: --senses)"))
    print(f"Ошибок: {len(errors)}, предупреждений: {len(warnings)}")

    failed = errors or (args.strict and warnings)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
