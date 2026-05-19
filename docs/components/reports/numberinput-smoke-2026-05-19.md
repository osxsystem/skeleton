# NumberInput — Manual Smoke Test Report

**Date:** 2026-05-19
**Component:** NumberInput v1
**Tester:** _fill in_
**Build:** `:shared-components` XCFramework (release) + `swift-package/NumberInput` v1
**Devices tested:** _fill in (e.g. iPhone 17 simulator, iPhone 16 Pro physical)_

---

## Prerequisites

Before running, ensure:
1. XCFramework is built: `./gradlew :shared-components:assembleSkeletonKitReleaseXCFramework`
2. XCFramework is built for shared-app: `./gradlew :shared-app:assembleSkeletonAppDebugXCFramework`
3. Xcode project is regenerated: `cd iosApp && ./generate-xcodeproj.sh`
4. Run the iosApp on iPhone 17 simulator (or physical device).

---

## Test Scenarios

### Scenario A — In-app Showcase (NumberInputShowcaseView)

Navigate to the Number Input Showcase screen in the iosApp.

| # | Step | Expected | Result |
|---|------|----------|--------|
| A1 | Launch app → navigate to showcase | Four fields render with initial values: en-US "1,234.50", vi-VN "1.234,50", de-DE "1.234,500", unsigned "42.00" | |
| A2 | Tap the en-US field | Keyboard appears, toolbar shows [Clear] [±] [···] [Done], field shows "1234.5" (raw) | |
| A3 | Tap Done | Keyboard dismisses, field shows "1,234.50" | |
| A4 | Tap en-US field, tap ± | Field shows "-1234.5", value is negative | |
| A5 | Tap ± again | Field shows "1234.5", value returns positive | |
| A6 | Tap en-US field, tap Clear | Field empty, value nil, keyboard stays visible | |
| A7 | Tap Done on empty field | Keyboard dismisses, field shows empty placeholder | |
| A8 | Tap unsigned field | Toolbar shows [Clear] [±(disabled)] [···] [Done]; ± button is disabled/grayed | |
| A9 | Tap "Reset all" button | All fields return to initial values | |

### Scenario B — Locale Formatting

| # | Locale | Input | Expected on Done | Result |
|---|--------|-------|-----------------|--------|
| B1 | en-US | 1234567 | "1,234,567.00" (comma grouping, dot decimal) | |
| B2 | vi-VN | 1234567 | "1.234.567,00" (dot grouping, comma decimal) | |
| B3 | de-DE | 1234567 | "1.234.567,000" (3 sig digits, dot grouping, comma decimal) | |

### Scenario C — Sign Toggle

| # | Step | Expected | Result |
|---|------|----------|--------|
| C1 | Type 42, tap ± | Shows -42 | |
| C2 | Tap ± again | Shows 42 | |
| C3 | Clear field, tap ± | No change (empty field; ± is no-op) | |

### Scenario D — External SPM Consumer (AC-09)

| # | Step | Expected | Result |
|---|------|----------|--------|
| D1 | Create new bare iOS app in Xcode | Fresh project compiles | |
| D2 | Add local package: File → Add Package Dep → Add Local → `swift-package/NumberInput` | Package resolves successfully | |
| D3 | Add `import NumberInput` + `NumberInputField(value:$v)` to a view | Compiles without errors | |
| D4 | Run on iPhone 17 simulator | Field renders, toolbar works, en-US/vi-VN/de-DE locales format correctly | |

---

## Results

**Status:** `[ ] PASS  [ ] PARTIAL  [ ] FAIL`

**Notes:**
_fill in any issues, deviations from expected, or platform-specific observations_

---

## Known Limitations (v1)

- Android Compose adapter deferred (androidMain has a stub that formats without locale).
- Hardware-keyboard input on iPad not formally validated.
- `ToolbarItemGroup(placement: .keyboard)` inside SwiftUI `Form`/`List` rows — test if applicable to your screen layout.
- External SPM consumer (Scenario D) requires building the XCFramework first; the `.binaryTarget` path is relative and not published to a remote URL yet.

---

## Sign-off

| Role | Name | Date |
|------|------|------|
| iOS Engineer | | |
| Product Owner | | |
