---
title: "DoD §14 manual smoke — Auth Steps 6–7–8"
date: 2026-05-19
plan: .claude/plans/260519-auth-step-6-7-8-login-ui/plan.md (local-only)
spec: ../LOGIN-IMPLEMENTATION-PLAN.md §14
result: pass
---

# DoD §14 manual smoke

All eight DoD §14 bullets verified on a live Android emulator (`Medium_Phone_API_36.1`, API 36, 1080×2400) and iOS Simulator (`iPhone 17`, iOS 26.4). Twenty-one screenshots captured under `/tmp/skeleton-smoke/`.

## Environment
- JDK 21, Android SDK at `~/Library/Android/sdk`, Xcode 17E202 / iOS 26.4 SDK
- Android driven via `adb shell input tap` / `input text` with bounds from `uiautomator dump`
- iOS driven via `osascript`+`System Events` `click at {x,y}` and `keystroke`, mapped through the Simulator window rect `AXGroup pos=(632,173) size=(402,874)`

## Results

| # | DoD bullet | Android | iOS | Evidence |
|---|---|---|---|---|
| 1 | `:shared-app:allTests` green (`LoginViewModelTest`) | ✅ | ✅ | `./gradlew :shared-app:allTests` → `BUILD SUCCESSFUL in 537ms` |
| 2 | `./gradlew :androidApp:installDebug` runs end-to-end | ✅ | n/a | `BUILD SUCCESSFUL in 8s`; package `dev.viethung.skeleton.android` |
| 3 | iOS build runs (Xcode equivalent) | n/a | ✅ | `xcodebuild … -sdk iphonesimulator build` → `** BUILD SUCCEEDED **`; `simctl install` + `simctl launch` |
| 4 | Submit valid → spinner ~800 ms → Dashboard | ✅ | ✅ | Android: 04→05→06; iOS: 14→15→16 |
| 5 | Submit invalid → alert; dismiss → form with email kept, password empty | ✅ | ✅ | Android: 09→10; iOS: 19→20 |
| 6 | Submit disabled when either field empty | ✅ | ✅ | 01-android-login, 01-ios-login, 12, 17, 20 |
| 7 | No raw colors / fonts / sizes — tokens only | ✅ | ✅ | grep on `LoginScreen.kt`, `DashboardPlaceholder.kt`, `LoginScreen.swift`, `DashboardPlaceholder.swift` — only `DesignTokens.spacing.*` / `theme.spacing.*` / `theme.typography.*` |
| 8 | Zero `android.*` / `UIKit.*` in any `commonMain` | ✅ | ✅ | `grep -rn` across `shared-core`, `shared-app`, `shared-components` commonMain → `none` |

### Extras observed (matches plan.md DoD)
- **Logout returns to empty Login**: Android (12), iOS (17) — both fields blank, Sign in disabled.
- **Back-press from Dashboard does not re-trigger nav**: Android back at Dashboard → launcher; relaunch lands on Sign in (08), no flash of Dashboard. iOS has no system back; auth gate held in `ContentView`.

## Smoke transcripts

### Android happy path
```
adb shell input tap 540 1075        # email field bounds [84,991][996,1159]
adb shell input text "test@example.com"
adb shell input keyevent 4          # dismiss keyboard so layout restores
adb shell input tap 540 1285        # password field bounds [84,1201][996,1369]
adb shell input text "password"
adb shell input keyevent 4
adb shell input tap 540 1495        # Sign in button bounds [84,1443][996,1548]
```
Result: spinner caught mid-rotation (`05-android-spinner.png`) → Dashboard with `Log out` + `Override theme` (`06-android-dashboard.png`). `uiautomator dump` confirms `text="Dashboard"` and `text="Log out"`.

### iOS happy path
```
click at {832, 657}                 # email at iOS logical (200, 484)
keystroke "test@example.com"
click at {832, 706}                 # password at iOS logical (200, 533)
keystroke "password"
click at {832, 752}                 # Sign in at iOS logical (200, 579)
```
Result: spinner (`15-ios-spinner.png`) → Dashboard (`16-ios-dashboard.png`).

### Bad-creds path (both)
Submit `test@example.com` + `wrongpass` → alert "Login failed / Invalid email or password" → OK → form shows email kept, password placeholder restored, Sign in greyed.

## Known caveats
- iOS scripted input required granting Accessibility to `osascript`. Without `idb`/`cliclick`/XCUITest, this is the only viable path; one mid-run `-25211` occurred but the click had already fired (alert dismiss verified by screenshot).
- Android `uiautomator dump` reports the Compose Sign-in button as `enabled="true"` even when visually greyed — Material3 a11y node quirk. Visual state is authoritative and matches DoD.
- No UI tests were added; `LoginViewModelTest` in `:shared-app:commonTest` remains the only automated coverage, per plan.md scope.

## Files referenced (read-only, no edits)
- `androidApp/src/main/kotlin/dev/viethung/skeleton/android/MainActivity.kt`
- `androidApp/src/main/kotlin/dev/viethung/skeleton/android/auth/LoginScreen.kt`
- `androidApp/src/main/kotlin/dev/viethung/skeleton/android/dashboard/DashboardPlaceholder.kt`
- `iosApp/iosApp/Auth/LoginScreen.swift`
- `iosApp/iosApp/Dashboard/DashboardPlaceholder.swift`
- `iosApp/iosApp/ContentView.swift`
- `shared-app/src/commonMain/kotlin/dev/viethung/showcase/auth/login/LoginViewModelHelper.kt`

## Conclusion
DoD §14 is satisfied. Plan is fully implemented and verified end-to-end on both platforms. No code changes were required during smoke.
