# Phase 02 — Design Token Bridge: QA Test Plan

**Feature:** Design Token Bridge (KMP `commonMain` primitives → Compose `MaterialTheme` + SwiftUI `EnvironmentKey`)
**Phase:** 02
**Plan dir:** `.planning/phases/02-design-token-bridge/`
**PRD-equivalent:** `.planning/REQUIREMENTS.md` §THEME + `.planning/phases/02-design-token-bridge/02-CONTEXT.md` (decisions D-01..D-17)
**Generated:** 2026-05-18
**Status:** Draft — pending `/cook` execution

---

## Acceptance Criteria

Sourced from `.planning/REQUIREMENTS.md §Theming` and `02-CONTEXT.md §decisions`.

| AC | Requirement | Source |
|----|-------------|--------|
| **AC-01** (THEME-01) | `DesignTokens` in `:shared-core/commonMain` defines colors (`Long` ARGB), typography (`TextStyleToken`), spacing, radius — **primitives only**, no Compose or SwiftUI types | REQUIREMENTS.md |
| **AC-02** (THEME-02) | `LightColors` and `DarkColors` palettes defined; every color is `Long` with `L` suffix; `commonTest` asserts no constant overflowed to negative | REQUIREMENTS.md |
| **AC-03** (THEME-03) | Compose `AppTheme` adapter maps tokens to `MaterialTheme` (`ColorScheme`, `Typography`, `Shapes`) on Android | REQUIREMENTS.md |
| **AC-04** (THEME-04) | SwiftUI `AppTheme` adapter maps tokens to environment values (`Color`, `Font`, spacing modifiers) on iOS | REQUIREMENTS.md |
| **AC-05** (THEME-05) | Dark mode follows system setting on both platforms; switching system theme updates both apps without restart | REQUIREMENTS.md |
| **AC-06** (D-17, validated 2026-05-18) | In-app theme toggle on `GreetingScreen` overrides system appearance; 10× rapid tap flips palette without restart; Pitfall 7 invariant preserved (palette selection stays in UI layer) | 02-CONTEXT.md D-17 |

---

## Test Strategy

### Levels

| Level | Tool | Sourceset / target | Runtime | Used for |
|-------|------|--------------------|---------|----------|
| Unit (shared) | `kotlin.test` + `kotest-assertions-core` + Turbine | `:shared-core` `commonTest` (JVM + iosSimulatorArm64) | ~5–30s | DesignTokens primitives, palette correctness, rapid-toggle simulation |
| Unit (Swift) | XCTest | `iosApp/iosAppTests/` | ~5s per build | `Color(argb: Int64)` alpha extraction (Pitfall 6 / D-08) |
| Build gate (Android) | Gradle | `:androidApp:assembleDebug` | ~15s | Compose adapter compiles; no hex literals in `theme/` |
| Build gate (iOS) | `xcodebuild` | `iosApp` scheme, iPhone 16 simulator | ~60s cold, ~10s cached | AppTheme.swift in `project.pbxproj`; full link |
| Negative-assertion | `grep -rE` | repo | <1s | No platform imports in commonMain; no AppCompat; no hex literals |
| Manual smoke | Human | Android device/emulator + iOS Simulator | ~5 min total | In-app toggle 10× per platform; rotation; first-launch system follow |

### Coverage targets

- **100% of ACs** mapped to ≥1 test case (see Traceability Matrix below).
- **All Critical scenarios** from `/ck-scenario` (6 of them) covered by an automated test or build gate. Manual smoke covers rotation guard (scenario 11).
- **Pitfall 6 + Pitfall 7** each have at least one dedicated regression test.

### Out of scope for this plan

- Compose UI screenshot regression (deferred until `:androidApp/src/androidTest/` infrastructure exists — not in any current plan).
- XCUITest end-to-end (deferred until iOS UI test target exists in `iosApp.xcodeproj`).
- Cross-platform pixel-diff visual regression (per Phase 02 scope; manual visual check is sufficient).

---

## Risk Assessment

| Risk | Impact | Likelihood | Mitigation | Test Coverage |
|------|--------|-----------|------------|---------------|
| **Pitfall 6** — ARGB Long sign-bit corruption in Swift bridge | Critical (transparent UI for every `0xFF...` constant) | Low (if `Int64` enforced) → Medium (after SKIE upgrades) | XCTest `testColorAdapterPreservesAlphaFor*`; `Int64` parameter in `Color(argb:)`; `commonTest` no-negative assertion | TC-021, TC-022, TC-023, TC-001 |
| **Pitfall 7** — Dark mode selection in wrong layer | Critical (light palette in dark mode, vice versa) | Low | `darkColorsBrightInDark` + `rapidToggleSimulation` tests; D-17 architectural invariant; no `isDark` parameter in `commonMain` | TC-008, TC-009, TC-011, TC-034 |
| **Missing `L` suffix** on new color constant | Critical (compile error or runtime negative value) | Medium (every new role is a chance) | `noColorConstantIsNegative` extended to all 72 constants; build gate | TC-001 |
| **AppCompat dependency** pulled transitively | High (silent night-mode delegate clash) | Low | `grep -rE 'AppCompatDelegate\|androidx\.appcompat'` returns 0 | TC-018 |
| **SKIE accessor name change** after upgrade | High (iOS build failure) | Medium (SKIE evolves fast) | `xcodebuild` gate; `gradle/libs.versions.toml` pin | TC-024 |
| **New ColorScheme role** added in Material3 minor version → defaults leak | High (D-01 violation, silent) | Low (M3 stable in 1.4.x) | Code review checklist on Compose BOM bump; surfaceTint explicit | TC-014 |
| **Rotation loses theme override** | High (UX regression, demo broken) | Low (rememberSaveable) | Manual rotation guard | TC-028 |
| **Process death loses override** | Medium (documented trade-off in D-17) | High (iOS kills aggressively) | Documented expected behavior | TC-033 |

---

## Test Cases

35 test cases total. Numbered sequentially; grouped by surface area.

### Group A — DesignTokens primitives (AC-01, AC-02)

#### TC-001: `noColorConstantIsNegative` — all 72 constants
- **Priority:** P1
- **Type:** Unit (commonTest)
- **AC Reference:** AC-01, AC-02
- **Precondition:** `shared-core/src/commonMain/.../DesignTokens.kt` exists with `LightColors` + `DarkColors` objects
- **Steps:**
  1. `./gradlew :shared-core:jvmTest --tests "*.DesignTokensTest.noColorConstantIsNegative"`
  2. Inspect `shared-core/build/test-results/jvmTest/TEST-*.xml`
- **Expected:** Test passes. The explicit-list assertion includes all 72 constants (36 light + 36 dark) and asserts each `>= 0L`.
- **Test Data:** All 72 `Long` constants from `LightColors` + `DarkColors`. Edge anchor: `LightColors.primary = 0xFF3F51B5L`.

#### TC-002: All 36 M3 ColorScheme roles present in both palettes
- **Priority:** P1
- **Type:** Unit (commonTest)
- **AC Reference:** AC-02
- **Precondition:** `DesignTokens.kt` exists
- **Steps:**
  1. Open `DesignTokensTest.kt`
  2. Verify the explicit-list-test enumerates all 36 roles (per 02-CONTEXT D-01) for **both** `LightColors` and `DarkColors`
  3. Confirm `surfaceTint` is in the list (was a Wave 0 addition — easy to miss)
- **Expected:** Both palettes have 36 `Long` constants. Test list length = 72.
- **Test Data:** Role names enumerated in 02-CONTEXT D-01.

#### TC-003: Typography has all 15 M3 type-scale roles
- **Priority:** P1
- **Type:** Unit (commonTest)
- **AC Reference:** AC-01
- **Precondition:** `DesignTokens.typography` object exists
- **Steps:**
  1. Run `typographyRolesAreComplete()` test from `DesignTokensTest.kt`
- **Expected:** All 15 roles (`displayLarge`..`labelSmall`) are non-null `TextStyleToken` instances.
- **Test Data:** Role names from 02-CONTEXT D-05.

#### TC-004: Spacing scale is monotonically increasing
- **Priority:** P2
- **Type:** Unit (commonTest)
- **AC Reference:** AC-01
- **Precondition:** `DesignTokens.spacing` exists
- **Steps:** Run `spacingIsOrdered()` test
- **Expected:** `xxs < xs < sm < md < lg < xl < xxl` (assertions on adjacent pairs)
- **Test Data:** `2f, 4f, 8f, 16f, 24f, 32f, 48f`

#### TC-005: Radius scale ordering (semantic + numeric)
- **Priority:** P2
- **Type:** Unit (commonTest)
- **AC Reference:** AC-01
- **Precondition:** `DesignTokens.radius` exists
- **Steps:** Assert `none < xs < sm < md < lg < xl < full`
- **Expected:** Pass. `none = 0f`, `full = 9999f`.
- **Test Data:** `0f, 4f, 8f, 12f, 16f, 28f, 9999f`

#### TC-006: No platform imports in `commonMain`
- **Priority:** P1
- **Type:** Build gate (grep)
- **AC Reference:** AC-01
- **Precondition:** None
- **Steps:**
  1. `grep -rE 'androidx\.|android\.|UIKit|SwiftUI|androidx\.compose' shared-core/src/commonMain/`
- **Expected:** Zero hits. `commonMain` contains only Kotlin stdlib + primitives.
- **Test Data:** —

#### TC-007: `TextStyleToken` has 4 documented fields
- **Priority:** P2
- **Type:** Unit (commonTest, structural)
- **AC Reference:** AC-01
- **Precondition:** `TextStyleToken.kt` exists
- **Steps:** Reflection on `TextStyleToken::class.declaredMemberProperties` size == 4
- **Expected:** Fields `size: Float`, `weight: Int`, `lineHeight: Float`, `letterSpacing: Float` (per D-04)
- **Test Data:** —

---

### Group B — Palette correctness (AC-02, AC-05)

#### TC-008: `rapidToggleSimulation` — 10 alternations
- **Priority:** P1
- **Type:** Unit (commonTest)
- **AC Reference:** AC-05, AC-06
- **Precondition:** Test exists in `DesignTokensTest.kt` (added in plan 02-04)
- **Steps:**
  1. Loop `(0 until 10)`; on odd index pick `DarkColors.primary`, on even index pick `LightColors.primary`
  2. Assert `LightColors.primary != DarkColors.primary`
  3. Assert each selection matches expectation
- **Expected:** Pass — palettes are distinct objects, alternation is deterministic.
- **Test Data:** 10 iterations.

#### TC-009: `darkColorsBrightInDark` — background + surface inverted
- **Priority:** P1
- **Type:** Unit (commonTest)
- **AC Reference:** AC-02, AC-05
- **Precondition:** Test exists in `DesignTokensTest.kt`
- **Steps:**
  1. Assert `DarkColors.background < LightColors.background`
  2. Assert `DarkColors.surface < LightColors.surface`
- **Expected:** Pass. `0x1C1B1FL < 0xFFFBFEL`.
- **Test Data:** Background + surface roles only.

#### TC-010: `LightColors.primary != DarkColors.primary`
- **Priority:** P1
- **Type:** Unit (commonTest)
- **AC Reference:** AC-02
- **Precondition:** None
- **Steps:** Single assertion in `rapidToggleSimulation`
- **Expected:** `0xFF3F51B5L != 0xFFBBC2FFL`
- **Test Data:** —

#### TC-011: Extended palette-swap guard — additional roles
- **Priority:** P2
- **Type:** Unit (commonTest) — **NEW, recommended per /ck-scenario action item**
- **AC Reference:** AC-02, AC-05
- **Precondition:** Extend `darkColorsBrightInDark()`
- **Steps:** Assert:
  1. `DarkColors.onBackground > LightColors.onBackground` (inverse: dark mode's `on` colors are lighter)
  2. `DarkColors.surfaceContainerLowest < LightColors.surfaceContainerLowest`
  3. `DarkColors.inversePrimary != DarkColors.primary` (inverse role makes sense within dark)
- **Expected:** All pass.
- **Test Data:** Constants from `02-01-PLAN.md §144-223`.

#### TC-012: Inverse-pair sanity — `inversePrimary` semantics
- **Priority:** P3
- **Type:** Unit (commonTest)
- **AC Reference:** AC-02
- **Precondition:** None
- **Steps:** Assert `LightColors.inversePrimary == DarkColors.primary` is approximately true (the inverse role mirrors the other palette's primary by M3 convention)
- **Expected:** `0xFFBBC2FFL == 0xFFBBC2FFL` and `DarkColors.inversePrimary == LightColors.primary` (`0xFF3F51B5L`)
- **Test Data:** As written.

---

### Group C — Compose AppTheme adapter (AC-03)

#### TC-013: `assembleDebug` exits 0
- **Priority:** P1
- **Type:** Build gate
- **AC Reference:** AC-03
- **Precondition:** `AppTheme.kt` and updated `MainActivity.kt` exist (plan 02-02)
- **Steps:**
  1. `./gradlew :androidApp:assembleDebug 2>&1 | tail -10`
- **Expected:** `BUILD SUCCESSFUL`, no warnings about M3 default leaking.
- **Test Data:** —

#### TC-014: ColorScheme constructor uses 36 roles incl. `surfaceTint`
- **Priority:** P1
- **Type:** Build gate (grep) + unit
- **AC Reference:** AC-03
- **Precondition:** `AppTheme.kt` exists
- **Steps:**
  1. `grep -c 'surfaceTint = Color(palette.surfaceTint)' androidApp/.../theme/AppTheme.kt` → 1
  2. `grep -c '= Color(palette\.' androidApp/.../theme/AppTheme.kt` → 36
- **Expected:** Both counts match. No M3 default leaks for `surfaceTint`.
- **Test Data:** —

#### TC-015: `AppTheme(isDark)` accepts override; defaults to `isSystemInDarkTheme()`
- **Priority:** P1
- **Type:** Build gate (grep)
- **AC Reference:** AC-06 (D-17)
- **Precondition:** `AppTheme.kt` updated per V-2
- **Steps:**
  1. `grep -c 'isDark: Boolean = isSystemInDarkTheme()' androidApp/.../theme/AppTheme.kt` → 1
- **Expected:** Signature matches D-17 contract.
- **Test Data:** —

#### TC-016: No hex literals in `androidApp` theme code
- **Priority:** P1
- **Type:** Negative assertion (grep)
- **AC Reference:** AC-03 (D-12)
- **Precondition:** AppTheme + MainActivity + GreetingScreen edits landed
- **Steps:**
  1. `grep -rE '0x[0-9A-Fa-f]{6,8}L?' androidApp/src/main/kotlin/dev/viethung/skeleton/android/`
- **Expected:** Zero hits across entire androidApp source tree.
- **Test Data:** —

#### TC-017: `MainActivity` wraps with `AppTheme`, not bare `MaterialTheme`
- **Priority:** P1
- **Type:** Build gate (grep)
- **AC Reference:** AC-03
- **Precondition:** MainActivity updated per plan 02-02 Task 2
- **Steps:**
  1. `grep -c 'MaterialTheme' androidApp/.../MainActivity.kt` → 0
  2. `grep -c 'AppTheme' androidApp/.../MainActivity.kt` → ≥ 2 (import + call)
  3. `grep -c 'rememberSaveable' androidApp/.../MainActivity.kt` → 1
- **Expected:** All match.
- **Test Data:** —

#### TC-018: No AppCompat dependency (D-17 rationale)
- **Priority:** P1
- **Type:** Negative assertion (grep)
- **AC Reference:** AC-06 (D-17 rationale)
- **Precondition:** None
- **Steps:**
  1. `grep -rE 'AppCompatDelegate|androidx\.appcompat' androidApp/`
  2. `grep 'androidx.appcompat' gradle/libs.versions.toml`
- **Expected:** Zero hits in both. Confirms state-hoist over AppCompatDelegate.
- **Test Data:** —

#### TC-019: GreetingScreen renders light palette in light mode (smoke)
- **Priority:** P2
- **Type:** Manual (visual)
- **AC Reference:** AC-03, AC-05
- **Precondition:** App installed via `:androidApp:installDebug`; system in light mode, no override
- **Steps:**
  1. Cold-start app
  2. Inspect background color of `GreetingScreen` (Box)
- **Expected:** Near-white `0xFFFFFBFEL`, primary text color matches indigo `0xFF3F51B5L` direction.
- **Test Data:** Visual.

#### TC-020: GreetingScreen renders dark palette in dark mode (smoke)
- **Priority:** P2
- **Type:** Manual (visual)
- **AC Reference:** AC-03, AC-05
- **Precondition:** App installed; system in dark mode, no override
- **Steps:**
  1. Cold-start app with system dark mode active
  2. Inspect background color
- **Expected:** Near-black `0xFF1C1B1FL`, primary text now uses dark-palette indigo `0xFFBBC2FFL`.
- **Test Data:** Visual.

---

### Group D — SwiftUI AppTheme adapter (AC-04)

#### TC-021: `testColorAdapterPreservesAlphaForFFOpaqueLong` — `0xFF3F51B5`
- **Priority:** P1
- **Type:** Unit (XCTest)
- **AC Reference:** AC-04 (Pitfall 6 / D-08)
- **Precondition:** `iosApp/iosAppTests/AppThemeTests.swift` exists (plan 02-03 Task 3)
- **Steps:**
  1. Open `iosApp.xcodeproj` in Xcode
  2. `Cmd+U` on iPhone 16 simulator (or `xcodebuild test -scheme iosApp`)
- **Expected:** Test passes. `Color(argb: 0xFF3F51B5).opacity ≈ 1.0` within tolerance 0.01.
- **Test Data:** `argb: Int64 = 0xFF3F51B5`.

#### TC-022: Alpha extraction for `0xFFFFFFFFL` (opaque white) — **NEW**
- **Priority:** P1
- **Type:** Unit (XCTest) — **recommended addition per /ck-scenario action item**
- **AC Reference:** AC-04
- **Precondition:** Add sibling test to `AppThemeTests.swift`
- **Steps:**
  1. `let argb: Int64 = 0xFFFFFFFF`
  2. Extract alpha byte
  3. `XCTAssertEqual(alpha, 1.0, accuracy: 0.001)`
- **Expected:** Pass. Largest opaque ARGB exposes any unsigned-shift bug.
- **Test Data:** `0xFFFFFFFF` (`LightColors.surfaceContainerLowest`)

#### TC-023: Alpha extraction for `0xFF000000L` (opaque black) — **NEW**
- **Priority:** P1
- **Type:** Unit (XCTest) — **recommended addition per /ck-scenario action item**
- **AC Reference:** AC-04
- **Precondition:** Add sibling test to `AppThemeTests.swift`
- **Steps:**
  1. `let argb: Int64 = 0xFF000000`
  2. Extract alpha byte
  3. Assert `alpha == 1.0` and `r == g == b == 0.0`
- **Expected:** Pass. RGB=0 case exposes any byte-extraction defect.
- **Test Data:** `0xFF000000` (`LightColors.scrim`)

#### TC-024: `xcodebuild` exits 0 (pbxproj registration)
- **Priority:** P1
- **Type:** Build gate
- **AC Reference:** AC-04
- **Precondition:** `AppTheme.swift` + `AppThemeTests.swift` added to `project.pbxproj`
- **Steps:**
  1. `xcodebuild -project iosApp/iosApp.xcodeproj -scheme iosApp -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
- **Expected:** Build succeeds. Catches missing pbxproj entries that grep would miss.
- **Test Data:** —

#### TC-025: `GreetingScreen.swift` uses `theme.colors.error` (no `.red`)
- **Priority:** P1
- **Type:** Negative assertion (grep)
- **AC Reference:** AC-04 (D-13)
- **Precondition:** GreetingScreen edited per plan 02-03 Task 2
- **Steps:**
  1. `grep -cE '\.foregroundColor\(\.red\)|\.foregroundStyle\(\.red\)' iosApp/iosApp/Greeting/GreetingScreen.swift` → 0
  2. `grep -c 'theme.colors.error' iosApp/iosApp/Greeting/GreetingScreen.swift` → 1
- **Expected:** Both match.
- **Test Data:** —

---

### Group E — In-app theme toggle (AC-06 / D-17)

#### TC-026: Android — three-state cycle, single advance per tap
- **Priority:** P1
- **Type:** Manual (visual)
- **AC Reference:** AC-06
- **Precondition:** `:androidApp:installDebug`, app cold-started, no override (button reads "Override theme")
- **Steps:**
  1. Tap → label becomes "Switch to Dark", palette forced light
  2. Tap → label becomes "Switch to System", palette forced dark
  3. Tap → label returns to "Override theme", palette follows system
- **Expected:** Each tap advances the cycle by exactly one step within 1-2 frames. Three-state cycle matches iOS (TC-029) — Android no longer asymmetric (closes ck:scenario #32).
- **Test Data:** Visual.

#### TC-027: Android — 10× rapid tap, no restart, cycle completes
- **Priority:** P1
- **Type:** Manual (smoke)
- **AC Reference:** AC-06 (D-17 SC4)
- **Precondition:** Same as TC-026
- **Steps:**
  1. Tap toggle button 10 times in < 3 seconds
  2. Watch for restart / blank screen / lag
- **Expected:** No restart. 10 taps = 3 full cycles + 1 → ends on "Switch to Dark" (themeOverride=false, palette forced light). Label and palette updated each tap.
- **Test Data:** 10 taps.

#### TC-028: Android — rotation persists override (`rememberSaveable` guard)
- **Priority:** P1
- **Type:** Manual (smoke)
- **AC Reference:** AC-06 (D-17 rotation guard)
- **Precondition:** Override active (e.g., user has tapped once → light override on dark system)
- **Steps:**
  1. Rotate device 90°
  2. Observe whether palette flips back to system or holds override
- **Expected:** Holds override. `rememberSaveable` survives configuration change.
- **Test Data:** Manual rotation.

#### TC-029: iOS — cycle nil → .light → .dark → nil with correct labels
- **Priority:** P1
- **Type:** Manual (visual)
- **AC Reference:** AC-06
- **Precondition:** `iosApp` running in iPhone 16 sim, no override (button reads "Override theme")
- **Steps:**
  1. Tap → label becomes "Switch to Dark", palette stays/becomes light
  2. Tap → label becomes "Switch to System", palette flips dark
  3. Tap → label returns to "Override theme", palette follows system
- **Expected:** All 3 transitions correct, labels match cycle stage.
- **Test Data:** Visual.

#### TC-030: iOS — 10× rapid tap, no restart, cycle completes
- **Priority:** P1
- **Type:** Manual (smoke)
- **AC Reference:** AC-06 (D-17 SC4)
- **Precondition:** Same as TC-029
- **Steps:**
  1. Tap button 10 times in < 3 seconds
  2. Observe palette flips, button labels, app lifecycle
- **Expected:** No restart. 10 taps complete 3 full cycles + 1 extra (10 mod 3 = 1 → ends on `.light`).
- **Test Data:** 10 taps.

#### TC-031: System dark mode change while override active → override wins
- **Priority:** P1
- **Type:** Manual (smoke, both platforms)
- **AC Reference:** AC-06 (D-17 Pitfall 7 invariant)
- **Precondition:** User has set in-app override (e.g., to dark)
- **Steps:**
  1. With override active, open system Settings → Display → toggle dark mode opposite to override
  2. Return to app
- **Expected:** App ignores system change; palette continues to honor override. Verifies "override > system".
- **Test Data:** Manual OS toggle.

#### TC-032: First launch follows OS appearance (no override)
- **Priority:** P1
- **Type:** Manual (cold-start)
- **AC Reference:** AC-05
- **Precondition:** Fresh app install (uninstall + reinstall) OR `themeOverride = nil` on iOS
- **Steps:**
  1. Verify system appearance (light or dark)
  2. Cold-start app
  3. Inspect palette
- **Expected:** Palette matches system appearance. Button labels reflect "no override" state.
- **Test Data:** Both system modes.

#### TC-033: Process death resets override (documented trade-off)
- **Priority:** P2
- **Type:** Manual (documented behavior)
- **AC Reference:** AC-06 (D-17 trade-off)
- **Precondition:** Override active
- **Steps:**
  1. Force-stop app (Android: Settings → Apps → Force Stop; iOS: swipe up + away)
  2. Relaunch
  3. Inspect palette + button label
- **Expected:** Override is gone. Palette follows system; button reads "Switch to Dark" (Android) or "Override theme" (iOS). This is **expected** per D-17 — not a defect.
- **Test Data:** Manual force-stop.

---

### Group F — Cross-cutting negative assertions

#### TC-034: No `isDark: Boolean` parameter in `commonMain` (Pitfall 7 invariant)
- **Priority:** P1
- **Type:** Negative assertion (grep)
- **AC Reference:** AC-05, AC-06 (D-16)
- **Precondition:** None
- **Steps:**
  1. `grep -rE 'isDark\s*:\s*Boolean' shared-core/src/commonMain/`
- **Expected:** Zero hits. Confirms no Kotlin code in `commonMain` accepts a darkness flag.
- **Test Data:** —

#### TC-035: No hex literals in `iosApp/Greeting/` or `iosApp/App/`
- **Priority:** P1
- **Type:** Negative assertion (grep)
- **AC Reference:** AC-04 (D-13)
- **Precondition:** GreetingScreen edited per plan 02-03
- **Steps:**
  1. `grep -rE 'Color\(red:.*green:.*blue:' iosApp/iosApp/Greeting/ iosApp/iosApp/App/`
- **Expected:** Zero hits. Raw color constructors live only in `iosApp/iosApp/Theme/AppTheme.swift`.
- **Test Data:** —

---

## Traceability Matrix

| AC | Test Cases | Coverage |
|----|-----------|----------|
| **AC-01** (THEME-01 — primitives only) | TC-001, TC-002, TC-003, TC-004, TC-005, TC-006, TC-007 | ✅ Full |
| **AC-02** (THEME-02 — Light/Dark palettes, no-negative) | TC-001, TC-002, TC-008, TC-009, TC-010, TC-011, TC-012 | ✅ Full |
| **AC-03** (THEME-03 — Compose adapter) | TC-013, TC-014, TC-015, TC-016, TC-017, TC-018, TC-019, TC-020 | ✅ Full |
| **AC-04** (THEME-04 — SwiftUI adapter) | TC-021, TC-022, TC-023, TC-024, TC-025, TC-035 | ✅ Full |
| **AC-05** (THEME-05 — dark mode without restart) | TC-008, TC-019, TC-020, TC-027, TC-030, TC-031, TC-032, TC-034 | ✅ Full |
| **AC-06** (D-17 — in-app toggle, validated 2026-05-18) | TC-015, TC-018, TC-026, TC-027, TC-028, TC-029, TC-030, TC-031, TC-033, TC-034 | ✅ Full |

**Coverage:** 6 / 6 ACs mapped (100%). Every AC is touched by ≥ 1 P1 test.

---

## Critical-scenario Mapping (from `/ck-scenario`)

| /ck-scenario # | Severity | Test Case |
|---|---|---|
| 1 (`0xFFFFFFFFL` opaque white) | Critical | TC-022 (new) |
| 2 (`0xFF000000L` opaque black) | Critical | TC-023 (new) |
| 3 (Missing `L` suffix) | Critical | TC-001 (no-negative guard) + plan-level lint regex |
| 11 (Rotation during override) | Critical | TC-028 |
| 21 (SKIE Int32 regression) | Critical | TC-021, TC-022, TC-023 |
| 22 (Palette swap) | Critical | TC-009, TC-011 (new role coverage) |

All 6 Critical scenarios have ≥ 1 dedicated test case.

---

## Execution Plan

1. **Pre-cook gate** — run TC-006 (no platform imports) and TC-034 (no isDark in commonMain) BEFORE `/cook`. These should already pass on the un-modified repo.
2. **Per-wave gate** during `/cook`:
   - Wave 1 (plan 02-01): run TC-001..TC-007 after Task 1; TC-008..TC-010 after Task 2.
   - Wave 2 (plan 02-02 + 02-03): TC-013..TC-018 (Android); TC-021..TC-025 (iOS). Add TC-022, TC-023 to AppThemeTests.swift per /ck-scenario action item.
   - Wave 3 (plan 02-04): TC-008..TC-012 (extend `darkColorsBrightInDark`); manual TC-026..TC-033 in `02-04-CKP`.
3. **Post-cook** — full QA via `/qa-full:full "design token bridge"`.

---

## Buoc 4 Self-Check

```
📋 QA Test Plan Self-Check:
├── Goi Skill tool ck:scenario? ✅ (35 scenarios from preceding /ck-scenario turn)
├── So scenarios: 35 (>= 30 ✅)
├── So test cases: 35 (1:1 input ratio — appropriate for tightly scoped feature)
├── Map 100% ACs? ✅ (all 6 ACs covered, traceability matrix complete)
├── Co Traceability Matrix? ✅ (AC ↔ TC bidirectional)
├── Co Risk Assessment? ✅ (8 risks with impact/likelihood/mitigation)
├── Co severity cho moi TC? ✅ (Priority P1/P2/P3 on every TC)
└── Co test data? ✅ (every TC lists fixtures or "Visual" for manual)
```

---

## Recommendations (action items for plan revision)

These extend Phase 02 plans based on `/ck-scenario` Critical findings. **Cheap additions; suggest before `/cook`:**

1. ~~**Add TC-022 + TC-023 to `02-03-PLAN.md` Task 3**~~ — **APPLIED 2026-05-18.** Two sibling tests added to `AppThemeTests.swift`: `testColorAdapterPreservesAlphaForOpaqueWhite` (0xFFFFFFFF) and `testColorAdapterPreservesAlphaForOpaqueBlack` (0xFF000000). Acceptance criteria updated.
2. ~~**Extend `darkColorsBrightInDark()` in `02-04-PLAN.md` Task 1**~~ — **APPLIED 2026-05-18.** Test now has 5 role-pair assertions: background+surface+surfaceContainerLowest darker in dark; onBackground inverted; inversePrimary↔primary equality across palettes per M3 spec.
3. ~~**Resolve Android cycle asymmetry** (scenario 32)~~ — **APPLIED 2026-05-18.** Android now three-state cycle (`null → false → true → null`) matching iOS. `MainActivity` uses `onCycleTheme` callback; `GreetingScreen` accepts `themeOverride: Boolean?` and renders button label as "Override theme" / "Switch to Dark" / "Switch to System". TC-026/TC-027 + 02-04-CKP manual steps updated; ck:scenario #32 closed.

---

*Test plan generated 2026-05-18. Based on `.planning/REQUIREMENTS.md §THEME` (THEME-01..05), `.planning/phases/02-design-token-bridge/02-CONTEXT.md` (D-01..D-17 incl. validated in-app toggle D-17), and 35-scenario `/ck-scenario` output.*
