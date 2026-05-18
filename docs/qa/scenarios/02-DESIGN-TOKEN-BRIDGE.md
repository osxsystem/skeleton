# Phase 02 — Design Token Bridge: Scenario Analysis (`/ck-scenario`)

**Feature:** ARGB Long overflow + dark mode toggle for KMP design token bridge
**Generated:** 2026-05-18
**Dimensions analyzed:** 7 of 12 — Input Extremes · Timing · State Transitions · Environment · Data Integrity · Integration · Feature Logic
**Dimensions skipped (with reason):** User Types (internal token layer, no roles) · Scale (fixed 72 constants) · Error Cascades (no I/O surface) · Authorization (no auth) · Compliance (no PII)

**Severity totals:** 6 Critical · 11 High · 12 Medium · 7 Low · **Total: 36 scenarios**

> See `docs/testcases/02-DESIGN-TOKEN-BRIDGE.md` for the test cases mapping each scenario to an executable test.

---

## Scenario Table

| # | Dimension | Scenario | Severity | Expected Behavior | Test Case |
|---|-----------|----------|----------|-------------------|-----------|
| **Input Extremes** |||||
| 1 | Input Extremes | `0xFFFFFFFFL` (opaque white) extracted via `Color(argb: Int64)` | Critical | opacity = 1.0; Int32 use silently corrupts alpha | TC-022 |
| 2 | Input Extremes | `0xFF000000L` (opaque black, alpha=0xFF, RGB=0) | Critical | opacity = 1.0, RGB = (0,0,0) | TC-023 |
| 3 | Input Extremes | Missing `L` suffix on new color: `const val foo = 0xFF3F51B5` | Critical | Compile error or negative `Int` — caught by `noColorConstantIsNegative` | TC-001 |
| 4 | Input Extremes | Test author uses `0x7FFFFFFF` (max positive Int32) as alpha fixture | High | Test passes under BOTH Int32 + Int64 — silently masks the bug; use `0xFF...` anchor | TC-021 |
| 5 | Input Extremes | `themeOverride = nil` (iOS) on cold start | High | Follows system; no spurious palette flicker | TC-032 |
| **Timing** |||||
| 6 | Timing | Android: tap toggle 10× in <500ms | High | Recomposition coalesces; final palette = final tap | TC-027 |
| 7 | Timing | System dark mode changes while override active | High | Override **wins** (Pitfall 7 invariant) | TC-031 |
| 8 | Timing | App backgrounded → user changes OS dark mode → resumed | High | `rememberSaveable` / `@State` retains override | TC-031 |
| 9 | Timing | Tap toggle during in-flight SwiftUI `.preferredColorScheme` animation | Medium | SwiftUI diffs; final state = last tap | TC-030 |
| 10 | Timing | Tap toggle while ViewModel state Loading → Ready transitioning | Medium | Palette flips; progress indicator stays | manual subset of TC-026/TC-029 |
| **State Transitions** |||||
| 11 | State Transitions | Override active, rotate device 90° | Critical | `rememberSaveable` persists | TC-028 |
| 12 | State Transitions | Override active, process killed by OS, relaunched | Medium | Override resets to nil (documented D-17 trade-off) | TC-033 |
| 13 | State Transitions | iOS cycle nil → .light → .dark → nil on system-dark device | Medium | First tap → .light (palette flips bright); expected per spec | TC-029 |
| 14 | State Transitions | First-ever launch | High | `themeOverride = nil`; follows system | TC-032 |
| 15 | State Transitions | Override active, external link launched, return | Medium | `rememberSaveable` survives Activity recreate | covered by TC-028 |
| **Environment** |||||
| 16 | Environment | Android with Material You / dynamic color enabled by OEM | Medium | `AppTheme` builds `ColorScheme` from `DesignTokens` — dynamic color should NOT leak | visual TC-019/TC-020 |
| 17 | Environment | iOS with "Increase Contrast" / "Reduce Transparency" | Medium | Post-render system adjustment; out of token-bridge contract | not in plan |
| 18 | Environment | iPad split-view appearance shifts while sharing screen | Medium | `@Environment(\.colorScheme)` flips; override (if set) still wins | partial TC-031 |
| 19 | Environment | RTL locale (Arabic, Hebrew) | Low | Button label hardcoded English; layout flips OK | not in plan (skeleton scope) |
| 20 | Environment | iOS 16 device | Low | Out of scope (iOS 17+ per Phase 1 D-01) | n/a |
| **Data Integrity** |||||
| 21 | Data Integrity | SKIE generates Swift accessor as `Int32` instead of `Int64` | Critical | Pitfall 6 mainline — silent alpha corruption for every `0xFF...` constant | TC-021, TC-022, TC-023 |
| 22 | Data Integrity | `LightColors` and `DarkColors` accidentally swapped during refactor | Critical | `darkColorsBrightInDark` catches via numeric assertion on background+surface | TC-009, TC-011 |
| 23 | Data Integrity | New color role added but missing from explicit-list `noColorConstantIsNegative` test | High | Silent test-completeness gap; code-review checklist | TC-002 |
| 24 | Data Integrity | Material3 minor version adds new `ColorScheme` role | High | Defaults leak in silently (D-01 violation); review on BOM bump | TC-014 |
| 25 | Data Integrity | TextStyleToken `letterSpacing` drifts between Compose `.sp` and SwiftUI `kerning` | Medium | Same primitive yields different tracking; document calibration | not in plan |
| **Integration** |||||
| 26 | Integration | SKIE upgrade changes accessor name | High | iOS build fails; `xcodebuild` gate catches at CI | TC-024 |
| 27 | Integration | Transitive dependency pulls `androidx.appcompat` | High | `AppCompatDelegate` callable but no-op on `ComponentActivity`; grep guard | TC-018 |
| 28 | Integration | Compose BOM update reorders/removes `ColorScheme` named arg | Medium | Compile failure; easy fix | TC-013 |
| 29 | Integration | iOS: `.preferredColorScheme(nil)` not honored by future SwiftUI parent (sheets, NavStack in Phase 5) | Medium | Currently only `WindowGroup` parent — verify when Phase 5 adds navigation | not in plan (Phase 5 concern) |
| 30 | Integration | Android: `enableEdgeToEdge` button obscured under gesture nav | Low | Add `Modifier.systemBarsPadding()` if observed | manual visual TC-019 |
| **Feature Logic** |||||
| 31 | Feature Logic | ~~Android binary toggle vs iOS three-state cycle~~ — **resolved**: Android now three-state to match iOS | Medium → ✅ | UX parity achieved 2026-05-18 (D-17 revised) | TC-026, TC-027 |
| 32 | Feature Logic | ~~Android override-true state, no way to return to system~~ — **resolved**: cycle now returns to `null` (follow system) | High → ✅ | Return path via three-state cycle (D-17, MainActivity onCycleTheme) | TC-026, TC-029 (parity) |
| 33 | Feature Logic | iOS button tapped 4× rapidly (full cycle + 1) | Low | Deterministic: nil → .light → .dark → nil → .light | covered by TC-030 |
| 34 | Feature Logic | Override active → user opens system settings expecting flip | Low | App ignores; discovery problem inherent to override toggles | documented |
| 35 | Feature Logic | Toggle button hidden behind keyboard (future input screens) | Low | Not in Phase 2 (GreetingScreen has no input) | n/a |

---

## Critical Findings — Plan Action Items

| # | Critical scenario | Recommended plan action | Status |
|---|------|------|--------|
| 1, 2 | Alpha extraction at boundary cases `0xFFFFFFFFL` and `0xFF000000L` | Add TC-022, TC-023 to `02-03-PLAN.md` Task 3 (sibling tests, ~10 lines) | ✅ applied 2026-05-18 |
| 3 | Missing `L` suffix on future color | Add a build-time grep lint regex per `02-01-PLAN.md` §409 — currently advisory comment only | recommended (still open) |
| 11 | Rotation during override | Already documented in `02-04-CKP` "Rotation guard"; manual smoke captures it | covered |
| 21 | SKIE Int32 regression after upgrade | TC-021..TC-023 + version pin in `gradle/libs.versions.toml` (already pinned) | covered (boundary tests added 2026-05-18) |
| 22 | LightColors/DarkColors palette swap | Extend `darkColorsBrightInDark()` with onBackground + surfaceContainerLowest + inversePrimary semantics (~5 lines) | ✅ applied 2026-05-18 |

---

## High-priority finding — Android cycle asymmetry (scenarios 31, 32) — ✅ RESOLVED 2026-05-18

Original asymmetry:
- **iOS:** clean three-state cycle `nil → .light → .dark → nil` (returns to system)
- **Android:** binary `Boolean?` flip — `themeOverride = !isDark` — never returns to `null` (no "follow system" return path)

**Applied fix 2026-05-18** — Android now three-state, matching iOS:
```kotlin
themeOverride = when (themeOverride) {
    null  -> false
    false -> true
    true  -> null
}
```
`MainActivity.kt` calls the lambda via `onCycleTheme`. `GreetingScreen.kt` accepts `themeOverride: Boolean?` and labels the button as "Override theme" / "Switch to Dark" / "Switch to System" via a `when` expression. Verified by:
- 02-02-PLAN.md acceptance criteria #6 (`grep -c 'onCycleTheme'`) + #6a (3 label strings present)
- 02-04-CKP human-verify (Android section, 10× rapid cycle)
- TC-026, TC-027 in `docs/testcases/02-DESIGN-TOKEN-BRIDGE.md`

---

*Generated by `/ck-scenario` 2026-05-18. Input feature: "ARGB Long overflow + dark mode toggle for KMP design token bridge". Linked to test plan: `docs/testcases/02-DESIGN-TOKEN-BRIDGE.md`.*
