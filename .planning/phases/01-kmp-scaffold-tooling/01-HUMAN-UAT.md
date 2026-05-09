---
status: partial
phase: 01-kmp-scaffold-tooling
source: [01-08-PLAN.md, 01-08-SUMMARY.md, 01-11-PLAN.md, 01-12-PLAN.md, 01-13-PLAN.md, 01-15-PLAN.md, 01-16-PLAN.md, 01-17-PLAN.md]
started: 2026-05-09T00:00:00Z
updated: 2026-05-09T14:30:00Z
---

## Current Test

Android smoke (BI-A through BI-H closed): PASSED (`./gradlew :androidApp:assembleDebug` exits 0; APK produced)
iOS tests 1–7: blocked on BI-I (SKIE upstream — Kotlin 2.3.21 support not yet released) and BI-J (iOS framework linker — missing -lsqlite3 in shared-app + shared-components framework declarations)

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

- [x] **F. KMP modules use pre-AGP-9 `android {}` DSL.** CLOSED by 01-16 (DSL migration) + 01-17 (downstream defects cleared) — `shared-core`, `shared-components`, `shared-app` use `kotlin { android { … withHostTestBuilder {} } }`; `androidTarget()` removed; top-level `android {}` deleted; `androidApp` dropped `kotlin.multiplatform` and uses Compose Compiler via catalog alias; BI-E bypass flags reverted; smoke now green via `./gradlew :androidApp:assembleDebug`.

### Discovered during 01-16, closed by 01-17

- [x] **G. `GreetingViewModelFactory.kt` uses `GlobalContext` in `commonMain` — unresolved on non-JVM targets.** CLOSED by 01-17 — replaced `org.koin.core.context.GlobalContext` (JVM-favored) with `org.koin.mp.KoinPlatformTools.defaultContext()` (Koin 4.x KMP-correct accessor). `:shared-app:compileCommonMainKotlinMetadata` and Native targets now compile.

- [x] **H. Two `GreetingViewModelTest` tests fail on Android JVM host test.** CLOSED by 01-17 — added `Dispatchers.setMain(StandardTestDispatcher())` + `Dispatchers.resetMain()` BeforeTest/AfterTest pair, and `advanceUntilIdle()` after each `vm.loadGreeting()` to synchronize on `viewModelScope.launch` completion. `:shared-app:allTests` now exits 0 with 3/3 passing.

- [ ] **I. SKIE 0.10.11 does not support Kotlin 2.3.21 (UPSTREAM BLOCKER — non-blocking for Android).** SKIE 0.10.11 (latest upstream release as of 2026-05-09; published 2026-04-02) supports Kotlin 2.0.0 .. 2.3.20. The project pins Kotlin 2.3.21. No SKIE release with 2.3.21 support exists yet. Workaround `skie { isEnabled = false }` in `shared-components/build.gradle.kts` stays in place. Upstream check pattern (re-run periodically):
  ```bash
  gh api repos/touchlab/SKIE/releases --jq '.[0:3] | .[] | "\(.tag_name) - \(.published_at[:10])"'
  ```
  When a SKIE > 0.10.11 with 2.3.21 support ships, open a follow-up plan to bump `skie` in `gradle/libs.versions.toml` and remove the `isEnabled = false` line. Disabling SKIE blocks iOS XCFramework generation (Tests 1–7 cannot proceed) but does not affect Android assembleDebug. Tracked separately from build-infra A–H gates.

### Discovered during 01-17, NOT closed

- [ ] **J. iOS framework linker missing `-lsqlite3` in `shared-app` and `shared-components` framework declarations (BLOCKING for iOS framework build, non-blocking for Android).** `shared-app/build.gradle.kts` and `shared-components/build.gradle.kts` iOS framework declarations do not include `linkerOpts.add("-lsqlite3")`. `shared-core/build.gradle.kts` correctly has it (line 27), but the umbrella frameworks in `shared-app` and `shared-components` do not inherit it. Error: `ld: Undefined symbols: _sqlite3_bind_blob, _sqlite3_bind_double, ...` during `:shared-app:linkDebugFrameworkIosArm64` and `:shared-components:linkReleaseFrameworkIosArm64`. Fix: add `linkerOpts.add("-lsqlite3")` to the `iosTarget.binaries.framework {}` block in both `shared-app/build.gradle.kts` and `shared-components/build.gradle.kts`. These files are outside 01-17 deviation-protocol scope. Assign to a follow-up plan.

**Current state:** A through H closed (build-infra fully resolved for Android). I open as upstream blocker (SKIE/Kotlin compatibility). J open as iOS framework linker defect. Android smoke (`./gradlew :androidApp:assembleDebug`) PASSES. iOS Tests 1–7 remain blocked on BI-I and BI-J. 01-14 Android smoke checkpoint is unblocked; iOS UAT awaits BI-I and BI-J resolution.

### Smoke command notes (01-14)

- **Android-only smoke (PASSES):** `./gradlew :androidApp:assembleDebug --no-daemon` exits 0; APK at `androidApp/build/outputs/apk/debug/androidApp-debug.apk`. This is the meaningful Android-side gate.
- **Full multi-target smoke (FAILS on iOS link):** `./gradlew :shared-core:build :shared-components:build :shared-app:build :androidApp:assembleDebug` fails on `:shared-*:linkDebugFrameworkIos*` due to BI-J. The Android-side compilation paths inside that command all pass; only the iOS link sub-tasks fail. Use `:androidApp:assembleDebug` (Android-only) as the gate until BI-J is closed.

## iOS Pre-Flight Checklist (Before Starting HUMAN-UAT Tests 1–7)

iOS UAT cannot start yet — both BI-I (SKIE upstream) and BI-J (iOS framework -lsqlite3 missing) block Test 1 (`./gradlew :shared-components:assembleSkeletonKitReleaseXCFramework`). Before running the 7 iOS tests on Mac + Xcode 16, confirm:

- [ ] **BI-I closed:** SKIE > 0.10.11 with Kotlin 2.3.21 support exists and `gradle/libs.versions.toml` is bumped; `skie { isEnabled = false }` removed from `shared-components/build.gradle.kts`. Re-check command:
  ```bash
  gh api repos/touchlab/SKIE/releases --jq '.[0:3] | .[] | "\(.tag_name) - \(.published_at[:10])"'
  ```
- [ ] **BI-J closed:** `linkerOpts.add("-lsqlite3")` added to the `iosTarget.binaries.framework {}` block in BOTH `shared-app/build.gradle.kts` AND `shared-components/build.gradle.kts`.
- [ ] **Plans 01-11, 01-12, 01-13, 01-15, 01-16, 01-17 are all complete** (check SUMMARY files).
- [ ] **Android smoke confirmed green** (`./gradlew :androidApp:assembleDebug` exits 0).
- [ ] **XCFramework rebuilt after BI-I/J fix:** `./gradlew :shared-components:assembleSKIEDebugXCFramework`.
- [ ] **IN-03 — SKIE symbol name check:** in the generated `SkeletonKit.framework/Headers`, verify the Swift symbol name for `initKoin`. SKIE may generate `doInitKoin` or `initKoin`. `iosApp/iosApp/App/AppKoinBridge.swift` currently calls `AppModuleKt.doInitKoin(platformModules:)` — update if the header shows a different name.

When all six checklist items are checked, proceed to Tests 1–7 below.

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
  status: closed
  closed_by: "01-16 (commits 77e52e8, 5cac60a, 7fadc45) — DSL migration done; 01-17 (BI-G/H downstream cleared)"
  defect_id: BI-F

- truth: "`./gradlew :androidApp:assembleDebug --no-daemon` exits 0"
  status: closed
  closed_by: "01-17 (commit — Task 4: BI-G fix, shared-core explicit dep, catalog alias)"
  defect_id: BI-G

- truth: "`./gradlew :shared-app:allTests --no-daemon` exits 0 — GreetingViewModelTest passes"
  status: closed
  closed_by: "01-17 (commit ae7d20c — Dispatchers.setMain + advanceUntilIdle)"
  defect_id: BI-H

- truth: "SKIE Swift interop generation works with Kotlin 2.3.21"
  status: failed
  reason: "SKIE 0.10.11 supports Kotlin up to 2.3.20. Project uses 2.3.21. skie { isEnabled = false } applied in shared-components/build.gradle.kts as upstream workaround to unblock Android builds. iOS XCFramework (SkeletonKit) will not contain SKIE-generated Swift interfaces."
  severity: major
  defect_id: BI-I
  disposition: deferred-upstream-blocker
  tracking: "gh api repos/touchlab/SKIE/releases --jq '.[0:3] | .[] | \"\\(.tag_name) - \\(.published_at[:10])\"'"
  artifacts: ["shared-components/build.gradle.kts"]
  recommendation: "Upgrade SKIE to a version that supports Kotlin 2.3.21 (requires libs.versions.toml change). Check https://github.com/touchlab/SKIE/releases."
  blocks: [1, 2, 3, 4, 5, 6, 7]

- truth: "iOS framework linking succeeds for shared-app and shared-components"
  status: failed
  reason: "shared-app/build.gradle.kts and shared-components/build.gradle.kts iOS framework declarations missing linkerOpts.add('-lsqlite3'). shared-core correctly has it but umbrella frameworks in shared-app and shared-components do not inherit it. Errors: 'ld: Undefined symbols: _sqlite3_bind_blob, ...' during linkDebugFrameworkIosArm64 and linkReleaseFrameworkIosArm64."
  severity: major
  defect_id: BI-J
  artifacts: ["shared-app/build.gradle.kts", "shared-components/build.gradle.kts"]
  recommendation: "Add linkerOpts.add('-lsqlite3') to iosTarget.binaries.framework {} block in both shared-app/build.gradle.kts and shared-components/build.gradle.kts. Assign to follow-up plan."
  blocks: [1, 2, 3, 4, 5, 6, 7]
```
