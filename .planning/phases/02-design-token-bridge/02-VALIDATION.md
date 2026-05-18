---
phase: 2
slug: design-token-bridge
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-10
---

# Phase 2 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | kotlin.test + kotest-assertions-core (commonTest); JUnit/Espresso (Android instrumented); XCTest (iOS) |
| **Config file** | `gradle/libs.versions.toml`, `shared-core/build.gradle.kts` (kotlin-test, kotest deps) |
| **Quick run command** | `./gradlew :shared-core:jvmTest` (~5s — fast feedback on token primitives) |
| **Full suite command** | `./gradlew :shared-core:allTests` (commonTest across jvm + iosSimulatorArm64) |
| **Estimated runtime** | ~30–60 seconds (full allTests including iOS simulator target) |

---

## Sampling Rate

- **After every task commit:** Run `./gradlew :shared-core:jvmTest` (jvmTest only; <10s feedback)
- **After every plan wave:** Run `./gradlew :shared-core:allTests` (cross-target — catches Long-overflow on iosSimulatorArm64)
- **Before `/gsd-verify-work`:** Full suite must be green; manual dark-mode toggle smoke on both platforms
- **Max feedback latency:** 60 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 02-01-T1 | 02-01 | 1 | THEME-01, THEME-02 | Pitfall 6 | No platform imports in commonMain; 36 Long constants per palette (incl. surfaceTint) with L suffix | build gate | `./gradlew :shared-core:jvmTest 2>&1 \| tail -5` | ✅ planned | ⬜ pending |
| 02-01-T2 | 02-01 | 1 | THEME-02 | Pitfall 6 | noColorConstantIsNegative covers all 72 constants (36 light + 36 dark); kotlin.test.Test used (not org.junit.Test) | unit (commonTest) | `./gradlew :shared-core:jvmTest --tests "dev.viethung.core.theme.DesignTokensTest" 2>&1 \| tail -10` | ✅ planned | ⬜ pending |
| 02-02-T1 | 02-02 | 2 | THEME-02, THEME-03 | Pitfall 6 | ColorScheme(36 roles incl. surfaceTint) sourced from DesignTokens; no hex literals in theme dir | build gate | `./gradlew :androidApp:assembleDebug 2>&1 \| tail -10` | ✅ planned | ⬜ pending |
| 02-02-T2 | 02-02 | 2 | THEME-03 | — | MainActivity wraps with AppTheme; no bare MaterialTheme | build gate | `./gradlew :androidApp:assembleDebug 2>&1 \| tail -5` | ✅ planned | ⬜ pending |
| 02-03-T1 | 02-03 | 2 | THEME-04 | Pitfall 6 | Color(argb: Int64) extension; 36 ThemeColors fields incl. surfaceTint; AppTheme.swift in project.pbxproj | grep + pbxproj check | `grep -c 'EnvironmentKey' iosApp/iosApp/Theme/AppTheme.swift && grep -c 'Int64' iosApp/iosApp/Theme/AppTheme.swift && grep -c 'AppTheme.swift' iosApp/iosApp.xcodeproj/project.pbxproj` | ✅ planned | ⬜ pending |
| 02-03-T2 | 02-03 | 2 | THEME-04, THEME-05 | Pitfall 7 | AppTheme injected at WindowGroup root; .red replaced by theme.colors.error; xcodebuild passes | build gate | `xcodebuild -project iosApp/iosApp.xcodeproj -scheme iosApp -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 \| tail -5` | ✅ planned | ⬜ pending |
| 02-03-T3 | 02-03 | 2 | THEME-04 | Pitfall 6 (Swift side) | testColorAdapterPreservesAlphaForFFOpaqueLong passes; AppThemeTests.swift in project.pbxproj | XCTest (unit) | `xcodebuild -project iosApp/iosApp.xcodeproj -scheme iosApp -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 \| tail -5` | ✅ planned | ⬜ pending |
| 02-04-T1 | 02-04 | 3 | THEME-05 | Pitfall 7 | rapidToggleSimulation + darkColorsBrightInDark tests pass (5 total in DesignTokensTest) | unit (commonTest) | `./gradlew :shared-core:jvmTest --tests "dev.viethung.core.theme.DesignTokensTest" 2>&1 \| grep -E "tests completed\|FAILED\|PASSED"` | ✅ planned | ⬜ pending |
| 02-04-CKP | 02-04 | 3 | THEME-05 (SC4) | Pitfall 7 | 10× dark/light toggle without app restart on Android + iOS | checkpoint:human-verify | manual | n/a | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] `:shared-core/src/commonTest/kotlin/dev/viethung/core/theme/DesignTokensTest.kt` — `noColorConstantIsNegative()` + token-completeness assertions for THEME-01, THEME-02 — **covered by 02-01-T2**
- [x] kotest-assertions-core dependency confirmed in `:shared-core` commonTest sourceSet (carry-over from Phase 1)
- [x] iOS smoke harness: `iosApp/iosAppTests/AppThemeTests.swift` — `testColorAdapterPreservesAlphaForFFOpaqueLong()` verifies Pitfall 6 mitigation on the Swift side — **covered by 02-03-T3**

*All Wave 0 items are covered by planned tasks. nyquist_compliant = true.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| In-app theme toggle without restart (Android) — D-17 | THEME-04 (SC4), THEME-05 | Animation timing + UI state persistence across config-change is not unit-testable | 1) Run `:androidApp:installDebug` 2) Tap the "Switch to Dark/Light" button in GreetingScreen 10× rapidly 3) Confirm palette flips each tap without app restart 4) Rotate device while in override state — palette must persist (rememberSaveable guard) |
| In-app theme toggle without restart (iOS) — D-17 | THEME-04 (SC4), THEME-05 | `.preferredColorScheme` propagation through SwiftUI environment is a runtime concern | 1) Run `iosApp` in Simulator (iPhone 16, iOS 17+) 2) Tap the cycle button in GreetingScreen 10× rapidly (cycles nil → .light → .dark → nil) 3) Confirm palette flips per tap and button label updates correctly |
| No AppCompat dependency added — D-17 rationale | scope discipline | Negative dependency assertion | `! grep -rE 'AppCompatDelegate\|androidx\.appcompat' androidApp/` returns no hits |
| No hex literals in androidApp theme code | THEME-02 (SC2) | Negative assertion (file content) | `! grep -rE '0x[0-9A-Fa-f]{6,8}L?' androidApp/src/main/kotlin/.../theme/` returns no hits |
| No hex literals in iosApp theme code | THEME-03 (SC3) | Negative assertion (file content) | `! grep -rE 'Color\(red:.*green:.*blue:' iosApp/iosApp/Theme/` returns no hits (raw initializers must live in `AppTheme.swift` adapter only, taking `Long` → `Color`) |
| **Coverage gap (V-D4 accepted)** — OS-level appearance change path | THEME-04 (SC4) | Removed in favor of in-app toggle per D-17 | The Android Settings → Display → Dark theme path and iOS Cmd+Shift+A path are NOT covered by a dedicated manual gate. Both paths share the same `AppTheme.build(isDark:)` adapter that the in-app toggle exercises — divergence is unlikely but unmonitored. |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 60s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved 2026-05-18 (after V-1..V-5 landed in 02-CONTEXT.md, 02-02-PLAN.md, 02-03-PLAN.md, 02-04-PLAN.md, and this file).

---

## Validation Summary

**Validated:** 2026-05-18
**Questions asked:** 4 (3 primary + 1 follow-up clarification)
**Reviewer:** viethung097@gmail.com

### Confirmed Decisions

- **V-D1 · Palette source:** Keep hand-picked hex committed in 02-01-PLAN.md (Indigo 500 primary `0xFF3F51B5L`, Teal 500 tertiary `0xFF009688L`). No Material Theme Builder regeneration. Rationale: skeleton placeholder is intentional; cloned products swap. → No changes to 02-01-PLAN.md.
- **V-D2 · Showcase scope expansion:** Add an in-app theme toggle button to `GreetingScreen` on both platforms. This was Claude's Discretion item #4 in 02-DISCUSSION-LOG and is now resolved as "in scope for Phase 2".
- **V-D3 · Toggle implementation:** Toggle **overrides** OS appearance.
  - iOS: `@State var themeOverride: ColorScheme?` at `WindowGroup` root → `.preferredColorScheme(themeOverride)`.
  - Android: button calls `AppCompatDelegate.setDefaultNightMode(MODE_NIGHT_YES | MODE_NIGHT_NO)`.
  - Pitfall 7 invariant **preserved**: palette selection still lives in the platform UI layer (Swift / Compose), never in `commonMain`. No `isDark: Boolean` is passed from Swift to Kotlin.
- **V-D4 · Verification scope trade-off (accepted):** 02-04-CKP human-verify gate switches from "10× OS-level appearance toggle" to "10× in-app button press". The system-appearance → palette code path is **no longer covered** by the manual gate. User explicitly accepted this coverage gap.

### Action Items — all landed 2026-05-18

- [x] **V-1 · 02-CONTEXT.md:** Added `D-17` documenting in-app toggle. Closed Claude's Discretion items #1, #2, #3, #4. Pitfall 7 invariant restated: "platform UI layer is the sole selector; no `isDark: Boolean` crosses into `commonMain`."
- [x] **V-2 · 02-02-PLAN.md (Android):** `files_modified` extended with `greeting/GreetingScreen.kt`. AppTheme signature changed to `@Composable fun AppTheme(isDark: Boolean = isSystemInDarkTheme(), content)`. MainActivity hoists `themeOverride: Boolean?` via `rememberSaveable`. New Task 3 adds `isDark` + `onToggleTheme` params to GreetingScreen with a Button. **Deviation from V-D3 (logged here):** `AppCompatDelegate.setDefaultNightMode` was discarded because MainActivity extends `ComponentActivity` (not `AppCompatActivity`) — switching base class + adding `androidx.appcompat` is scope creep. Pure-Compose state hoist gives identical UX with zero new dependencies. Trade-off documented in D-17.
- [x] **V-3 · 02-03-PLAN.md (iOS):** `files_modified` extended with `ContentView.swift`. `iosApp.swift` hoists `@State themeOverride: ColorScheme?` at `WindowGroup` root, applies `.preferredColorScheme(themeOverride)` and `.environment(\.appTheme, AppTheme.build(isDark: (themeOverride ?? systemColorScheme) == .dark))`. ContentView pass-through accepts `Binding<ColorScheme?>`. GreetingScreen renders cycle button (nil → .light → .dark → nil).
- [x] **V-4 · 02-04-PLAN.md:** `02-04-CKP` human-verify instructions rewritten for both platforms to drive the in-app button. Dropped coverage documented inline ("OS-level appearance change path … no dedicated manual gate; relies on the same `AppTheme.build(isDark:)` adapter").
- [x] **V-5 · This file:** `Manual-Only Verifications` table updated to the in-app toggle steps + AppCompat negative-dependency assertion + coverage-gap row. Approval flipped to `approved 2026-05-18`.

#### Follow-up revisions (post-validation, applied 2026-05-18)

Three QA recommendations from `docs/testcases/02-DESIGN-TOKEN-BRIDGE.md` (generated by `/docs-project:qa`) landed as further plan edits after V-1..V-5 were approved:

- **QA-1:** Added boundary-alpha XCTests to `02-03-PLAN.md` Task 3 — `testColorAdapterPreservesAlphaForOpaqueWhite` (`0xFFFFFFFF`) and `testColorAdapterPreservesAlphaForOpaqueBlack` (`0xFF000000`). Closes ck:scenario #1 + #2 (both Critical).
- **QA-2:** Extended `darkColorsBrightInDark()` in `02-04-PLAN.md` Task 1 from 2 → 5 assertions (added onBackground inverse, surfaceContainerLowest darker, inversePrimary↔primary M3 sanity). Closes ck:scenario #22 (Critical).
- **QA-3:** Android cycle now three-state (`null → false → true → null`) matching iOS — V-2's original binary `onToggleTheme = !isDark` was superseded by `onCycleTheme` with three button labels. The V-2 audit line above describing "isDark + onToggleTheme" reflects the pre-QA-3 state; current plan content uses `themeOverride + onCycleTheme`. Closes ck:scenario #32 (High).

### No Plan Revisions Needed

- 02-01-PLAN.md: hex values, structure (`object DesignTokens`), 36-constant audit — all confirmed.
- 02-03-PLAN.md: `struct AppTheme` + sub-structs (`ThemeColors`, `ThemeTypography`, ...) — confirmed.
- Validation cadence, sampling rate, Wave 0 coverage — confirmed.

### Recommendation

**Proceed to `/cook .planning/phases/02-design-token-bridge`.** All five action items landed 2026-05-18. The plans now describe the in-app toggle scope explicitly (D-17), with the AppCompat → state-hoist deviation documented in V-2 and D-17 rationale. Approval flipped to `approved`.
