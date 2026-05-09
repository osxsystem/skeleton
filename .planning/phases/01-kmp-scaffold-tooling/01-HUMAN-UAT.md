---
status: partial
phase: 01-kmp-scaffold-tooling
source: [01-08-PLAN.md, 01-08-SUMMARY.md]
started: 2026-05-09T00:00:00Z
updated: 2026-05-09T00:00:00Z
---

## Current Test

[awaiting human testing on Mac + Xcode 16]

## Tests

### 1. Build the SkeletonKit XCFramework
expected: `./gradlew :shared-components:assembleSkeletonKitReleaseXCFramework` succeeds; the framework appears at `shared-components/build/XCFrameworks/release/SkeletonKit.xcframework`.
result: pending

### 2. Create the iosApp Xcode project
expected: Xcode → File → New → Project → iOS App (SwiftUI). Product Name `iosApp`, Bundle ID `dev.viethung.skeleton.ios`. Saved into `iosApp/` so `iosApp/iosApp.xcodeproj` exists. Minimum deployment target = iOS 17.0.
result: pending

### 3. Wire committed Swift sources into the project
expected: Drag `iosApp/iosApp/Common/IosViewModelStoreOwner.swift`, `iosApp/iosApp/App/AppKoinBridge.swift`, `iosApp/iosApp/Greeting/GreetingScreen.swift` into the project navigator. Replace Xcode-generated `iosApp.swift` and `ContentView.swift` with the committed versions.
result: pending

### 4. Embed SkeletonKit framework
expected: Targets → iosApp → General → Frameworks, Libraries, and Embedded Content → + → add `SkeletonKit.xcframework` → set to Embed & Sign.
result: pending

### 5. Add `-lsqlite3` linker flag
expected: Build Settings → Other Linker Flags → add `-lsqlite3`.
result: pending

### 6. Compile and run on iOS 17 simulator
expected: ⌘B compiles green. Run on iPhone 15 / iOS 17 simulator. "Hello, KMP" (or whatever the Greeting use-case returns) renders on screen.
result: pending

### 7. Verify @StateObject deinit lifecycle
expected: Push a second view (`NavigationLink` to a trivial `Text("ok")` view), then pop back. Xcode console must show `[IosViewModelStoreOwner] deinit cleared store`. This proves D-12 / Pitfall 1+2 / SCAF-05 are working at runtime.
result: pending

## Summary

total: 7
passed: 0
issues: 0
pending: 7
skipped: 0
blocked: 0

## Gaps

(none recorded yet — fill in when running the tests on Mac + Xcode)
