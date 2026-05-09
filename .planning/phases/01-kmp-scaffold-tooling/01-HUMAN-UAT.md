---
status: partial
phase: 01-kmp-scaffold-tooling
source: [01-08-PLAN.md, 01-08-SUMMARY.md, 01-11-PLAN.md, 01-12-PLAN.md, 01-13-PLAN.md]
started: 2026-05-09T00:00:00Z
updated: 2026-05-09T04:30:00Z
---

## Current Test

[awaiting human testing on Mac + Xcode 16]
[blocked on 3 build-infra defects — see "Pre-Flight Build-Infra Gate" below]

## Post Gap-Closure Status (Plans 01-11..01-13)

Wave 1 gap-closure source has been applied to develop. Each fix is reviewed and consistent at the source level:

| Fix | Gap | What Changed |
|-----|-----|-------------|
| CR-01 | GreetingRepository never bound | `GreetingRepositoryImpl.kt` created (SQLDelight-backed); `factory<GreetingRepository> { GreetingRepositoryImpl(get()) }` added to `appModule` |
| CR-02 | iOS DatabaseDriverFactory unbound | `iosPlatformModule` created in `shared-app/iosMain`; `initKoin(vararg platformModules: Module)` accepts platform modules; `AppKoinBridge.swift` passes `iosPlatformModule` |
| CR-05 | GreetingViewModelFactory bypassed ViewModelStore | Factory now resolves `GetGreetingUseCase` from Koin and constructs `GreetingViewModel(useCase)` directly so `ViewModelStore` owns the instance |
| WR-01 | kotlinx-datetime prohibited dependency | Removed from `shared-core/build.gradle.kts` and `gradle/libs.versions.toml` |
| WR-05 | CI SKIE gate exited 0 on missing headers | `ci.yml` SKIE header gate and XCFramework path check now `exit 1` with ERROR |

Source commits (on `develop`): `d99e084`, `ac107bd`, `8de2a24`, `49f3671`, `4b05e5f` (01-11/12), `14f3e9d`, `946fde8`, `179da63` (01-13).

## Pre-Flight Build-Infra Gate (BLOCKING — must close before Tests 1–7)

The post-merge build gate could not run on the orchestrator's machine due to three accumulated 01-01 defects. These must be resolved before `./gradlew :shared-components:assembleSkeletonKitReleaseXCFramework` can succeed for Test 1:

- [ ] **A. `gradlew` script is missing.** Only `gradle/wrapper/gradle-wrapper.properties` is committed. Generate `gradlew` and `gradlew.bat` from a Gradle 9.5.0 distribution.
- [ ] **B. `gradle/wrapper/gradle-wrapper.jar` is missing.** Same source.
- [ ] **C. `build.gradle.kts:3` plugin spec.** Line `kotlin("jvm") apply false` has no version. Either change to `alias(libs.plugins.kotlin.jvm) apply false` (requires a `kotlin-jvm` entry in `gradle/libs.versions.toml [plugins]`) or remove the line if no module uses it (only `:server` has a JVM target — verify it has its own plugin block).

Recommended path: open a focused 01-15 plan to close A/B/C with their own atomic commits before running the iOS UAT below. After A/B/C are green, this section can be marked closed.

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
