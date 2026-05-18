---
phase: 02-design-token-bridge
plan: "02"
subsystem: android-theme
tags: [androidApp, compose, material3, theme, d-17, in-app-toggle]

requires: ["02-01"]
provides:
  - androidApp/.../theme/AppTheme.kt — Compose adapter mapping all DesignTokens to MaterialTheme
  - MainActivity.kt with rememberSaveable themeOverride state + AppTheme wrap
  - GreetingScreen.kt with themeOverride/onCycleTheme params + three-state cycle button (D-17)
affects: [02-04 manual D-17 toggle smoke on Android]

tech-stack:
  added: []
  patterns:
    - "Compose adapter reads commonMain DesignTokens primitives and constructs ColorScheme(36 roles), Typography(15 roles), Shapes(5 sizes)"
    - "Palette selection lives in MainActivity scope only — no isDark Boolean ever crosses into commonMain (D-16 invariant)"
    - "In-app theme override via `rememberSaveable { mutableStateOf<Boolean?>(null) }` — pure-Compose state hoist, no AppCompat dependency"

key-files:
  created:
    - androidApp/src/main/kotlin/dev/viethung/skeleton/android/theme/AppTheme.kt
  modified:
    - androidApp/src/main/kotlin/dev/viethung/skeleton/android/MainActivity.kt
    - androidApp/src/main/kotlin/dev/viethung/skeleton/android/greeting/GreetingScreen.kt

key-decisions:
  - "AppTheme signature accepts `isDark: Boolean = isSystemInDarkTheme()` — default follows system, caller may override (D-17)"
  - "Three-state cycle `null → false → true → null` for UX parity with iOS (D-17 / ck:scenario #32)"
  - "`AppCompatDelegate.setDefaultNightMode` rejected — would require switching MainActivity base class and adding androidx.appcompat. The Compose state hoist gives identical UX with zero new dependencies."
  - "ColorScheme constructor explicitly passes surfaceTint (and all 36 roles) — prevents M3 default leakage (D-01)"
  - "Used `androidx.compose.ui.text.TextStyle` (not the plan's `androidx.compose.material3.TextStyle` which doesn't exist — Typography accepts the ui.text type)"

patterns-established:
  - "Compose adapter pattern: `fun AppTheme(isDark: Boolean = ..., content)` reading DesignTokens objects and feeding ColorScheme/Typography/Shapes"
  - "Private `TextStyleToken.toTextStyle()` extension keeps the primitive→Compose mapping local to the adapter"
  - "Three-state theme override pattern: nullable Boolean? where null = follow system, false/true = explicit override"

requirements-completed: [THEME-02, THEME-03, THEME-05]

duration: 12min
completed: 2026-05-18
---

# Phase 2 Plan 02: Android Compose Adapter

**Wave 2A — DesignTokens → MaterialTheme adapter with D-17 in-app theme toggle (three-state cycle).**

## Accomplishments
- Created `AppTheme.kt` constructing `ColorScheme(36 roles incl. surfaceTint)` + `Typography(15 roles)` + `Shapes(5 sizes)` entirely from `DesignTokens.*`.
- Replaced bare `MaterialTheme { ... }` in `MainActivity.kt` with `AppTheme(isDark = themeOverride ?: isSystemInDarkTheme()) { ... }`; hoisted `themeOverride: Boolean?` via `rememberSaveable`.
- Added `themeOverride: Boolean?` + `onCycleTheme: () -> Unit` parameters to `GreetingScreen.kt`; wrapped existing Loading/Ready/Error render inside a centered `Column` and added a single Button cycling label `Override theme → Switch to Dark → Switch to System → Override theme`.

## Verification
- `./gradlew :androidApp:assembleDebug` exits 0
- `grep -rE '0x[0-9A-Fa-f]{6,8}L?' androidApp/src/main/kotlin/dev/viethung/skeleton/android/` → 0 hits (D-12)
- `grep -rE 'AppCompatDelegate|androidx\.appcompat' androidApp/src/` → 0 hits (D-17 rationale)
- `grep -c 'MaterialTheme' androidApp/.../MainActivity.kt` → 0 (bare MaterialTheme removed)
- `grep -c 'surfaceTint' androidApp/.../theme/AppTheme.kt` → 1
- All 36 ColorScheme roles, 15 Typography roles, 5 Shapes sizes wired from DesignTokens — no hardcoded values

## Deviations from Plan
- **Import correction:** plan listed `import androidx.compose.material3.TextStyle` but that class doesn't exist in M3 1.4.0; the correct package is `androidx.compose.ui.text.TextStyle`, which `Typography(...)` accepts. No behavioral impact.
- **Material3 1.4.0 deprecation warning:** the 36-arg `ColorScheme(...)` constructor is deprecated in favor of one with additional "fixed" container roles (M3 spec extension). Tolerated for Phase 2 — adding those roles is a separate token-set expansion that belongs in a later phase or in product code.

## Issues Encountered
- Initial build failed with `Unresolved reference 'inverseSurface'` etc. starting at line 52 of AppTheme.kt. Root cause: `if (isDark) DesignTokens.DarkColors else DesignTokens.LightColors` inferred to `Any` because the two objects had no common type. Fixed upstream in 02-01 by introducing `ColorPalette` interface (documented in 02-01-SUMMARY); 02-02 picked up the fix transparently.

## Next Plan Readiness
- Android adapter ready for the 02-04 manual D-17 smoke (three-state cycle on real device).
- The D-16 invariant is preserved: `themeOverride` lives entirely in `MainActivity` scope; `commonMain` only ever sees `Boolean = true/false` at the call site, never receives state.

---
*Phase: 02-design-token-bridge*
*Completed: 2026-05-18*
