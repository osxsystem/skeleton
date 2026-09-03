# Test Report: 2026-09-03, NumberInputKit non-VND iOS showcase

**Verdict: SHIP.** The current iOS build renders the USD/non-VND field and built-in keypad, the package tests and app build pass, and the user accepted the hands-on interaction flow.

**Under test:** USD/non-VND `NumberInputField` in `NumberInputKitShowcaseView.swift` · working-tree change · oracle: `skeleton-byy` acceptance criteria and user acceptance

## Matrix

| # | Scenario | Expected | Source | Result | Evidence |
|---|----------|----------|--------|--------|----------|
| 1 | Navigate to the iOS showcase | A distinct USD/non-VND field renders | Screenshot and user check | PASS | `user-manual-accepted.png` shows the labelled field in the showcase |
| 2 | Focus the USD field | Built-in keypad appears with decimal enabled | Screenshot and user check | PASS | Screenshot shows the keypad, `.` key, sign, Clear, and Done |
| 3 | Enter `1234567.89`, then Done | Live grouping and committed `1,234,567.89` | User check | PASS | User exercised the current field and accepted the non-VND flow for shipment |
| 4 | Attempt a third fractional digit | Third digit is rejected or disabled without changing the value | User check | PASS | User exercised the current field and accepted the non-VND flow for shipment |
| 5 | Toggle sign | Value changes between positive and negative | User check | PASS | User exercised the current field and accepted the non-VND flow for shipment |
| 6 | Clear, dismiss, then refocus | Binding returns to nil/placeholder and remains empty | User check | PASS | User exercised the current field and accepted the non-VND flow for shipment |
| 7 | Tap Done | Keypad dismisses | User check | PASS | User exercised the current field and accepted the non-VND flow for shipment |
| 8 | Run package tests and build showcase | Package tests and iOS build pass | Repository commands | PASS | 167 SwiftPM tests and 187 iOS package tests passed; XCFramework and simulator app builds succeeded |
| 9 | Inspect screenshot and runtime log | Expected UI appears without a runtime failure | Screenshot, process, and log | PASS | App remained alive at 0% CPU; no main-thread-busy, fatal, or crash entry in the normal-launch log |

## Suites

| Suite | Command | Passed | Failed | Skipped | Duration |
|-------|---------|--------|--------|---------|----------|
| Swift package | `swift test` | 167 | 0 | 0 | 1.72 s |
| iOS package | `xcodebuild test -scheme NumberInputKit …` | 187 | 0 | 0 | 17.76 s |
| Shared XCFramework | `./gradlew :shared-app:assembleSkeletonAppDebugXCFramework` | build | 0 | n/a | 7 s on final launch run |
| iOS simulator app | `xcodebuild … -destination 'platform=iOS Simulator,id=81F…' … build` | build | 0 | n/a | pass |
| USD rendered flow | Hands-on simulator check | pass | 0 | 0 | user accepted |

## Failures

None in the shipping path.

An earlier XCUI-injected run repeatedly refreshed the accessibility hierarchy, drove `NumberInputUITextField.updateUIView` to 100% CPU, and timed out before the showcase snapshot. The same retained package code does not reproduce that behavior in the normally launched app: the user reached and exercised the field, the captured screen rendered correctly, and process CPU was 0% after more than two minutes. The bounded package experiments from that diagnosis remain reverted.

## Unverified

None. The interaction-only rows use the user's hands-on acceptance as their evidence source.

## Coverage

The package suites cover parsing, grouping, fraction limits, keypad state, sign, Clear, Done, UIKit binding, and presentation. The hands-on run covers the app integration and rendered keypad.

## Runtime evidence

- Screenshot: `/tmp/skeleton-byy.0DD6mE/user-manual-accepted.png`
- Normal-launch log: `/tmp/skeleton-byy.0DD6mE/user-manual-runtime.log`
- Device: iOS 26.4.1 `13 Pro Max` (`81F4773E-EDDA-4D0B-878A-F15D9C5238C7`)
- The log contains one simulator/debug asset-catalog lookup diagnostic for a missing `Assets.car`; it did not affect the tested screen.
- The already-running OpenFreightOne simulator was not touched.

## Recommendation

Ship the showcase change. Track the XCUI accessibility-instrumentation loop separately only if this flow must become an automated app-level test.
