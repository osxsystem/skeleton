---
phase: 02-design-token-bridge
plan: "04"
subsystem: design-tokens
tags: [commonTest, dark-mode, d-16, d-17, theme-05, manual-verification, sc4]

requires: ["02-02", "02-03"]
provides:
  - DesignTokensTest.kt extended with rapidToggleSimulation() and darkColorsBrightInDark() — synthetic D-16/SC4 regression guards
  - Manual D-17 in-app cycle smoke approved on Android + iOS (10× taps, no restart)
affects: []

tech-stack:
  added: []
  patterns:
    - "Synthetic toggle-loop test simulating AppTheme.build(isDark:) selection — catches accidental LightColors/DarkColors object swap at unit-test level before the manual gate"
    - "M3 inverse-role convention assertion — each palette's inversePrimary equals the OTHER palette's primary"

key-files:
  created: []
  modified:
    - shared-core/src/commonTest/kotlin/dev/viethung/core/theme/DesignTokensTest.kt

key-decisions:
  - "darkColorsBrightInDark extended per QA recommendation (TC-011 / ck:scenario #22) — 5 role-pair assertions: 3 darker-in-dark (background, surface, surfaceContainerLowest), 1 inverse-direction (onBackground), 2 M3 inverse-role equalities (inversePrimary ↔ primary across palettes)"
  - "Manual gate confirmed via D-17 in-app button (V-D4 trade-off): OS Settings appearance-change path is NOT separately verified; relies on the same AppTheme.build(isDark:) adapter the button path exercises"

patterns-established:
  - "Cross-target commonTest guards for dark-mode invariants — no platform code needed to catch palette-swap regressions"

requirements-completed: [THEME-05]

duration: 10min (tests) + manual verification
completed: 2026-05-18
---

# Phase 2 Plan 04: Wave 3 — Dark-Mode Contract Tests + Manual D-17 Smoke

**Wave 3 final gate — appends two synthetic regression tests to DesignTokensTest.kt, then verifies SC4 via the D-17 in-app cycle button on both platforms.**

## Accomplishments
- Appended `rapidToggleSimulation()`: 10-iteration alternating-selection loop verifying `LightColors.primary != DarkColors.primary` and that each isDark↔palette mapping is consistent. Synthetic D-16 contract guard.
- Appended `darkColorsBrightInDark()`: 5 role-pair assertions guarding against accidental palette swap:
  - `DarkColors.background < LightColors.background`
  - `DarkColors.surface < LightColors.surface`
  - `DarkColors.surfaceContainerLowest < LightColors.surfaceContainerLowest`
  - `DarkColors.onBackground > LightColors.onBackground` (inverse direction for "on" roles)
  - `LightColors.inversePrimary == DarkColors.primary` and `DarkColors.inversePrimary == LightColors.primary` (M3 inverse-role convention)
- DesignTokensTest.kt now has 5 tests total, all passing on JVM (Android host) and iosSimulatorArm64.
- **Manual D-17 cycle smoke approved by user** — both platforms tap-cycle the palette 10× without restart, label cycles correctly, palette flips per tap.

## Verification
- `./gradlew :shared-core:testAndroidHostTest --tests "dev.viethung.core.theme.DesignTokensTest"` → 5 tests, 0 failures
- `./gradlew :shared-core:iosSimulatorArm64Test --tests "dev.viethung.core.theme.DesignTokensTest"` → 5 tests, 0 failures
- `grep -c 'rapidToggleSimulation\|darkColorsBrightInDark' shared-core/src/commonTest/kotlin/dev/viethung/core/theme/DesignTokensTest.kt` → 2
- `grep -rE '0x[0-9A-Fa-f]{6,8}L?' androidApp/src/main/kotlin/dev/viethung/skeleton/android/` → 0 hits (D-12)
- `grep -cE '\.foregroundColor\(\.red\)|\.foregroundStyle\(\.red\)' iosApp/iosApp/Greeting/GreetingScreen.swift` → 0 (D-13)
- `grep -rE 'AppCompatDelegate|androidx\.appcompat' androidApp/src/` → 0 hits (D-17 rationale)
- **Manual Android:** install via `./gradlew :androidApp:installDebug`, tap cycle button 10× — palette flips per tap, label cycles `Override theme → Switch to Dark → Switch to System → Override theme`, rotation preserves override (rememberSaveable). **User: approved.**
- **Manual iOS:** open `iosApp/iosApp.xcodeproj`, ⌘R on iPhone 17 simulator, tap cycle button 10× — palette flips per tap, label cycles correctly. **User: approved.**

## Deviations from Plan

- The plan's verification commands reference `./gradlew :shared-core:jvmTest`; the actual KMP target is `android` (host), so the equivalent task is `:shared-core:testAndroidHostTest`. Documented in 02-01-SUMMARY.

## Issues Encountered

None during this plan. (The substantial Phase 1 iOS gap-closure work happened in 02-03; by the time 02-04 ran, both platforms were already building.)

## Accepted Coverage Trade-off (V-D4)

The OS-level appearance change path (Android Settings → Display, iOS ⌘⇧A) is no longer separately verified by a manual gate. The D-17 in-app button exercises the same `AppTheme.build(isDark:)` adapter; divergence is unlikely but not impossible. Re-introducing the OS-level path requires either:
- Adding a separate manual checkpoint (rejected — D-17 button gate is sufficient for skeleton scope), or
- Instrumented UI tests that toggle system appearance (Phase 6 SHOW-04 candidate).

## Phase 2 — Closeout

All five phase requirements complete: THEME-01, THEME-02, THEME-03, THEME-04, THEME-05.
- D-16 (Pitfall 7) invariant preserved on both platforms: no `isDark: Boolean` ever crosses into commonMain.
- D-17 (in-app theme toggle) verified end-to-end on both platforms via the 10× cycle smoke.
- Pitfall 6 (ARGB Long overflow) double-guarded: commonTest `noColorConstantIsNegative()` on JVM+iOS, plus XCTest `testColorAdapterPreservesAlphaForFFOpaqueLong/OpaqueWhite/OpaqueBlack`.

Phase 2 also closed a substantial Phase 1 iOS-build gap as a necessary side effect (see 02-03-SUMMARY §Deviations) — the iOS app now builds and runs end-to-end for the first time.

## Next Phase Readiness
- Token bridge complete on both platforms; ready for Phase 3 component ViewModels to consume `DesignTokens` via `:shared-core`.
- Recommended follow-ups (not blocking):
  - Update root README to document the XcodeGen prerequisite + `iosApp/generate-xcodeproj.sh` bootstrap step (the README still says `open iosApp/iosApp.xcodeproj` directly).
  - When SKIE supports Kotlin 2.3.21, re-enable it and consider unwinding the per-VM helper pattern in `shared-app/.../greeting/GreetingViewModelHelper.kt` if SKIE provides a cleaner alternative.

---
*Phase: 02-design-token-bridge*
*Completed: 2026-05-18*
