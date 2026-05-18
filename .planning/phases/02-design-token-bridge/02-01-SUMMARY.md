---
phase: 02-design-token-bridge
plan: "01"
subsystem: design-tokens
tags: [kmp, common-main, design-tokens, material3, pitfall-6, color-palette]

requires: []
provides:
  - shared-core/.../theme/DesignTokens.kt — single source of truth for all visual primitives (commonMain)
  - shared-core/.../theme/DesignTokensTest.kt — Pitfall 6 regression guard + completeness assertions (commonTest)
  - ColorPalette interface enabling typed `if (isDark) DarkColors else LightColors` selection
affects: [02-02 Android adapter, 02-03 iOS adapter, 02-04 dark-mode contract tests]

tech-stack:
  added: []
  patterns:
    - "All color constants are `override val <name>: Long = 0xFF...L` — L suffix is load-bearing (D-02 / D-15 / Pitfall 6)"
    - "LightColors and DarkColors implement a shared `ColorPalette` interface so `if/else` selection compiles"
    - "TextStyleToken is a primitives-only data class (no Compose/SwiftUI types) — bridges to both adapters by structure"
    - "commonTest uses kotlin.test.Test exclusively (NEVER org.junit.Test) for iosSimulatorArm64 compatibility"

key-files:
  created:
    - shared-core/src/commonMain/kotlin/dev/viethung/core/theme/DesignTokens.kt
    - shared-core/src/commonTest/kotlin/dev/viethung/core/theme/DesignTokensTest.kt
  modified: []

key-decisions:
  - "Introduced `interface ColorPalette` (delta from plan): the plan assumed `if (isDark) DesignTokens.DarkColors else DesignTokens.LightColors` would compile, but two unrelated Kotlin `object`s have no common supertype so property access on the union fails. The interface gives both objects a shared type. Plan grep criteria still hold (`object LightColors` + `: Long = 0x...L` patterns unchanged); only `const val` became `override val`."
  - "Used full Material 3 ColorScheme mirror — 36 roles including surfaceTint — to avoid M3 default leakage (D-01)"
  - "Skeleton identity palette per D-03: indigo primary 0xFF3F51B5L, teal tertiary 0xFF009688L, neutral surface greys; intentional placeholder for cloned products"

patterns-established:
  - "Primitives-only commonMain rule enforced: zero imports in DesignTokens.kt"
  - "Explicit-list test pattern for cross-target reliability (reflection unreliable on iosSimulatorArm64)"
  - "ColorPalette interface as the contract between commonMain palette objects and platform adapters"

requirements-completed: [THEME-01, THEME-02]

duration: 8min
completed: 2026-05-18
---

# Phase 2 Plan 01: DesignTokens.kt + commonTest

**Wave 1 anchor — single source of truth for all visual primitives, enforced by the KMP compiler to reject Compose and SwiftUI imports on either target.**

## Accomplishments
- Created `DesignTokens.kt` in `:shared-core/commonMain` with zero imports: 36-role `LightColors` and `DarkColors` palettes (Skeleton indigo identity), 15-role M3 typography scale, 7-step spacing, 7-step radius — all primitive `Long`/`Float`/`Int`.
- Created `DesignTokensTest.kt` in `:shared-core/commonTest` with three tests: `noColorConstantIsNegative()` (Pitfall 6 guard, explicit-list across all 72 constants), `typographyRolesAreComplete()` (15 M3 roles present, all `size > 0f`), `spacingIsOrdered()` (xxs < xs < … < xxl).
- All 3 tests pass on both `:shared-core:testAndroidHostTest` (Android host) and `:shared-core:iosSimulatorArm64Test` — Pitfall 6 cross-target gate green.

## Verification
- `./gradlew :shared-core:testAndroidHostTest --tests "dev.viethung.core.theme.DesignTokensTest"` — 3 tests, 0 failures
- `./gradlew :shared-core:iosSimulatorArm64Test --tests "dev.viethung.core.theme.DesignTokensTest"` — 3 tests, 0 failures
- `grep -c 'import ' shared-core/src/commonMain/kotlin/dev/viethung/core/theme/DesignTokens.kt` → 0
- `grep -c 'surfaceTint' DesignTokens.kt` → 2 (LightColors + DarkColors)
- All 72 `: Long = 0x...L` constants present, every line ends with `L` suffix

## Deviations from Plan
- **ColorPalette interface introduced (Wave 1 delta).** The plan structure `object LightColors { const val primary: Long = 0xFF... }` was preserved in spirit but each `const val` became `override val` and both objects now implement a new `ColorPalette` interface. Reason: `if (isDark) DarkColors else LightColors` cannot compile in `02-02`'s Compose adapter without a shared type — Kotlin infers `Any` for two unrelated singletons and rejects every property access. The interface adds zero runtime cost and is invisible to the Swift bridge (header still emits `swift_name("DesignTokens.LightColors")` etc.). Acceptance criteria for hex-literal patterns and L suffix all still hold.

## Issues Encountered
- First test invocation used `:shared-core:jvmTest` (per the plan) but the actual KMP target is `android` (host), not `jvm`. Correct tasks are `testAndroidHostTest` (JVM-style host tests) and `iosSimulatorArm64Test`. Documented for downstream plans.

## Next Plan Readiness
- `DesignTokens.LightColors`/`DarkColors` (36 roles each, including surfaceTint) ready for the Compose `ColorScheme(...)` constructor (02-02) and SwiftUI `ThemeColors` struct (02-03).
- `DesignTokens.typography`/`spacing`/`radius` ready for both adapters.
- `ColorPalette` shared type unblocks branched palette selection on both platforms without compromising the D-16 invariant (Kotlin never receives `isDark` — the UI layer picks the object reference).

---
*Phase: 02-design-token-bridge*
*Completed: 2026-05-18*
