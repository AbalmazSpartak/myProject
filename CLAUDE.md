# Swift & SwiftUI Project Rules

## Tech Stack
- Language: Swift 6 (language mode 6, strict concurrency; default actor isolation — MainActor)
- Framework: SwiftUI / Composable Architecture (укажите ваше)
- Target: iOS 18+ / macOS (iOS 18 needed for Translation in text scan)

## Build and Test Commands
- Build: xcodebuild -project myProject.xcodeproj -target myProject -sdk iphonesimulator -configuration Debug build
  - Builds the target directly; the app lands in `build/Debug-iphonesimulator/myProject.app` (gitignored) — install it with `xcrun simctl install <device> <path>` to check screens.
  - The scheme is shared (`myProject.xcodeproj/xcshareddata/xcschemes/myProject.xcscheme`) since 2026-10-03; before that the auto-generated scheme once reported BUILD SUCCEEDED without compiling. If any build shows no `SwiftCompile` steps after source changes, don't trust it.
- Test: there are no test targets yet.

## Word List (master database)
- `myProject/Resources/words.csv` is the single source of truth for built-in words. Edit it, never regenerate it from an external spreadsheet export without merging.
- Columns: `Word,PoS,IPA,Translation,Example,Level,Topic,Tags`. IPA without brackets, translation variants separated by commas, target word in the example marked `<b>…</b>`, one meaning per row.
- After any change run: `python3 scripts/validate_words.py` (exit code 1 = errors). New level files: `python3 scripts/validate_words.py path/to/file.csv`.
- Then regenerate the lookup list for checking new words against the base: `python3 scripts/export_word_list.py` (writes `existing_words.txt`).
## Code Style Guide
- Use modern Swift concurrency (async/await), avoid completion handlers.
- Keep SwiftUI views small and decomposed.
- Use explicit types only when type inference fails.
