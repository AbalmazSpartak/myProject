# Swift & SwiftUI Project Rules

## Tech Stack
- Language: Swift 6
- Framework: SwiftUI / Composable Architecture (укажите ваше)
- Target: iOS 17+ / macOS

## Build and Test Commands
- Build: xcodebuild -project myProject.xcodeproj -scheme myProject -destination "platform=iOS Simulator,name=iPhone 16e,OS=18.6" build
- Test: xcodebuild -project myProject.xcodeproj -scheme myProject -destination "platform=iOS Simulator,name=iPhone 16e,OS=18.6" test

## Word List (master database)
- `myProject/Resources/words.csv` is the single source of truth for built-in words. Edit it, never regenerate it from an external spreadsheet export without merging.
- Columns: `Word,PoS,IPA,Translation,Example,Level,Topic,Tags`. IPA without brackets, translation variants separated by commas, target word in the example marked `<b>…</b>`, one meaning per row.
- After any change run: `python3 scripts/validate_words.py` (exit code 1 = errors). New level files: `python3 scripts/validate_words.py path/to/file.csv`.
- Then regenerate the lookup list for checking new words against the base: `python3 scripts/export_word_list.py` (writes `existing_words.txt`).
## Code Style Guide
- Use modern Swift concurrency (async/await), avoid completion handlers.
- Keep SwiftUI views small and decomposed.
- Use explicit types only when type inference fails.
