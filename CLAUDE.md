# Swift & SwiftUI Project Rules

## Tech Stack
- Language: Swift 6 (language mode 6, strict concurrency; default actor isolation — MainActor)
- Framework: SwiftUI + SwiftData (no Composable Architecture)
- Target: iOS 18.0+, iPhone and iPad, plus the `WordWidget` widget extension (iOS 18 needed for Translation in text scan). Mac/visionOS appear in the target's supported platforms but are not tested.
- Packages: FluidAudio (Kokoro neural voice on Neural Engine), sherpa-onnx (Piper voices).

## Two Apps, Two Branches
- **LexiStream** (bundle id `com.personalteam.lexistream`, new design) lives in branch `lexistream-dev`.
- **WordLearner** (original app) lives in `main`.
- Same project and scheme (`myProject`) in both; the branch decides which app gets built. Commit work for an app to its branch; other branches only for temporary experiments. Shared code needed by both apps: ask before cherry-picking it to the other branch.

## Build and Test Commands
- Build (simulator): xcodebuild -project myProject.xcodeproj -scheme myProject -destination 'generic/platform=iOS Simulator' -configuration Debug build
- Build (iPhone): xcodebuild -project myProject.xcodeproj -scheme myProject -destination 'generic/platform=iOS' -configuration Debug -allowProvisioningUpdates build
  - Build with `-scheme`, not `-target`: since the FluidAudio package (Kokoro on Neural Engine) was added, `-target` fails with «failed creating index directory '-I/Users/…': Read-only file system» (and leaves junk in `myProject.xcodeproj/-Xcc/`, gitignored).
  - The app lands in DerivedData (`~/Library/Developer/Xcode/DerivedData/myProject-*/Build/Products/Debug-iphoneos/myProject.app`); install on the iPhone with `xcrun devicectl device install app --device <id> <path>`, on a simulator with `xcrun simctl install <device> <path>`.
  - The scheme is shared (`myProject.xcodeproj/xcshareddata/xcschemes/myProject.xcscheme`) since 2026-10-03; before that the auto-generated scheme once reported BUILD SUCCEEDED without compiling. If any build shows no `SwiftCompile` steps after source changes, don't trust it.
- Install on the iPhone: the `/install` skill (`.claude/skills/install/`) builds, checks for `SwiftCompile` steps and the phone lock state, then installs.
- Test: `./scripts/run_tests.sh` — word list checks plus logic tests (`scripts/logic-tests/main.swift`, compiled with `swiftc` on the Mac, no phone needed). There is no Xcode test target; UI is checked on the simulator/iPhone.

## Servers
- `server/account` (login and account), `server/ai` (AI hints and book word translation, with quotas and a monthly budget), `server/word-race` — Cloudflare Workers deployed with `wrangler`.
- Local secrets live in `server/**/.dev.vars` (gitignored); never commit keys.

## Word List (master database)
- `myProject/Resources/words.csv` is the single source of truth for built-in words. Edit it, never regenerate it from an external spreadsheet export without merging.
- Columns: `Word,PoS,IPA,Translation,Example,Level,Topic,Tags`. IPA without brackets, translation variants separated by commas, target word in the example marked `<b>…</b>`, one meaning per row.
- After any change run: `python3 scripts/validate_words.py` (exit code 1 = errors). New level files: `python3 scripts/validate_words.py path/to/file.csv`.
- Then regenerate the lookup list for checking new words against the base: `python3 scripts/export_word_list.py` (writes `existing_words.txt`).
- Both steps run automatically after any Claude edit of `words.csv` (hook `.claude/hooks/words-check.sh`); read its output and fix reported errors.

## Code Style Guide
- Use modern Swift concurrency (async/await), avoid completion handlers.
- Keep SwiftUI views small and decomposed.
- Use explicit types only when type inference fails.
