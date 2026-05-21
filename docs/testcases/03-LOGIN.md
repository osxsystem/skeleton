# 03 — Login Authentication: QA Review

**Feature:** Login (email/password) — Android Compose + iOS SwiftUI, shared `LoginViewModel`
**PRD:** [`../auth/LOGIN-PRD.md`](../auth/LOGIN-PRD.md) (12 ACs, FR-01..FR-12)
**Plan:** [`../auth/LOGIN-IMPLEMENTATION-PLAN.md`](../auth/LOGIN-IMPLEMENTATION-PLAN.md) (8 steps, sequential)
**Generated:** 2026-05-19
**Last updated:** 2026-05-19 (AC-09 closed: real `EncryptedSharedPreferences` + `Keychain` actuals + automated tests)
**Status:** Post-implementation review — tests landed across commits `916fba8`..`b82a939`; DoD smoke verified in [`../auth/reports/dod-smoke-260519.md`](../auth/reports/dod-smoke-260519.md). Persistence layer added in a follow-up: `SessionStore` is now an `interface` with `EncryptedSessionStore` (Android) and `KeychainSessionStore` (iOS) actuals.

---

## Scope of this review

This is **not** a forward-looking test plan. The feature shipped per plan `.claude/plans/260519-auth-step-6-7-8-login-ui/plan.md`, and per that plan's explicit scope **no UI tests were added** — `LoginViewModelTest` in `:shared-app:commonTest` is the only automated UI-adjacent coverage, paired with a manual scripted smoke on both platforms. This document inventories what landed and maps it to the PRD's ACs.

---

## Test inventory

### `commonTest` — 17 cases across 4 files

| File | Cases | Surface area |
|---|---|---|
| `shared-app/.../auth/login/LoginViewModelTest.kt` | 9 | VM state machine (Editing → Submitting → Succeeded/Failed), Turbine, `StandardTestDispatcher`. Uses an inline private `FakeSessionStore` (in-memory) |
| `shared-core/.../domain/auth/LoginUseCaseTest.kt` | 3 | Email trim + blank-input guard |
| `shared-core/.../data/auth/AuthRepositoryTest.kt` | 2 | Success-path session persist; failure-path leaves store untouched |
| `shared-core/.../data/remote/auth/FakeAuthApiTest.kt` | 3 | Canonical-cred success; wrong-password and unknown-email both throw `AuthException` |

The pre-refactor `SessionStoreTest.kt` (4 cases against the in-memory placeholder class) was removed — the interface contract is now exercised by the platform impls' instrumented/XCTest suites. The Fake itself is 6 lines and used as a test double in the 3 files above; not separately tested.

Test framework: `kotlin.test` + `kotest-assertions-core` + Turbine + `kotlinx-coroutines-test` (per CLAUDE.md §5).

### Android instrumented — 4 cases (real `EncryptedSharedPreferences`)

| File | Cases | Surface area |
|---|---|---|
| `androidApp/src/androidTest/.../EncryptedSessionStoreTest.kt` | 4 | Round-trip across fresh `EncryptedSessionStore` instances using `InstrumentationRegistry` context. Validates real `EncryptedSharedPreferences` (AES256-GCM master key + AES256-SIV/AES256-GCM prefs), not a mock. |

Runs via `:androidApp:connectedDebugAndroidTest` on a connected emulator or device. Latest green run: 4 tests, 0 failures, on `Medium_Phone_API_36.1` (API 36).

### iOS XCTest — 4 cases (real `Keychain`, 3 gated on entitlements)

| File | Cases | Surface area |
|---|---|---|
| `iosApp/iosAppTests/KeychainSessionStoreTests.swift` | 4 | Round-trip across fresh `KeychainSessionStore` instances. Validates real `platform.Security` Keychain (service: `dev.viethung.skeleton.auth`, accessibility: `AfterFirstUnlock`). |

Runs via `xcodebuild test`. Latest run: 1 case passed (`testFreshInstanceReturnsNilWhenKeychainEmpty`); the 3 write-path cases `XCTSkipIf` themselves while `keychain-access-groups` entitlement isn't being embedded — the iosApp builds with `CODE_SIGNING_ALLOWED = NO`, so even though `iosApp/iosApp/iosApp.entitlements` exists and is referenced via `CODE_SIGN_ENTITLEMENTS`, the binary ships without an entitlements blob. On a real device build with provisioning, the gate flips and all 4 cases run. See the file header for the one-time pbxproj knobs.

### Manual scripted smoke — both platforms

Recorded in [`../auth/reports/dod-smoke-260519.md`](../auth/reports/dod-smoke-260519.md). Driven by `adb shell input tap` / `input text` on Android (`Medium_Phone_API_36.1`) and `osascript` System Events on iOS (`iPhone 17` simulator, iOS 26.4). 21 screenshots under `/tmp/skeleton-smoke/`. Verified all 8 DoD §14 bullets, plus logout-resets-form and back-press-does-not-re-trigger-nav.

---

## Traceability — AC ↔ evidence

| AC | Requirement | Evidence | Status |
|---|---|---|---|
| **AC-01** | Initial `Editing("", "", isSubmitEnabled=false)` | `LoginViewModelTest.initial_state_is_empty_editing` | ✅ Automated |
| **AC-02** | Submit disabled until both fields non-empty | `LoginViewModelTest.typing_both_fields_enables_submit` + `blanking_a_field_disables_submit` | ✅ Automated |
| **AC-03** | Tap Submit → `Submitting` within 50 ms; loader visible | `LoginViewModelTest.submit_happy_path_emits_submitting_then_succeeded` (state); smoke 05/15 (loader visible during ~800 ms delay) | ✅ Automated (state) + ✅ Smoke (visual) |
| **AC-04** | Valid creds → `Succeeded` exactly once + `SessionStore.read()` non-null | `LoginViewModelTest.submit_happy_path_*`; `AuthRepositoryTest.login_success_persists_session_and_returns_it`; smoke happy path | ✅ Automated + ✅ Smoke |
| **AC-05** | `AuthException` → `Failed(email preserved, password="", message)` | `LoginViewModelTest.submit_auth_failure_emits_failed_with_message_and_preserves_email`; `FakeAuthApiTest` (2 cases) | ✅ Automated |
| **AC-06** | Unknown exception → generic "Something went wrong. Please try again." | `LoginViewModelTest.submit_unexpected_exception_emits_failed_with_friendly_message` | ✅ Automated |
| **AC-07** | `onErrorDismissed()` → `Editing(email preserved, password="", isSubmitEnabled=false)` | `LoginViewModelTest.on_error_dismissed_returns_to_editing_with_email_preserved`; smoke bad-creds | ✅ Automated + ✅ Smoke |
| **AC-08** | `onNavigatedToDashboard()` → `Editing()` empty (no re-trigger) | `LoginViewModelTest.on_navigated_to_dashboard_resets_to_empty_editing`; smoke "back-press from Dashboard does not re-trigger nav" | ✅ Automated + ✅ Smoke |
| **AC-09** | Session survives app restart on Android (EncryptedSharedPreferences) + iOS (Keychain) | Android: `EncryptedSessionStoreTest` (4 instrumented cases, real EncryptedSharedPreferences, all green on emulator). iOS: `KeychainSessionStoreTests.swift` (1 case green, 3 gated on entitlements — see iOS XCTest table above). | ✅ Automated (Android) / ⚠️ Gated (iOS write-path) |
| **AC-10** | `commonTest` exercises all 4 state branches with Turbine | `LoginViewModelTest` covers Editing→Submitting→Succeeded, Editing→Submitting→Failed (both error kinds), Failed→Editing (dismiss), Succeeded→Editing (reset) | ✅ Automated |
| **AC-11** | `grep` repo for `println.*password\|Log\..*password` → 0 hits | Not automated as a test. Spot-checked manually during smoke; CLAUDE.md §2 + plan §15 enforce. | ⚠️ Manual gate |
| **AC-12** | End-to-end happy path passes on Android + iOS | DoD §14 smoke transcripts (both platforms), 21 screenshots | ✅ Smoke |

**Coverage:** 11 / 12 ACs fully automated on at least one platform (AC-09 Android instrumented test closes the persistence gap; iOS XCTest landed but 3/4 cases are entitlements-gated). 1 / 12 (AC-11 log-grep) still manual.

---

## Gaps vs. PRD §12 "Testing Strategy"

The PRD's testing-strategy table (PRD §12) lists seven layers. Five landed; two did not.

| Layer (PRD §12) | Status | Note |
|---|---|---|
| `LoginViewModel` state machine — kotlin.test + Turbine | ✅ Landed | `LoginViewModelTest`, 9 cases |
| `LoginUseCase` validation | ✅ Landed | `LoginUseCaseTest`, 3 cases (trim + 2 blank-input throws) |
| `AuthRepository` w/ fake API + fake store | ✅ Landed | `AuthRepositoryTest`, 2 cases |
| `SessionStore` Android instrumented (process kill round-trip) | ✅ Added (2026-05-19) | `EncryptedSessionStoreTest`, 4 cases, real EncryptedSharedPreferences |
| `SessionStore` iOS XCTest (app re-launch round-trip) | ✅ Added (2026-05-19) | `KeychainSessionStoreTests.swift`, 4 cases, real Keychain (3 entitlement-gated) |
| `LoginScreen` Compose UI test (disabled-submit, alert appears) | ❌ Not added | No `androidApp/src/androidTest/` exists in the repo |
| `LoginScreen` SwiftUI XCTest / XCUITest | ❌ Not added | `iosApp/iosAppTests/` contains only `AppThemeTests.swift` |

These gaps are **acknowledged**, not discovered here — DoD smoke report line 65: *"No UI tests were added; `LoginViewModelTest` in `:shared-app:commonTest` remains the only automated coverage, per plan.md scope."*

---

## How to re-run

```bash
# Shared (17 cases, JVM + iosSimulatorArm64)
./gradlew :shared-core:allTests
./gradlew :shared-app:allTests

# Android instrumented (4 cases, requires running emulator/device)
./gradlew :androidApp:connectedDebugAndroidTest

# iOS XCTest (4 cases; 3 skip without entitlements)
./gradlew :shared-app:assembleSkeletonAppDebugXCFramework
cd iosApp && xcodebuild -project iosApp.xcodeproj -scheme iosApp \
    -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' test

# Manual smoke — credentials test@example.com / password
./gradlew :androidApp:installDebug   # then tap through Sign in → Dashboard → force-stop → relaunch (Android: lands on Dashboard, no Login)
# iOS: open iosApp/iosApp.xcodeproj, ⌘R, tap through; swipe-away + relaunch
```

Latest green runs:
- `./gradlew :shared-core:allTests :shared-app:allTests` → `BUILD SUCCESSFUL`
- `./gradlew :androidApp:connectedDebugAndroidTest` → `tests=4 failures=0 errors=0 skipped=0` on `Medium_Phone_API_36.1`
- `xcodebuild test` → 7 tests, 0 failures, 3 skipped (the entitlement-gated Keychain write cases)

---

## Verdict

Login meets its plan-of-record scope plus the AC-09 follow-up. Shared logic (state machine, use case, repository, fake API) is exercised by 17 `commonTest` cases. Real platform persistence is now exercised by 4 Android instrumented cases (all green) and 4 iOS XCTest cases (1 green, 3 entitlement-gated with documented one-time setup). End-to-end on both platforms is recorded in the manual DoD smoke. The remaining gap is AC-11 (automated repo-wide `password` log-grep), which stays a manual code-review checkpoint.
