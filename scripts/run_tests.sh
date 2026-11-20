#!/bin/bash
# Все автоматические проверки без телефона: слова (скрипты) и логика приложения (Swift на компьютере).
# Запуск из корня репозитория: ./scripts/run_tests.sh
set -u
cd "$(dirname "$0")/.."
status=0

echo "== Слова: структура и ошибки =="
python3 scripts/validate_words.py || status=1

echo; echo "== Слова: темы и теги =="
python3 scripts/check_words_topics.py || status=1

echo; echo "== Логика приложения (Swift) =="
BIN="$(mktemp -d)/logic-tests"
swiftc -swift-version 6 -default-isolation MainActor -enable-upcoming-feature NonisolatedNonsendingByDefault -o "$BIN" \
  Shared/BookParser.swift Shared/ZipArchive.swift Shared/Book.swift Shared/Word.swift Shared/Category.swift Shared/WordList.swift \
  Shared/CommunityTopic.swift Shared/TopicBlock.swift Shared/TopicComment.swift Shared/UserProfile.swift Shared/StudyScope.swift \
  Shared/FSRSCalculator.swift Shared/StudyLimits.swift Shared/DailyStreak.swift Shared/DailyStudy.swift Shared/AppGroup.swift \
  myProject/Services/AppMode.swift myProject/Services/TranscriptionLookup.swift myProject/Services/PDFBook.swift \
  myProject/Services/RussianPlural.swift myProject/Views/Books/PhonicsPalette.swift myProject/Models/BookMarks.swift myProject/Models/BookWordOrder.swift \
  scripts/logic-tests/main.swift 2>&1 | grep -E "error" | head -20
if [ -x "$BIN" ]; then "$BIN" || status=1; else echo "Не удалось собрать тесты логики"; status=1; fi

echo; [ $status -eq 0 ] && echo "ИТОГ: всё в порядке" || echo "ИТОГ: есть ошибки (см. выше)"
exit $status
