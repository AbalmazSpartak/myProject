---
name: install
description: Собрать приложение (LexiStream или WordLearner — по текущей ветке) и поставить на iPhone пользователя. Использовать, когда пользователь пишет «/install», «поставь на телефон», «установи на iPhone».
---

# /install — сборка и установка на iPhone

Делай шаги по порядку. На каждом шаге при ошибке — остановись и коротко объясни по-русски, что случилось.

## 1. Что собираем
- `git branch --show-current`: `lexistream-dev` → LexiStream (`com.personalteam.lexistream`), `main` → WordLearner. Другая ветка — скажи пользователю, какая, и спроси, ставить ли.
- `git status --short` — если есть чужие незакоммиченные правки (параллельные окна), просто упомяни это; сборка возьмёт файлы как есть.

## 2. Телефон доступен?
```
xcrun devicectl device info lockState --device 00008101-000208E23CD0001E
```
- `passcodeRequired: false` — дальше без вопросов.
- `passcodeRequired: true` или телефон не найден — написать «нужен телефон — разблокируйте» и ждать. Сборку (шаг 3) можно запустить заранее.
- Только iPhone. Про iPad в ответе не писать.

## 3. Сборка (команда из CLAUDE.md)
```
xcodebuild -project myProject.xcodeproj -scheme myProject -destination 'generic/platform=iOS' -configuration Debug -allowProvisioningUpdates build 2>&1 | tee /tmp/claude-501/install-build.log | tail -5
```
- Только `-scheme`, не `-target`.
- Проверь, что код правда скомпилирован: `grep -c SwiftCompile /tmp/claude-501/install-build.log`. Если 0 после правок в исходниках — сборке не верить, сказать пользователю.
- При `BUILD FAILED`: показать первые ошибки (`grep -E "error:" … | head -10`), не устанавливать.

## 4. Установка
```
APP=$(ls -d ~/Library/Developer/Xcode/DerivedData/myProject-*/Build/Products/Debug-iphoneos/myProject.app | head -1)
xcrun devicectl device install app --device 00008101-000208E23CD0001E "$APP"
```
- Если ошибка подписи или профиль истёк — повторить шаг 3 (там уже `-allowProvisioningUpdates`), потом шаг 4.

## 5. Отчёт
Коротко, по формату пользователя: «Что сделано» (какое приложение, ветка, коммит `git log -1 --oneline`, установлено) → «На что обратить внимание» (предупреждения, если были). Если работа требует проверки на телефоне — напомнить про карточку проверки на доске TaskForge.
