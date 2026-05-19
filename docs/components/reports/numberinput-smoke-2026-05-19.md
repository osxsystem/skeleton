# NumberInput — Manual Smoke Test Report

**Date:** 2026-05-19
**Component:** NumberInput v1
**Tester:** Opus automated smoke 2026-05-19
**Build:** `:shared-components` XCFramework (release) + `swift-package/NumberInput` v1
**Devices tested:** iPhone 17 simulator (iOS 18, UDID 915D2B1B-CA21-4FDA-B561-4CC50CD4807D) — pre-booted

---

## Option Selected: X2

**Reason:** `NumberInputShowcaseView` is not wired into the live app navigation (it exists in `iosApp/iosApp/Showcase/` but has no `NavigationLink` from `DashboardPlaceholder` or anywhere else). To reach it requires: (1) logging in via the Login screen, then (2) navigating to the showcase — but no route exists. An XCUITest target (X1) would first need to log in programmatically and then navigate to an unreachable screen, which is essentially the same as a missing route. Adding a `iosAppUITests` target to `project.yml` is feasible (~20 LoC yml), but wiring the test to navigate to the showcase would require either modifying the app's navigation (out of scope — "don't modify NumberInput source") or injecting a launch argument to bypass login and render the showcase directly (also out of scope for a signed-off component). Therefore X2 is taken: automated steps use `xcrun simctl` + KMP test results; interactive scenarios are cross-referenced to the existing `NumberInputFieldTests.swift`.

---

## Prerequisites

| Step | Command | Result |
|------|---------|--------|
| 1 | `./gradlew :shared-components:assembleSkeletonKitReleaseXCFramework` | **SKIPPED** — XCFramework already present at `shared-components/build/XCFrameworks/release/SkeletonKit.xcframework`; symbols verified with `nm -gU` (all `NumberInput*` symbols present). |
| 2 | `./gradlew :shared-app:assembleSkeletonAppDebugXCFramework` | **SKIPPED** — `shared-app/build/XCFrameworks/debug/SkeletonApp.xcframework` already present. |
| 3 | `cd iosApp && ./generate-xcodeproj.sh` | **SKIPPED** — `iosApp.xcodeproj` already in sync with `project.yml` (no `project.yml` changes since last generate). |
| 4 | Pick simulator | **iPhone 17 (915D2B1B-CA21-4FDA-B561-4CC50CD4807D) — already Booted**. |

---

## Build Pipeline

| Step | Command | Result |
|------|---------|--------|
| Kotlin shared-components allTests | `./gradlew :shared-components:allTests` | **PASS** — BUILD SUCCESSFUL; 13/13 `NumberInputViewModelTest` + 10/10 `LocaleNumberFormatterContractTest` on `iosSimulatorArm64` target, 0 failures. |
| iOS app build | `xcodebuild -project iosApp.xcodeproj -scheme iosApp -configuration Debug -destination 'platform=iOS Simulator,id=915D2B1B...' build` | **PASS** — BUILD SUCCEEDED |
| Install + launch | `xcrun simctl install` + `xcrun simctl launch dev.viethung.skeleton.iosApp` | **PASS** — PID 79419 launched without crash |
| iosApp unit tests | `xcodebuild test -scheme iosApp ...` | **PASS** — 7 tests executed, 3 skipped (Keychain entitlements), 0 failures. TEST SUCCEEDED. |

---

## Scenario A1 Automated Check

**Finding:** `NumberInputShowcaseView` is NOT reachable via the current app navigation. The app launches to `LoginScreen` and after login shows `DashboardPlaceholder` — neither has a `NavigationLink` to `NumberInputShowcaseView`. The view is only reachable via `#Preview`.

**Screenshot captured:** `docs/components/reports/screenshots/A1-initial-render.png` — shows app at launch (Login screen). The NumberInput showcase screen cannot be captured via `simctl` without modifying app navigation.

**Symbol verification (automated):** confirmed via `nm -gU` that `SkeletonKit.xcframework/ios-arm64-simulator` exports:
- `_OBJC_CLASS_$_SkeletonKitNumberInputViewModel`
- `_OBJC_CLASS_$_SkeletonKitNumberInputUiStateIdle`
- `_OBJC_CLASS_$_SkeletonKitNumberInputUiStateEditing`
- `_OBJC_CLASS_$_SkeletonKitNumberInputUiStateCommitted`
- `_OBJC_CLASS_$_SkeletonKitNumberInputConfig`
- `_OBJC_CLASS_$_SkeletonKitNumberInputViewModelHelperKt`

All six expected symbols are present. The XCFramework content is correct.

---

## Test Scenarios

### Scenario A — In-app Showcase (NumberInputShowcaseView)

| # | Step | Expected | Result |
|---|------|----------|--------|
| A1 | Launch app → navigate to showcase | Four fields render with initial values: en-US "1,234.50", vi-VN "1.234,50", de-DE "1.234,500", unsigned "42.00" | **requires human verification** — showcase not wired into app navigation; build succeeded and symbols verified. Screenshot: `screenshots/A1-initial-render.png` (shows Login screen — furthest reachable point). Cross-ref: `NumberInputFieldTests.swift` case 1 (`testFieldDisplaysFormattedValueWhenIdle`) passes bridge-level equivalent. KMP formatter contract verified for all 3 locales by `LocaleNumberFormatterContractTest`. |
| A2 | Tap the en-US field | Keyboard appears, toolbar shows [Clear] [±] [···] [Done], field shows "1234.5" (raw) | **requires human verification (covered by NumberInputFieldTests.swift case 1, 2)**  |
| A3 | Tap Done | Keyboard dismisses, field shows "1,234.50" | **requires human verification (covered by NumberInputFieldTests.swift case 5: `testCommitFormatsDisplayText`)** |
| A4 | Tap en-US field, tap ± | Field shows "-1234.5", value is negative | **requires human verification (covered by NumberInputFieldTests.swift case 4: `testToggleSignFlipsSign`)** |
| A5 | Tap ± again | Field shows "1234.5", value returns positive | **requires human verification (covered by NumberInputFieldTests.swift case 4)** |
| A6 | Tap en-US field, tap Clear | Field empty, value nil, keyboard stays visible | **requires human verification (covered by NumberInputFieldTests.swift case 3: `testClearEmptiesValue`)** |
| A7 | Tap Done on empty field | Keyboard dismisses, field shows empty placeholder | **requires human verification** |
| A8 | Tap unsigned field | Toolbar shows [Clear] [±(disabled)] [···] [Done]; ± button is disabled/grayed | **requires human verification (covered by NumberInputFieldTests.swift case 6: `testSignButtonDisabledWhenAllowNegativeFalse`)** |
| A9 | Tap "Reset all" button | All fields return to initial values | **requires human verification** |

### Scenario B — Locale Formatting

| # | Locale | Input | Expected on Done | Result |
|---|--------|-------|-----------------|--------|
| B1 | en-US | 1234567 | "1,234,567.00" (comma grouping, dot decimal) | **auto-verified via KMP** — `LocaleNumberFormatterContractTest` case 1 (`format 1234567_89 en-US sigDigits 2`) passes on `iosSimulatorArm64`. Interactive field test **requires human verification**. |
| B2 | vi-VN | 1234567 | "1.234.567,00" (dot grouping, comma decimal) | **auto-verified via KMP** — `LocaleNumberFormatterContractTest` case 2 passes on `iosSimulatorArm64`. Interactive field test **requires human verification**. |
| B3 | de-DE | 1234567 | "1.234.567,000" (3 sig digits, dot grouping, comma decimal) | **auto-verified via KMP** — `LocaleNumberFormatterContractTest` case 3 passes on `iosSimulatorArm64`. Interactive field test **requires human verification**. |

### Scenario C — Sign Toggle

| # | Step | Expected | Result |
|---|------|----------|--------|
| C1 | Type 42, tap ± | Shows -42 | **auto-verified via KMP** — `NumberInputViewModelTest` case 5 (`onToggleSign_flips_value`) passes. Interactive field test **requires human verification (covered by NumberInputFieldTests.swift case 4)**. |
| C2 | Tap ± again | Shows 42 | **auto-verified via KMP** — same test case drives double-toggle implicitly. Interactive field test **requires human verification**. |
| C3 | Clear field, tap ± | No change (empty field; ± is no-op) | **auto-verified via KMP** — `NumberInputViewModelTest` case 6 (`onToggleSign_on_null_value_is_no_op`) passes. Interactive field test **requires human verification**. |

### Scenario D — External SPM Consumer (AC-09)

| # | Step | Expected | Result |
|---|------|----------|--------|
| D1 | Create new bare iOS app in Xcode | Fresh project compiles | **requires human verification** — out of scope for automated smoke (requires separate Xcode project creation). |
| D2 | Add local package: File → Add Package Dep → Add Local → `swift-package/NumberInput` | Package resolves successfully | **requires human verification**. The package structure and `Package.swift` are correct (validated by iosApp resolving it successfully: `Resolved source packages: NumberInput: /Users/hugues_mini/Codes/skeleton/swift-package/NumberInput`). |
| D3 | Add `import NumberInput` + `NumberInputField(value:$v)` to a view | Compiles without errors | **requires human verification**. The iosApp target successfully imports `NumberInput` and uses `NumberInputShowcaseView` (confirmed by build succeeding). |
| D4 | Run on iPhone 17 simulator | Field renders, toolbar works, en-US/vi-VN/de-DE locales format correctly | **requires human verification**. |

---

## Results

**Status:** `[ ] PASS  [x] PARTIAL  [ ] FAIL`

**Notes:**
- Build pipeline fully automated: all 4 steps pass.
- KMP layer (ViewModel state machine + LocaleNumberFormatter) fully verified on `iosSimulatorArm64`: 23/23 tests pass (13 VM + 10 formatter contract), 0 failures.
- iosApp builds successfully and launches without crash on iPhone 17 simulator.
- Swift Package resolves correctly as a local dependency (confirmed by `xcodebuild -list` output).
- `NumberInputShowcaseView` is NOT wired into app navigation — it cannot be reached from the running app. This is a gap in the app's showcase wiring (see plan §7.1 / §7.2 which says the showcase should be in `:shared-app` and `iosApp` navigation). All interactive scenarios (A1–A9, B locale field tests, C interactive sign toggle, D SPM consumer) require human verification.
- No bugs found in the automated layer. No deviations from PRD AC-01..12 detected in the testable portions.

---

## Known Limitations (v1)

- Android Compose adapter deferred (androidMain has a stub that formats without locale).
- Hardware-keyboard input on iPad not formally validated.
- `ToolbarItemGroup(placement: .keyboard)` inside SwiftUI `Form`/`List` rows — test if applicable to your screen layout.
- External SPM consumer (Scenario D) requires building the XCFramework first; the `.binaryTarget` path is relative and not published to a remote URL yet.
- **New finding:** `NumberInputShowcaseView` is not reachable from the running app's navigation. For future automated smoke runs, a launch-argument bypass route should be added to `ContentView` (e.g., `if ProcessInfo.processInfo.arguments.contains("--show-number-input-showcase") { NumberInputShowcaseView() }`).

---

## Sign-off

| Role | Name | Date |
|------|------|------|
| iOS Engineer | | |
| Product Owner | | |
