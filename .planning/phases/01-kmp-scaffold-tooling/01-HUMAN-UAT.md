---
status: partial
phase: 01-kmp-scaffold-tooling
source: [01-08-PLAN.md, 01-08-SUMMARY.md, 01-11-PLAN.md, 01-12-PLAN.md, 01-13-PLAN.md, 01-15-PLAN.md, 01-16-PLAN.md]
started: 2026-05-09T00:00:00Z
updated: 2026-05-09T22:00:00Z
---

## Current Test

[awaiting human testing on Mac + Xcode 16]
[BI-A/B/C/D/E closed by 01-15; BI-F migration done by 01-16 but blocked by new BI-G/BI-H/BI-I discovered during compilation — Android smoke still not green]

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

## Pre-Flight Build-Infra Gate

- [x] **A. `gradlew` script is missing.** CLOSED by 01-15 — generated via `gradle wrapper` from a Gradle 9.5.0 distribution against an empty temp project (the live project's plugins block tripped AGP 9 conflicts during wrapper task evaluation).
- [x] **B. `gradle/wrapper/gradle-wrapper.jar` is missing.** CLOSED by 01-15 — same source as BI-A.
- [x] **C. `build.gradle.kts:3` plugin spec.** CLOSED by 01-15 — replaced `kotlin("jvm") apply false` with `alias(libs.plugins.kotlin.jvm) apply false`; added `kotlin-jvm = { id = "org.jetbrains.kotlin.jvm", version.ref = "kotlin" }` to `gradle/libs.versions.toml [plugins]`.

### Discovered & closed during 01-15 (out of original scope, user-authorized inline fixes)

- [x] **D. KSP version `2.3.21-2.0.4` does not exist upstream.** CLOSED by 01-15 — bumped to `ksp = "2.3.7"` (Maven Central latest for the 2.3.x line; KSP2 dropped the `<kotlin>-<ksp>` legacy naming). CLAUDE.md tech stack table needs a follow-up doc fix.
- [x] **E. AGP 9 + `kotlin.multiplatform` + `com.android.application` extension conflict.** CLOSED by 01-15 — added `android.builtInKotlin=false` and `android.newDsl=false` to `gradle.properties` as the upstream-recommended temporary bypass. Long-term fix per AGP 9 guidance: either remove `kotlin.multiplatform` from `androidApp` (let built-in Kotlin handle Android-side compilation) or restructure androidApp to use `com.android.kotlin.multiplatform.library`. Tracked for follow-up.

### Partially migrated by 01-16 — BI-F DSL migration done; new blockers BI-G/BI-H/BI-I discovered

- [x] **F. KMP modules use pre-AGP-9 `android {}` DSL.** PARTIALLY CLOSED by 01-16 — `shared-core`, `shared-components`, `shared-app` migrated to `kotlin { android { namespace; compileSdk; minSdk; compilerOptions { jvmTarget.JVM_21 }; withHostTestBuilder {} } }`. `androidTarget()` removed. Top-level `android {}` blocks deleted from KMP modules. `androidApp` dropped `kotlin.multiplatform` (built-in Kotlin + Compose Compiler plugin). BI-E bypass flags reverted. Build configuration now progresses past DSL errors. However, NEW compilation blockers surfaced (BI-G/BI-H/BI-I — see below). Android smoke is still NOT green.

### Discovered during 01-16, NOT closed — current blockers

- [ ] **G. `GreetingViewModelFactory.kt` uses `GlobalContext` in `commonMain` — unresolved on non-JVM targets (BLOCKING).** `shared-app/src/commonMain/kotlin/.../GreetingViewModelFactory.kt:6` imports `org.koin.core.context.GlobalContext` which is not available in the Kotlin/Native metadata compilation (`compileCommonMainKotlinMetadata`) or iOS targets (`compileKotlinIosArm64`, `compileKotlinIosSimulatorArm64`). Fails with `Unresolved reference 'GlobalContext'`. This cascades to `:androidApp:compileDebugKotlin` which cannot resolve types from `:shared-app`. Fix: replace `GlobalContext.get().get<GetGreetingUseCase>()` with a Koin component pattern or pass the use-case as a constructor argument (removing the runtime Koin lookup from commonMain). Affected file: `shared-app/src/commonMain/kotlin/dev/viethung/showcase/greeting/GreetingViewModelFactory.kt` — outside plan 01-16 scope.

- [ ] **H. Two `GreetingViewModelTest` tests fail on Android JVM host test (non-blocking if BI-G fixed separately).** `loadGreetingTransitionsToReady` and `loadGreetingOnErrorTransitionsToError` fail with `No item was found` from Turbine's `expectMostRecentItem()`. Root cause: `GreetingViewModel.loadGreeting()` uses `viewModelScope.launch` which requires a coroutine dispatcher; in the test context the coroutine may not complete before `expectMostRecentItem()` is called. Fix: use `advanceUntilIdle()` from `TestCoroutineScheduler` or `awaitItem()` with timeout instead of `expectMostRecentItem()`. Only `initialStateIsLoading` passes (1/3). Affected file: `shared-app/src/commonTest/kotlin/.../GreetingViewModelTest.kt` — outside plan 01-16 scope.

- [ ] **I. SKIE 0.10.11 does not support Kotlin 2.3.21 (BLOCKING for iOS, non-blocking for Android).** SKIE 0.10.11 supports Kotlin up to 2.3.20; the project uses 2.3.21. SKIE has been temporarily disabled (`skie { isEnabled = false }`) in `shared-components/build.gradle.kts` to unblock Android configuration. This disables Swift interop generation; iOS build cannot produce `SkeletonKit.xcframework`. Fix: upgrade SKIE to a version supporting 2.3.21 (requires `libs.versions.toml` change, out of scope for 01-16). Alternatively, downgrade Kotlin to 2.3.20. Track for a dedicated plan.

**Current state:** A/B/C/D/E closed. F migration done (DSL correct) but blocked from closing completely by BI-G. G/H/I open. Android smoke (`./gradlew :androidApp:assembleDebug`) fails due to BI-G cascade. iOS Tests 1–7 remain blocked by BI-I.

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

```yaml
- truth: "`./gradlew` script exists at repo root and is executable"
  status: closed
  closed_by: 01-15 (commit 7e20b82)
  defect_id: BI-A

- truth: "`gradle/wrapper/gradle-wrapper.jar` exists in the repo so `./gradlew` can bootstrap"
  status: closed
  closed_by: 01-15 (commit 7e20b82)
  defect_id: BI-B

- truth: "Root `build.gradle.kts` plugins block compiles — every plugin spec carries a version or comes from a versioned source"
  status: closed
  closed_by: 01-15 (commit dcee746)
  defect_id: BI-C

- truth: "KSP plugin version pinned in libs.versions.toml exists upstream"
  status: closed
  closed_by: 01-15 (commit d4859b5) — ksp bumped from 2.3.21-2.0.4 (legacy KSP1 naming, never published) to 2.3.7
  defect_id: BI-D
  follow_up: "CLAUDE.md tech stack table still lists KSP 2.3.21-2.0.4; update to 2.3.7 in a doc-only plan."

- truth: "AGP 9 + `kotlin.multiplatform` + `com.android.application` configure without extension conflict"
  status: closed
  closed_by: 01-15 (commit fad8968) — added android.builtInKotlin=false + android.newDsl=false as temporary bypass
  defect_id: BI-E
  follow_up: "Long-term: either remove kotlin.multiplatform from androidApp or restructure to com.android.kotlin.multiplatform.library. See https://kotl.in/gradle/agp-new-kmp"

- truth: "shared-* KMP build.gradle.kts files configure successfully under AGP 9"
  status: partial
  reason: "DSL migration done by 01-16 — all three modules now use kotlin { android { namespace; compileSdk; minSdk; compilerOptions; withHostTestBuilder {} } }. Configuration passes. But compilation fails due to BI-G (GlobalContext in commonMain)."
  closed_by: "01-16 (commits 77e52e8, 5cac60a, 7fadc45) — DSL shape correct; blocked at compilation by BI-G"
  defect_id: BI-F
  blocks: [1, 2, 3, 4, 5, 6, 7]

- truth: "`./gradlew :androidApp:assembleDebug --no-daemon` exits 0"
  status: failed
  reason: ":shared-app:compileCommonMainKotlinMetadata fails: GreetingViewModelFactory.kt:6,27 imports org.koin.core.context.GlobalContext which is not resolvable in commonMain Kotlin metadata compilation. Error: 'Unresolved reference GlobalContext'. Cascades to :androidApp:compileDebugKotlin which cannot resolve types from :shared-app."
  severity: blocker
  defect_id: BI-G
  artifacts: ["shared-app/src/commonMain/kotlin/dev/viethung/showcase/greeting/GreetingViewModelFactory.kt"]
  recommendation: "Replace GlobalContext.get().get<GetGreetingUseCase>() with a pure constructor injection or KoinComponent pattern that works in commonMain (no runtime Koin context lookup). Fix is in a single source file outside plan 01-16 scope."
  blocks: [1, 2, 3, 4, 5, 6, 7]

- truth: "`./gradlew :shared-app:allTests --no-daemon` exits 0 — GreetingViewModelTest passes"
  status: failed
  reason: "2/3 tests fail: loadGreetingTransitionsToReady and loadGreetingOnErrorTransitionsToError both fail with 'No item was found' from Turbine expectMostRecentItem(). viewModelScope.launch() dispatches coroutine asynchronously; test calls expectMostRecentItem() before the coroutine completes. Also blocked by BI-G (iOS compilation failure in allTests dependency chain)."
  severity: major
  defect_id: BI-H
  artifacts: ["shared-app/src/commonTest/kotlin/dev/viethung/showcase/greeting/GreetingViewModelTest.kt"]
  recommendation: "Add advanceUntilIdle() after loadGreeting() call, or switch from expectMostRecentItem() to awaitItem() with proper coroutine advancement."

- truth: "SKIE Swift interop generation works with Kotlin 2.3.21"
  status: failed
  reason: "SKIE 0.10.11 supports Kotlin up to 2.3.20. Project uses 2.3.21. skie { isEnabled = false } applied in shared-components/build.gradle.kts as upstream workaround to unblock Android builds. iOS XCFramework (SkeletonKit) will not contain SKIE-generated Swift interfaces."
  severity: major
  defect_id: BI-I
  artifacts: ["shared-components/build.gradle.kts"]
  recommendation: "Upgrade SKIE to a version that supports Kotlin 2.3.21 (requires libs.versions.toml change), or downgrade Kotlin to 2.3.20. Check https://github.com/touchlab/SKIE/releases for Kotlin 2.3.21 support."
  blocks: [1, 2, 3, 4, 5, 6, 7]
```
