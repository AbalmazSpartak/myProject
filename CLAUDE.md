# Swift & SwiftUI Project Rules

## Tech Stack
- Language: Swift 6
- Framework: SwiftUI / Composable Architecture (укажите ваше)
- Target: iOS 17+ / macOS

## Build and Test Commands
- Build: xcodebuild -project myProject.xcodeproj -scheme myProject -destination "platform=iOS Simulator,name=iPhone 16e,OS=18.6" build
- Test: xcodebuild -project myProject.xcodeproj -scheme myProject -destination "platform=iOS Simulator,name=iPhone 16e,OS=18.6" test

## Code Style Guide
- Use modern Swift concurrency (async/await), avoid completion handlers.
- Keep SwiftUI views small and decomposed.
- Use explicit types only when type inference fails.
