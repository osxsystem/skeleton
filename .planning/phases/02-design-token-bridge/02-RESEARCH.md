# Phase 2: Design Token Bridge - Research

**Researched:** 2026-05-10
**Domain:** KMP design tokens / Compose MaterialTheme adapter / SwiftUI EnvironmentKey adapter / dark mode ownership
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01 (color palette):** `DesignTokens.kt` defines the **full M3 ColorScheme mirror** — all ~30+ color roles as listed in D-01. Compose adapter passes every role to `ColorScheme(...)`. No M3 defaults leak in.
- **D-02 (constants):** Two `object` declarations: `LightColors` and `DarkColors`. Every constant is `Long` with `L` suffix. `commonTest` asserts no color constant is negative.
- **D-03 (palette values):** Intentional Skeleton identity palette — indigo-primary / teal-tertiary / neutral-grey. Planner selects exact hex values.
- **D-04 (TextStyleToken):** `data class TextStyleToken(val size: Float, val weight: Int, val lineHeight: Float, val letterSpacing: Float)` in `commonMain`. No Compose or SwiftUI types.
- **D-05 (type scale):** All 15 M3 roles in `DesignTokens.typography`. Compose adapter maps each to `Typography(displayLarge = ..., ...)`. iOS adapter maps each to `Font.system(size:weight:)`.
- **D-06 (AppTheme struct):** Swift `struct AppTheme` holds `.colors: ThemeColors`, `.typography: ThemeTypography`, `.spacing: ThemeSpacing`, `.radius: ThemeRadius`. Views access via `@Environment(\.appTheme) var theme`.
- **D-07 (injection point):** Single `AppThemeKey: EnvironmentKey`. Injected at `WindowGroup` root in `iosApp.swift`. `@Environment(\.colorScheme)` read there; `.environment(\.appTheme, AppTheme.build(colorScheme == .dark))` applied once.
- **D-08 (Swift color adapter):** Swift adapter uses `Int64` (never `Int32`). Alpha extraction: `let a = UInt8((argb >> 24) & 0xFF)`.
- **D-09 (spacing):** 7 semantic steps: `xxs=2f`, `xs=4f`, `sm=8f`, `md=16f`, `lg=24f`, `xl=32f`, `xxl=48f`. All `Float` in `commonMain`.
- **D-10 (radius):** Semantic names: `none=0f`, `xs=4f`, `sm=8f`, `md=12f`, `lg=16f`, `xl=28f`, `full=9999f`. Compose maps to M3 `Shapes(...)`.
- **D-11 (Compose adapter):** `@Composable fun AppTheme(content: @Composable () -> Unit)` in `:androidApp`. Reads `isSystemInDarkTheme()` internally. `MainActivity.setContent` wraps `AppTheme { Surface { GreetingScreen() } }`.
- **D-12 (no hex in androidApp):** No hex literals in `androidApp` theme code. All values from `DesignTokens`.
- **D-13 (iOS GreetingScreen):** `GreetingScreen.swift` hardcoded `.red` replaced with `theme.colors.error`.
- **D-14 (iOS injection):** `iosApp.swift` `WindowGroup { ContentView() }` updated to add `.environment(\.appTheme, ...)`.
- **D-15 (Pitfall 6 mitigation):** Every color constant ends with `L`; `commonTest` `noColorConstantIsNegative()` runs on JVM and `iosSimulatorArm64`; Swift adapter uses `Int64`.
- **D-16 (Pitfall 7 mitigation):** `DesignTokens` only exports both palettes; Swift `@Environment(\.colorScheme)` is the sole selector; no `isDark: Boolean` ever passed from Swift to Kotlin.
- **File placement:**
  - `DesignTokens.kt` → `:shared-core/src/commonMain/kotlin/dev/viethung/core/theme/DesignTokens.kt`
  - `AppTheme.kt` → `:androidApp/src/main/kotlin/dev/viethung/skeleton/android/theme/AppTheme.kt`
  - Swift adapter → `iosApp/iosApp/Theme/AppTheme.swift`
- **No new dependencies** in `gradle/libs.versions.toml` (tokens are pure data classes/objects).
- **Dark mode:** SwiftUI owns selection always (D-16); Compose reads `isSystemInDarkTheme()` independently on Android.

### Claude's Discretion

- Exact hex values for the Skeleton identity palette — pick an indigo/teal/neutral scheme that looks intentional.
- Whether `DesignTokens` is a Kotlin `object` (singleton) or a set of top-level `const val` declarations — `object` is the cleaner namespace.
- Whether `ThemeColors`, `ThemeTypography`, `ThemeSpacing`, `ThemeRadius` are `struct` or `class` in Swift — `struct` is idiomatic for value types in SwiftUI environment.
- Whether to add a runtime theme toggle to `GreetingScreen` for dark mode verification purposes — not required.

### Deferred Ideas (OUT OF SCOPE)

- Runtime light/dark theme toggle in showcase UI (SHOW-04) — Phase 6.
- Brand refinement / final color values — out of scope for v1.
- Custom font loading — Phase 2 uses system fonts only.
- Dynamic color / Material You — explicit opt-out.

</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| THEME-01 | `DesignTokens` in `:shared-core/commonMain` defines colors (Long ARGB), typography (`TextStyleToken`), spacing, and radius — primitives only, no Compose or SwiftUI types | §Standard Stack, §Pattern 1 (DesignTokens), §Pitfall 6 walkthrough |
| THEME-02 | `LightColors` and `DarkColors` palettes defined; every color is `Long` with `L` suffix; `commonTest` asserts no constant overflowed to negative | §Pattern 2 (LightColors/DarkColors), §Pitfall 6 walkthrough, §Validation Architecture |
| THEME-03 | Compose `AppTheme` adapter maps tokens to `MaterialTheme` (`ColorScheme`, `Typography`, `Shapes`) on Android | §Pattern 3 (Compose adapter), §Code Examples — Compose |
| THEME-04 | SwiftUI `AppTheme` adapter maps tokens to environment values (`Color`, `Font`, spacing modifiers) on iOS | §Pattern 4 (Swift adapter), §Code Examples — Swift |
| THEME-05 | Dark mode follows system setting on both platforms; switching the system theme updates both apps without restart | §Pitfall 7 walkthrough, §Pattern 5 (dark mode ownership), §Validation Architecture |

</phase_requirements>

---

## Summary

Phase 2 is a pure data-plumbing phase. `DesignTokens.kt` is a Kotlin `object` hierarchy in `commonMain` holding `Long` ARGB constants, `TextStyleToken` data-class instances, and `Float` spacing/radius values — nothing that requires a Compose or SwiftUI import. The Android adapter converts these to `MaterialTheme(colorScheme, typography, shapes)` using `Color(0xFF...L)` / `TextStyle(fontSize, lineHeight, letterSpacing, fontWeight)` / `RoundedCornerShape(dp)`. The SwiftUI adapter converts them to `Color(red:green:blue:opacity:)` values wrapped in an `AppTheme` struct injected at `WindowGroup` root via `EnvironmentKey`.

The two locked pitfalls for this phase are mechanical and testable: Pitfall 6 (ARGB Long overflow) is caught by a `commonTest` no-negative assertion on both JVM and `iosSimulatorArm64` targets before any Swift code runs; Pitfall 7 (wrong-side dark-mode selection) is avoided by exporting both palettes from Kotlin and letting `@Environment(\.colorScheme)` in `iosApp.swift` perform the selection. Android reads `isSystemInDarkTheme()` independently — the two platforms never communicate about appearance.

The Material3 1.4.0 `ColorScheme` constructor (mapped by Compose BOM 2026.05.00) has an expanded parameter list beyond the baseline 30 roles. The D-01 list in CONTEXT.md covers the stable required roles; the `Fixed` color family (e.g., `primaryFixed`, `primaryFixedDim`) is available in 1.4 but was added to support fixed-in-light-and-dark tonal palettes and is not required for a basic skeleton identity palette.

**Primary recommendation:** Follow D-01 through D-16 exactly. No library additions. The entire bridge is 4 Kotlin files + 3 Swift files + 1 `commonTest` file.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Design token definition (colors, type, spacing, radius) | KMP commonMain (`shared-core`) | — | Must compile on both targets; primitives-only rule enforces this |
| Dark/light palette selection | iOS (SwiftUI `@Environment`) | Android reads `isSystemInDarkTheme()` independently | Pitfall 7: selection on the Kotlin side introduces a propagation race |
| Color → Compose `Color` conversion | Android (`androidApp` theme/) | — | Compose types do not exist in `commonMain`; KMP compiler enforces boundary |
| Color → SwiftUI `Color` conversion | iOS (`iosApp/Theme/`) | — | SwiftUI types do not exist in `commonMain` |
| Token → `MaterialTheme` wiring | Android (`AppTheme.kt`) | — | `MaterialTheme` is Compose-only |
| Token → SwiftUI environment injection | iOS (`AppTheme.swift` + `iosApp.swift`) | — | `EnvironmentKey` is SwiftUI-only |
| Correctness assertions (no negative colors) | KMP `commonTest` | — | Must run on both JVM and `iosSimulatorArm64` to catch platform-specific overflow |

---

## Standard Stack

### Core (all pre-existing, no new additions)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `androidx.compose.material3` | 1.4.0 (via BOM 2026.05.00) | `ColorScheme`, `Typography`, `Shapes`, `MaterialTheme` | Locked in `libs.versions.toml` |
| `androidx.compose:compose-bom` | 2026.05.00 | Pin all Compose library versions | Locked in `libs.versions.toml` |
| `kotlin.test` | (via `kotlin("test")`) | `commonTest` assertions | Already in `shared-core/build.gradle.kts` commonTest deps |
| `kotest-assertions-core` | 5.9.1 | Fluent assertion DSL in `commonTest` | Already in `shared-core/build.gradle.kts` commonTest deps |
| SwiftUI (system) | iOS 17.0+ | `EnvironmentKey`, `@Environment`, `Color`, `Font` | iOS deployment target locked at 17.0 (01-CONTEXT D-02) |

**No new entries in `gradle/libs.versions.toml` are needed for Phase 2.** All types used in `DesignTokens.kt` are Kotlin primitives (`Long`, `Float`, `Int`, `data class`). All Compose types used in `AppTheme.kt` are already in the BOM.

### Supporting (existing androidApp dependencies already include these)

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `isSystemInDarkTheme()` | (Compose Foundation) | Android dark mode detection | Inside `AppTheme.kt` composable |
| `RoundedCornerShape` | (Compose Foundation) | Radius token → Compose shape | `Shapes(extraSmall = RoundedCornerShape(radius.xs.dp), ...)` |

---

## Architecture Patterns

### System Architecture Diagram

```
  [DesignTokens.kt — commonMain]
        LightColors (Long ARGB consts)
        DarkColors  (Long ARGB consts)
        typography  (TextStyleToken data classes)
        spacing     (Float values)
        radius      (Float values)
            │
            ├─────────────────────────────────────────────────────┐
            │                                                     │
    [AppTheme.kt — androidApp]                      [AppTheme.swift — iosApp]
    isSystemInDarkTheme()                           @Environment(\.colorScheme)
          ↓                                                ↓
    selects LightColors or DarkColors          selects LightColors or DarkColors
          ↓                                                ↓
    Color(0xFF...L)   →  ColorScheme(...)      Color(red:green:blue:opacity:)
    TextStyle(...)    →  Typography(...)       Font.system(size:weight:)
    RoundedCornerShape→  Shapes(...)           CGFloat spacing/radius
          ↓                                                ↓
    MaterialTheme(colorScheme, typography,     AppTheme struct
      shapes, content = content)               injected via .environment(\.appTheme, ...)
          ↓                                         at WindowGroup root
    GreetingScreen reads                       GreetingScreen reads
    MaterialTheme.colorScheme.error,           @Environment(\.appTheme).colors.error
    MaterialTheme.typography.headlineMedium    etc.
```

### Recommended Project Structure

```
shared-core/
└── src/commonMain/kotlin/dev/viethung/core/
    └── theme/
        └── DesignTokens.kt         # object + nested objects/data classes

shared-core/
└── src/commonTest/kotlin/dev/viethung/core/
    └── theme/
        └── DesignTokensTest.kt     # noColorConstantIsNegative()

androidApp/
└── src/main/kotlin/dev/viethung/skeleton/android/
    └── theme/
        └── AppTheme.kt             # @Composable AppTheme(content)

iosApp/iosApp/
└── Theme/
    ├── AppTheme.swift              # struct AppTheme + sub-structs + AppThemeKey
    └── AppThemeExtensions.swift    # (optional) Color(argb:) init extension
```

---

## Pattern 1: DesignTokens.kt — commonMain primitives

**What:** A single `object DesignTokens` in `commonMain` with nested objects/data-class instances for colors, typography, spacing, and radius. No platform imports.

**When to use:** All token definitions live here — this is the single source of truth.

```kotlin
// Source: CONTEXT.md D-01 to D-10, verified against Pitfall 6 prevention
// File: shared-core/src/commonMain/kotlin/dev/viethung/core/theme/DesignTokens.kt

package dev.viethung.core.theme

// TextStyleToken — four primitive fields, no Compose/SwiftUI type
data class TextStyleToken(
    val size: Float,
    val weight: Int,       // e.g., 400 = Regular, 500 = Medium
    val lineHeight: Float,
    val letterSpacing: Float,  // in sp (Compose convention); divide by size for iOS kerning
)

object DesignTokens {

    // ── Color palettes ────────────────────────────────────────────────────
    // CRITICAL: every constant MUST end with L (Long literal).
    // 0xFFXXXXXX without L is Int on Kotlin/JVM and overflows to negative for
    // any color where the high byte (alpha) sets the sign bit. See Pitfall 6.

    object LightColors {
        const val primary: Long              = 0xFF3F51B5L  // Indigo 500
        const val onPrimary: Long            = 0xFFFFFFFFL
        const val primaryContainer: Long     = 0xFFE8EAF6L  // Indigo 50
        const val onPrimaryContainer: Long   = 0xFF1A237EL  // Indigo 900
        const val inversePrimary: Long       = 0xFF9FA8DAL  // Indigo 200

        const val secondary: Long            = 0xFF607D8BL  // Blue Grey 500
        const val onSecondary: Long          = 0xFFFFFFFFL
        const val secondaryContainer: Long   = 0xFFECEFF1L  // Blue Grey 50
        const val onSecondaryContainer: Long = 0xFF263238L  // Blue Grey 900

        const val tertiary: Long             = 0xFF009688L  // Teal 500
        const val onTertiary: Long           = 0xFFFFFFFFL
        const val tertiaryContainer: Long    = 0xFFE0F2F1L  // Teal 50
        const val onTertiaryContainer: Long  = 0xFF004D40L  // Teal 900

        const val error: Long                = 0xFFB00020L
        const val onError: Long              = 0xFFFFFFFFL
        const val errorContainer: Long       = 0xFFFFDAD6L
        const val onErrorContainer: Long     = 0xFF410002L

        const val background: Long           = 0xFFFAFAFAL
        const val onBackground: Long         = 0xFF1C1B1FL
        const val surface: Long              = 0xFFFAFAFAL
        const val onSurface: Long            = 0xFF1C1B1FL
        const val surfaceVariant: Long       = 0xFFE7E0ECL
        const val onSurfaceVariant: Long     = 0xFF49454FL
        const val surfaceTint: Long          = 0xFF3F51B5L  // = primary
        const val inverseSurface: Long       = 0xFF313033L
        const val inverseOnSurface: Long     = 0xFFF4EFF4L
        const val outline: Long              = 0xFF79747EL
        const val outlineVariant: Long       = 0xFFCAC4D0L
        const val scrim: Long                = 0xFF000000L

        // Surface container family (added M3 1.2, stable 1.3)
        const val surfaceDim: Long              = 0xFFDDD8DEL
        const val surfaceBright: Long           = 0xFFFDF8FDL
        const val surfaceContainerLowest: Long  = 0xFFFFFFFFL
        const val surfaceContainerLow: Long     = 0xFFF7F2F7L
        const val surfaceContainer: Long        = 0xFFF3EDF7L
        const val surfaceContainerHigh: Long    = 0xFFECE6F0L
        const val surfaceContainerHighest: Long = 0xFFE6E0E9L
    }

    object DarkColors {
        const val primary: Long              = 0xFF9FA8DAL  // Indigo 200
        const val onPrimary: Long            = 0xFF1A237EL  // Indigo 900
        const val primaryContainer: Long     = 0xFF283593L  // Indigo 800
        const val onPrimaryContainer: Long   = 0xFFE8EAF6L  // Indigo 50
        const val inversePrimary: Long       = 0xFF3F51B5L  // Indigo 500

        const val secondary: Long            = 0xFFB0BEC5L  // Blue Grey 200
        const val onSecondary: Long          = 0xFF263238L  // Blue Grey 900
        const val secondaryContainer: Long   = 0xFF37474FL  // Blue Grey 800
        const val onSecondaryContainer: Long = 0xFFECEFF1L  // Blue Grey 50

        const val tertiary: Long             = 0xFF80CBC4L  // Teal 200
        const val onTertiary: Long           = 0xFF004D40L  // Teal 900
        const val tertiaryContainer: Long    = 0xFF00695CL  // Teal 800
        const val onTertiaryContainer: Long  = 0xFFE0F2F1L  // Teal 50

        const val error: Long                = 0xFFFFB4ABL
        const val onError: Long              = 0xFF690005L
        const val errorContainer: Long       = 0xFF93000AL
        const val onErrorContainer: Long     = 0xFFFFDAD6L

        const val background: Long           = 0xFF1C1B1FL
        const val onBackground: Long         = 0xFFE6E1E5L
        const val surface: Long              = 0xFF1C1B1FL
        const val onSurface: Long            = 0xFFE6E1E5L
        const val surfaceVariant: Long       = 0xFF49454FL
        const val onSurfaceVariant: Long     = 0xFFCAC4D0L
        const val surfaceTint: Long          = 0xFF9FA8DAL  // = primary
        const val inverseSurface: Long       = 0xFFE6E1E5L
        const val inverseOnSurface: Long     = 0xFF313033L
        const val outline: Long              = 0xFF938F99L
        const val outlineVariant: Long       = 0xFF49454FL
        const val scrim: Long                = 0xFF000000L

        const val surfaceDim: Long              = 0xFF141218L
        const val surfaceBright: Long           = 0xFF3B383EL
        const val surfaceContainerLowest: Long  = 0xFF0F0D13L
        const val surfaceContainerLow: Long     = 0xFF1D1B20L
        const val surfaceContainer: Long        = 0xFF211F26L
        const val surfaceContainerHigh: Long    = 0xFF2B2930L
        const val surfaceContainerHighest: Long = 0xFF36343BL
    }

    // ── Typography ────────────────────────────────────────────────────────
    // letterSpacing is in sp (matching M3 spec). Compose: .sp directly.
    // SwiftUI: token.letterSpacing / token.size gives the kerning ratio,
    // or pass as-is to Font.tracking() / UIFont.kern.
    // M3 default values from https://m3.material.io/styles/typography/type-scale-tokens
    object Typography {
        val displayLarge   = TextStyleToken(size = 57f, weight = 400, lineHeight = 64f, letterSpacing = -0.25f)
        val displayMedium  = TextStyleToken(size = 45f, weight = 400, lineHeight = 52f, letterSpacing = 0f)
        val displaySmall   = TextStyleToken(size = 36f, weight = 400, lineHeight = 44f, letterSpacing = 0f)
        val headlineLarge  = TextStyleToken(size = 32f, weight = 400, lineHeight = 40f, letterSpacing = 0f)
        val headlineMedium = TextStyleToken(size = 28f, weight = 400, lineHeight = 36f, letterSpacing = 0f)
        val headlineSmall  = TextStyleToken(size = 24f, weight = 400, lineHeight = 32f, letterSpacing = 0f)
        val titleLarge     = TextStyleToken(size = 22f, weight = 400, lineHeight = 28f, letterSpacing = 0f)
        val titleMedium    = TextStyleToken(size = 16f, weight = 500, lineHeight = 24f, letterSpacing = 0.15f)
        val titleSmall     = TextStyleToken(size = 14f, weight = 500, lineHeight = 20f, letterSpacing = 0.1f)
        val bodyLarge      = TextStyleToken(size = 16f, weight = 400, lineHeight = 24f, letterSpacing = 0.5f)
        val bodyMedium     = TextStyleToken(size = 14f, weight = 400, lineHeight = 20f, letterSpacing = 0.25f)
        val bodySmall      = TextStyleToken(size = 12f, weight = 400, lineHeight = 16f, letterSpacing = 0.4f)
        val labelLarge     = TextStyleToken(size = 14f, weight = 500, lineHeight = 20f, letterSpacing = 0.1f)
        val labelMedium    = TextStyleToken(size = 12f, weight = 500, lineHeight = 16f, letterSpacing = 0.5f)
        val labelSmall     = TextStyleToken(size = 11f, weight = 500, lineHeight = 16f, letterSpacing = 0.5f)
    }

    // ── Spacing ───────────────────────────────────────────────────────────
    object Spacing {
        const val xxs: Float = 2f
        const val xs:  Float = 4f
        const val sm:  Float = 8f
        const val md:  Float = 16f
        const val lg:  Float = 24f
        const val xl:  Float = 32f
        const val xxl: Float = 48f
    }

    // ── Radius ────────────────────────────────────────────────────────────
    object Radius {
        const val none: Float = 0f
        const val xs:   Float = 4f
        const val sm:   Float = 8f
        const val md:   Float = 12f
        const val lg:   Float = 16f
        const val xl:   Float = 28f
        const val full: Float = 9999f
    }
}
```

---

## Pattern 2: commonTest — noColorConstantIsNegative

**What:** A `@Test` in `shared-core/src/commonTest` that iterates over every named color in both palettes using an explicit list and asserts each is `> 0L`. Uses `kotlin.test.Test` (never `org.junit.Test`) so it runs on JVM and `iosSimulatorArm64`.

**When to use:** Required for THEME-02. Must be in `:shared-core` `commonTest` so it exercises the same module that defines the tokens.

```kotlin
// Source: CONTEXT.md D-02, D-15; Pitfall 6 prevention
// File: shared-core/src/commonTest/kotlin/dev/viethung/core/theme/DesignTokensTest.kt
package dev.viethung.core.theme

import kotlin.test.Test
import kotlin.test.assertTrue

class DesignTokensTest {

    @Test
    fun noColorConstantIsNegative() {
        // Reflection is not reliable on all KMP targets — use an explicit list.
        // This list must stay in sync with DesignTokens.kt when adding constants.
        val lightColors: List<Long> = listOf(
            DesignTokens.LightColors.primary,
            DesignTokens.LightColors.onPrimary,
            DesignTokens.LightColors.primaryContainer,
            DesignTokens.LightColors.onPrimaryContainer,
            DesignTokens.LightColors.inversePrimary,
            DesignTokens.LightColors.secondary,
            DesignTokens.LightColors.onSecondary,
            DesignTokens.LightColors.secondaryContainer,
            DesignTokens.LightColors.onSecondaryContainer,
            DesignTokens.LightColors.tertiary,
            DesignTokens.LightColors.onTertiary,
            DesignTokens.LightColors.tertiaryContainer,
            DesignTokens.LightColors.onTertiaryContainer,
            DesignTokens.LightColors.error,
            DesignTokens.LightColors.onError,
            DesignTokens.LightColors.errorContainer,
            DesignTokens.LightColors.onErrorContainer,
            DesignTokens.LightColors.background,
            DesignTokens.LightColors.onBackground,
            DesignTokens.LightColors.surface,
            DesignTokens.LightColors.onSurface,
            DesignTokens.LightColors.surfaceVariant,
            DesignTokens.LightColors.onSurfaceVariant,
            DesignTokens.LightColors.surfaceTint,
            DesignTokens.LightColors.inverseSurface,
            DesignTokens.LightColors.inverseOnSurface,
            DesignTokens.LightColors.outline,
            DesignTokens.LightColors.outlineVariant,
            DesignTokens.LightColors.scrim,
            DesignTokens.LightColors.surfaceDim,
            DesignTokens.LightColors.surfaceBright,
            DesignTokens.LightColors.surfaceContainerLowest,
            DesignTokens.LightColors.surfaceContainerLow,
            DesignTokens.LightColors.surfaceContainer,
            DesignTokens.LightColors.surfaceContainerHigh,
            DesignTokens.LightColors.surfaceContainerHighest,
        )

        val darkColors: List<Long> = listOf(
            DesignTokens.DarkColors.primary,
            DesignTokens.DarkColors.onPrimary,
            DesignTokens.DarkColors.primaryContainer,
            DesignTokens.DarkColors.onPrimaryContainer,
            DesignTokens.DarkColors.inversePrimary,
            DesignTokens.DarkColors.secondary,
            DesignTokens.DarkColors.onSecondary,
            DesignTokens.DarkColors.secondaryContainer,
            DesignTokens.DarkColors.onSecondaryContainer,
            DesignTokens.DarkColors.tertiary,
            DesignTokens.DarkColors.onTertiary,
            DesignTokens.DarkColors.tertiaryContainer,
            DesignTokens.DarkColors.onTertiaryContainer,
            DesignTokens.DarkColors.error,
            DesignTokens.DarkColors.onError,
            DesignTokens.DarkColors.errorContainer,
            DesignTokens.DarkColors.onErrorContainer,
            DesignTokens.DarkColors.background,
            DesignTokens.DarkColors.onBackground,
            DesignTokens.DarkColors.surface,
            DesignTokens.DarkColors.onSurface,
            DesignTokens.DarkColors.surfaceVariant,
            DesignTokens.DarkColors.onSurfaceVariant,
            DesignTokens.DarkColors.surfaceTint,
            DesignTokens.DarkColors.inverseSurface,
            DesignTokens.DarkColors.inverseOnSurface,
            DesignTokens.DarkColors.outline,
            DesignTokens.DarkColors.outlineVariant,
            DesignTokens.DarkColors.scrim,
            DesignTokens.DarkColors.surfaceDim,
            DesignTokens.DarkColors.surfaceBright,
            DesignTokens.DarkColors.surfaceContainerLowest,
            DesignTokens.DarkColors.surfaceContainerLow,
            DesignTokens.DarkColors.surfaceContainer,
            DesignTokens.DarkColors.surfaceContainerHigh,
            DesignTokens.DarkColors.surfaceContainerHighest,
        )

        (lightColors + darkColors).forEachIndexed { i, color ->
            assertTrue(color > 0L,
                "Color at index $i is negative ($color). " +
                "Likely missing L suffix on hex literal — see Pitfall 6."
            )
        }
    }
}
```

---

## Pattern 3: Compose AppTheme adapter (androidApp)

**What:** A `@Composable fun AppTheme(...)` that reads `isSystemInDarkTheme()`, selects the correct `Long`-based palette, converts each role to `Color(0xFF...L)`, builds `ColorScheme(...)`, `Typography(...)`, `Shapes(...)`, and delegates to `MaterialTheme(...)`.

**Key API facts verified:**
- `ColorScheme` constructor (Material3 1.3+/1.4) takes the 29 stable roles listed in D-01 plus the 7 `surfaceContainer*` / `surfaceDim` / `surfaceBright` / `surfaceTint` roles. [VERIFIED: composables.com/docs Material3 1.4.0 class reference]
- `Typography` constructor takes exactly 15 `TextStyle` parameters (displayLarge → labelSmall). The 30-param emphasized-variant constructor exists but is opt-in and not required for a skeleton. [VERIFIED: Context7 Material3 Typography docs]
- `Shapes` stable constructor has 5 parameters: `extraSmall`, `small`, `medium`, `large`, `extraLarge`. `full` and `none` are not parameters — they are `CircleShape` / `RectangleShape` Compose constants. [VERIFIED: WebSearch composables.com Shapes docs]
- `isSystemInDarkTheme()` is in `androidx.compose.foundation` (part of BOM). [VERIFIED: Context7 Material3 docs]

```kotlin
// Source: CONTEXT.md D-11, D-12; Material3 1.4.0 ColorScheme/Typography/Shapes APIs
// File: androidApp/src/main/kotlin/dev/viethung/skeleton/android/theme/AppTheme.kt

package dev.viethung.skeleton.android.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.ColorScheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Shapes
import androidx.compose.material3.TextStyle
import androidx.compose.material3.Typography
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import dev.viethung.core.theme.DesignTokens
import dev.viethung.core.theme.TextStyleToken

@Composable
fun AppTheme(content: @Composable () -> Unit) {
    val isDark = isSystemInDarkTheme()
    val palette = if (isDark) DesignTokens.DarkColors else DesignTokens.LightColors

    val colorScheme = ColorScheme(
        primary                = Color(palette.primary),
        onPrimary              = Color(palette.onPrimary),
        primaryContainer       = Color(palette.primaryContainer),
        onPrimaryContainer     = Color(palette.onPrimaryContainer),
        inversePrimary         = Color(palette.inversePrimary),
        secondary              = Color(palette.secondary),
        onSecondary            = Color(palette.onSecondary),
        secondaryContainer     = Color(palette.secondaryContainer),
        onSecondaryContainer   = Color(palette.onSecondaryContainer),
        tertiary               = Color(palette.tertiary),
        onTertiary             = Color(palette.onTertiary),
        tertiaryContainer      = Color(palette.tertiaryContainer),
        onTertiaryContainer    = Color(palette.onTertiaryContainer),
        error                  = Color(palette.error),
        onError                = Color(palette.onError),
        errorContainer         = Color(palette.errorContainer),
        onErrorContainer       = Color(palette.onErrorContainer),
        background             = Color(palette.background),
        onBackground           = Color(palette.onBackground),
        surface                = Color(palette.surface),
        onSurface              = Color(palette.onSurface),
        surfaceVariant         = Color(palette.surfaceVariant),
        onSurfaceVariant       = Color(palette.onSurfaceVariant),
        surfaceTint            = Color(palette.surfaceTint),
        inverseSurface         = Color(palette.inverseSurface),
        inverseOnSurface       = Color(palette.inverseOnSurface),
        outline                = Color(palette.outline),
        outlineVariant         = Color(palette.outlineVariant),
        scrim                  = Color(palette.scrim),
        surfaceBright          = Color(palette.surfaceBright),
        surfaceDim             = Color(palette.surfaceDim),
        surfaceContainer       = Color(palette.surfaceContainer),
        surfaceContainerHigh   = Color(palette.surfaceContainerHigh),
        surfaceContainerHighest = Color(palette.surfaceContainerHighest),
        surfaceContainerLow    = Color(palette.surfaceContainerLow),
        surfaceContainerLowest = Color(palette.surfaceContainerLowest),
    )

    val t = DesignTokens.Typography
    val typography = Typography(
        displayLarge   = t.displayLarge.toTextStyle(),
        displayMedium  = t.displayMedium.toTextStyle(),
        displaySmall   = t.displaySmall.toTextStyle(),
        headlineLarge  = t.headlineLarge.toTextStyle(),
        headlineMedium = t.headlineMedium.toTextStyle(),
        headlineSmall  = t.headlineSmall.toTextStyle(),
        titleLarge     = t.titleLarge.toTextStyle(),
        titleMedium    = t.titleMedium.toTextStyle(),
        titleSmall     = t.titleSmall.toTextStyle(),
        bodyLarge      = t.bodyLarge.toTextStyle(),
        bodyMedium     = t.bodyMedium.toTextStyle(),
        bodySmall      = t.bodySmall.toTextStyle(),
        labelLarge     = t.labelLarge.toTextStyle(),
        labelMedium    = t.labelMedium.toTextStyle(),
        labelSmall     = t.labelSmall.toTextStyle(),
    )

    val r = DesignTokens.Radius
    val shapes = Shapes(
        extraSmall = RoundedCornerShape(r.xs.dp),
        small      = RoundedCornerShape(r.sm.dp),
        medium     = RoundedCornerShape(r.md.dp),
        large      = RoundedCornerShape(r.lg.dp),
        extraLarge = RoundedCornerShape(r.xl.dp),
    )

    MaterialTheme(
        colorScheme = colorScheme,
        typography  = typography,
        shapes      = shapes,
        content     = content,
    )
}

private fun TextStyleToken.toTextStyle(): TextStyle = TextStyle(
    fontSize      = size.sp,
    fontWeight    = FontWeight(weight),
    lineHeight    = lineHeight.sp,
    letterSpacing = letterSpacing.sp,
)
```

**MainActivity.kt change (surgical — one line swap):**

```kotlin
// Before (Phase 1):
MaterialTheme {
    Surface {
        GreetingScreen()
    }
}

// After (Phase 2) — import swapped from MaterialTheme to AppTheme:
AppTheme {
    Surface {
        GreetingScreen()
    }
}
```

---

## Pattern 4: SwiftUI AppTheme adapter (iosApp)

**What:** A Swift `struct AppTheme` holding typed sub-structs (`ThemeColors`, `ThemeTypography`, `ThemeSpacing`, `ThemeRadius`), with a `static func build(isDark: Bool) -> AppTheme` factory. An `AppThemeKey: EnvironmentKey` injects it at `WindowGroup` root. Views read `@Environment(\.appTheme) var theme`.

**Key API facts verified:**
- `EnvironmentKey` protocol requires one property: `static var defaultValue: Value`. [VERIFIED: Context7 SwiftUI EnvironmentKey docs]
- `EnvironmentValues` extension pattern: computed property `get { self[AppThemeKey.self] } / set { ... }`. [VERIFIED: Context7 SwiftUI EnvironmentValues docs]
- `Color(red:green:blue:opacity:)` takes `Double` in `[0.0, 1.0]`. The default `colorSpace` is `.sRGB`. [VERIFIED: Context7 SwiftUI Color init docs]
- Byte extraction from ARGB `Int64` must use `Int64` (not `Int32`) — see Pitfall 6 walkthrough below. [VERIFIED: CONTEXT.md D-08]

```swift
// Source: CONTEXT.md D-06, D-07, D-08; Apple SwiftUI EnvironmentKey docs
// File: iosApp/iosApp/Theme/AppTheme.swift

import SwiftUI
import SkeletonKit

// ── Color conversion helper ────────────────────────────────────────────────
// CRITICAL: argb must be Int64 (not Int32). On KMP/Native, Long bridges to Int64.
// Using Int32 here re-introduces the sign-bit overflow that DesignTokens.kt avoids.
extension Color {
    init(argb: Int64) {
        let a = Double(UInt8((argb >> 24) & 0xFF)) / 255.0
        let r = Double(UInt8((argb >> 16) & 0xFF)) / 255.0
        let g = Double(UInt8((argb >> 8)  & 0xFF)) / 255.0
        let b = Double(UInt8( argb        & 0xFF)) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

// ── Sub-structs (value types — idiomatic for SwiftUI environment) ──────────
struct ThemeColors {
    let primary: Color;            let onPrimary: Color
    let primaryContainer: Color;   let onPrimaryContainer: Color
    let inversePrimary: Color
    let secondary: Color;          let onSecondary: Color
    let secondaryContainer: Color; let onSecondaryContainer: Color
    let tertiary: Color;           let onTertiary: Color
    let tertiaryContainer: Color;  let onTertiaryContainer: Color
    let error: Color;              let onError: Color
    let errorContainer: Color;     let onErrorContainer: Color
    let background: Color;         let onBackground: Color
    let surface: Color;            let onSurface: Color
    let surfaceVariant: Color;     let onSurfaceVariant: Color
    let surfaceTint: Color
    let inverseSurface: Color;     let inverseOnSurface: Color
    let outline: Color;            let outlineVariant: Color
    let scrim: Color
    let surfaceDim: Color;         let surfaceBright: Color
    let surfaceContainerLowest: Color; let surfaceContainerLow: Color
    let surfaceContainer: Color;       let surfaceContainerHigh: Color
    let surfaceContainerHighest: Color
}

struct ThemeTypography {
    let displayLarge: Font;   let displayMedium: Font;  let displaySmall: Font
    let headlineLarge: Font;  let headlineMedium: Font; let headlineSmall: Font
    let titleLarge: Font;     let titleMedium: Font;    let titleSmall: Font
    let bodyLarge: Font;      let bodyMedium: Font;     let bodySmall: Font
    let labelLarge: Font;     let labelMedium: Font;    let labelSmall: Font
}

struct ThemeSpacing {
    let xxs: CGFloat; let xs: CGFloat; let sm: CGFloat; let md: CGFloat
    let lg: CGFloat;  let xl: CGFloat; let xxl: CGFloat
}

struct ThemeRadius {
    let none: CGFloat; let xs: CGFloat; let sm: CGFloat; let md: CGFloat
    let lg: CGFloat;   let xl: CGFloat; let full: CGFloat
}

// ── AppTheme ───────────────────────────────────────────────────────────────
struct AppTheme {
    let colors: ThemeColors
    let typography: ThemeTypography
    let spacing: ThemeSpacing
    let radius: ThemeRadius

    static func build(isDark: Bool) -> AppTheme {
        let p = isDark
            ? DesignTokens.DarkColors.shared
            : DesignTokens.LightColors.shared

        let colors = ThemeColors(
            primary:               Color(argb: p.primary),
            onPrimary:             Color(argb: p.onPrimary),
            primaryContainer:      Color(argb: p.primaryContainer),
            onPrimaryContainer:    Color(argb: p.onPrimaryContainer),
            inversePrimary:        Color(argb: p.inversePrimary),
            secondary:             Color(argb: p.secondary),
            onSecondary:           Color(argb: p.onSecondary),
            secondaryContainer:    Color(argb: p.secondaryContainer),
            onSecondaryContainer:  Color(argb: p.onSecondaryContainer),
            tertiary:              Color(argb: p.tertiary),
            onTertiary:            Color(argb: p.onTertiary),
            tertiaryContainer:     Color(argb: p.tertiaryContainer),
            onTertiaryContainer:   Color(argb: p.onTertiaryContainer),
            error:                 Color(argb: p.error),
            onError:               Color(argb: p.onError),
            errorContainer:        Color(argb: p.errorContainer),
            onErrorContainer:      Color(argb: p.onErrorContainer),
            background:            Color(argb: p.background),
            onBackground:          Color(argb: p.onBackground),
            surface:               Color(argb: p.surface),
            onSurface:             Color(argb: p.onSurface),
            surfaceVariant:        Color(argb: p.surfaceVariant),
            onSurfaceVariant:      Color(argb: p.onSurfaceVariant),
            surfaceTint:           Color(argb: p.surfaceTint),
            inverseSurface:        Color(argb: p.inverseSurface),
            inverseOnSurface:      Color(argb: p.inverseOnSurface),
            outline:               Color(argb: p.outline),
            outlineVariant:        Color(argb: p.outlineVariant),
            scrim:                 Color(argb: p.scrim),
            surfaceDim:            Color(argb: p.surfaceDim),
            surfaceBright:         Color(argb: p.surfaceBright),
            surfaceContainerLowest:  Color(argb: p.surfaceContainerLowest),
            surfaceContainerLow:     Color(argb: p.surfaceContainerLow),
            surfaceContainer:        Color(argb: p.surfaceContainer),
            surfaceContainerHigh:    Color(argb: p.surfaceContainerHigh),
            surfaceContainerHighest: Color(argb: p.surfaceContainerHighest)
        )

        let t = DesignTokens.Typography.shared
        let typography = ThemeTypography(
            displayLarge:   t.displayLarge.toFont(),
            displayMedium:  t.displayMedium.toFont(),
            displaySmall:   t.displaySmall.toFont(),
            headlineLarge:  t.headlineLarge.toFont(),
            headlineMedium: t.headlineMedium.toFont(),
            headlineSmall:  t.headlineSmall.toFont(),
            titleLarge:     t.titleLarge.toFont(),
            titleMedium:    t.titleMedium.toFont(),
            titleSmall:     t.titleSmall.toFont(),
            bodyLarge:      t.bodyLarge.toFont(),
            bodyMedium:     t.bodyMedium.toFont(),
            bodySmall:      t.bodySmall.toFont(),
            labelLarge:     t.labelLarge.toFont(),
            labelMedium:    t.labelMedium.toFont(),
            labelSmall:     t.labelSmall.toFont()
        )

        let s = DesignTokens.Spacing.shared
        let spacing = ThemeSpacing(
            xxs: CGFloat(s.xxs), xs: CGFloat(s.xs), sm: CGFloat(s.sm),
            md: CGFloat(s.md),   lg: CGFloat(s.lg), xl: CGFloat(s.xl),
            xxl: CGFloat(s.xxl)
        )

        let rad = DesignTokens.Radius.shared
        let radius = ThemeRadius(
            none: CGFloat(rad.none), xs: CGFloat(rad.xs), sm: CGFloat(rad.sm),
            md: CGFloat(rad.md),     lg: CGFloat(rad.lg), xl: CGFloat(rad.xl),
            full: CGFloat(rad.full)
        )

        return AppTheme(colors: colors, typography: typography,
                        spacing: spacing, radius: radius)
    }
}

// ── Font helper ────────────────────────────────────────────────────────────
// TextStyleToken.weight: 400 = regular, 500 = medium, 600 = semibold, 700 = bold
private extension TextStyleToken {
    func toFont() -> Font {
        let swiftWeight: Font.Weight = {
            switch self.weight {
            case 300: return .light
            case 400: return .regular
            case 500: return .medium
            case 600: return .semibold
            case 700: return .bold
            default:  return .regular
            }
        }()
        return .system(size: CGFloat(self.size), weight: swiftWeight)
    }
}

// ── EnvironmentKey + EnvironmentValues extension ───────────────────────────
private struct AppThemeKey: EnvironmentKey {
    static let defaultValue: AppTheme = AppTheme.build(isDark: false)
}

extension EnvironmentValues {
    var appTheme: AppTheme {
        get { self[AppThemeKey.self] }
        set { self[AppThemeKey.self] = newValue }
    }
}
```

**iosApp.swift update (surgical):**

```swift
// Source: CONTEXT.md D-07, D-14
// File: iosApp/iosApp/iosApp.swift

import SwiftUI

@main
struct iosApp: App {
    init() {
        AppKoinBridge.start()
    }

    @Environment(\.colorScheme) private var colorScheme

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        // D-07: inject once at WindowGroup root; all descendant views inherit
        // D-16: Swift owns dark/light selection — colorScheme drives it, not Kotlin
        .environment(\.appTheme, AppTheme.build(isDark: colorScheme == .dark))
    }
}
```

**GreetingScreen.swift update (surgical — one property + one line):**

```swift
// Source: CONTEXT.md D-13; existing file: iosApp/iosApp/Greeting/GreetingScreen.swift

struct GreetingScreen: View {
    @StateObject private var owner = IosViewModelStoreOwner()
    @State private var uiState: GreetingViewModelUiState = .loading
    @Environment(\.appTheme) private var theme   // ADD THIS

    var body: some View {
        // ...
        case .error(let e):
            Text("Error: \(e.message)")
                .foregroundColor(theme.colors.error)  // was: .foregroundColor(.red)
        // ...
    }
}
```

---

## Pattern 5: Dark mode ownership (Pitfall 7 — correct side of bridge)

**What:** The correct ownership model ensures SwiftUI re-renders synchronously on appearance change without a round-trip through Kotlin.

**How it works on iOS:** `@Environment(\.colorScheme)` in `iosApp.swift` is a system-provided environment value that SwiftUI updates automatically and immediately when the user changes system appearance. Re-rendering `body` (which recalculates `.environment(\.appTheme, AppTheme.build(isDark: colorScheme == .dark))`) propagates the new `AppTheme` to all descendant views without restart, because SwiftUI's environment propagation is synchronous within the render cycle.

**How it works on Android:** `isSystemInDarkTheme()` in `AppTheme.kt` is a Compose `@Composable` function that reads from the current `LocalConfiguration`. Compose triggers recomposition of `AppTheme { }` and all its descendants when system appearance changes, without restart.

**Why Kotlin must NOT own the selection:** If a `isDark: Boolean` parameter were passed from `iosApp.swift` to a Kotlin VM and then back to Swift, the selection would transit the async SKIE bridge, introducing at minimum one frame of lag. On rapid appearance toggling this produces a flash of the wrong palette. The correct model keeps selection on each platform's native appearance detection.

---

## Pitfall 6 Walkthrough: ARGB Long Overflow

**Failure mode:**

```kotlin
// WRONG — 0xFFFF0000 is 4,278,190,080 which exceeds Int.MAX_VALUE (2,147,483,647)
// Kotlin infers this as Int on JVM targets, wraps to -16,776,448 (negative!)
const val primary = 0xFF3F51B5   // <-- missing L suffix

// On Kotlin/Native (iosSimulatorArm64), the platform's Int is also 32-bit signed.
// The overflow happens identically.
```

**What the Swift side sees:**

When a negative `Long` bridges to Swift as `Int64`, the value is legitimately negative. The byte-extraction then produces:

```swift
let argb: Int64 = -12619595  // (0xFF3F51B5 misinterpreted as Int32 = -12619595)
let a = UInt8((argb >> 24) & 0xFF)  // = UInt8(0xFF & 0xFF) BUT argb is negative
// With Int32, the sign extension corrupts the upper bits before masking.
// With Int64, the value would have been positive from the start (never happens if L suffix used).
```

**Correct form:**

```kotlin
const val primary: Long = 0xFF3F51B5L   // L suffix forces Long on all KMP targets
// Value: 4,282,347,445 — fits in Long.MAX_VALUE (9,223,372,036,854,775,807) — positive
```

**The assertion that catches it (see Pattern 2 above):**

```kotlin
assertTrue(color > 0L, "Color at index $i is negative...")
// A missing L suffix will fail this on BOTH jvmTest and iosSimulatorArm64Test
```

**Run command:**
```bash
./gradlew :shared-core:allTests
# Runs jvm + iosSimulatorArm64 targets; both must pass
```

---

## Pitfall 7 Walkthrough: Dark Mode on the Wrong Side of the Bridge

**Failure mode — if Kotlin owned selection:**

```kotlin
// WRONG — Kotlin ViewModel holds isDark
class ThemeViewModel : ViewModel() {
    private val _isDark = MutableStateFlow(false)
    val isDark: StateFlow<Boolean> = _isDark.asStateFlow()
}
```

```swift
// WRONG — Swift passes isDark flag to Kotlin then reads it back
vm.setDark(colorScheme == .dark)  // async; ViewModel updates on next coroutine frame
for await isDark in vm.isDark {   // one SKIE frame lag
    theme = AppTheme.build(isDark: isDark)
}
```

**Result:** On rapid system appearance toggle (10 toggles in iOS Simulator), the UI shows the wrong palette for ~1 frame per toggle because the selection travels through the async SKIE bridge before re-rendering.

**Correct form — Swift selects, no round-trip:**

```swift
// iosApp.swift — @Environment(\.colorScheme) is updated synchronously by SwiftUI
@Environment(\.colorScheme) private var colorScheme

var body: some Scene {
    WindowGroup { ContentView() }
    .environment(\.appTheme, AppTheme.build(isDark: colorScheme == .dark))
    // When colorScheme changes, SwiftUI recomputes body, AppTheme.build runs
    // synchronously, and the new theme propagates to all descendants before
    // the next frame is drawn. Zero lag.
}
```

**Detection test:** Switch system appearance rapidly 10 times in iOS Simulator via Settings → Developer → Dark Appearance (or `xcrun simctl ui booted appearance dark/light`). Observe the app — any flash of wrong palette means Kotlin owns the selection.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| ARGB Long → Compose Color | Custom bit manipulation | `Color(longValue)` constructor — Compose `Color` accepts `Long` directly | The Compose `Color(Long)` constructor already extracts ARGB; no bit manipulation needed on the Kotlin side |
| M3 ColorScheme defaults | Partial `ColorScheme` with missing roles | Explicit all-roles `ColorScheme(...)` constructor | Missing roles fall back to M3 defaults which may not match the Skeleton palette |
| Font weight mapping | Custom weight class | `FontWeight(int)` in Compose; `Font.Weight` switch in Swift | Both platforms have direct APIs for integer weights |
| Dark mode detection | Custom `ColorScheme`-detection logic in Kotlin | `isSystemInDarkTheme()` (Compose) / `@Environment(\.colorScheme)` (SwiftUI) | Platform-native; automatically handles edge cases (forced light/dark per view hierarchy, accessibility settings) |

---

## Common Pitfalls

### Pitfall A: `Color(Long)` vs `Color(Int)` on Android

**What goes wrong:** Calling `Color(palette.primary.toInt())` on the Android side looks like a safe conversion but truncates the value for high-alpha colors — exactly Pitfall 6 re-applied.

**How to avoid:** Use `Color(palette.primary)` directly. The `Color(Long)` constructor exists and accepts the ARGB Long. Never call `.toInt()` on a color `Long`.

**Warning signs:** Colors with `0xFF` alpha that appear transparent on Android, or a compile warning about integer overflow.

### Pitfall B: `DesignTokens.LightColors.shared` access pattern in Swift

**What goes wrong:** Kotlin `object` declarations compile to singletons. On the Swift side, a Kotlin `object LightColors` is accessed as `LightColors.shared` (SKIE wraps Kotlin objects as Swift singletons). Using `LightColors()` will not compile.

**How to avoid:** In `AppTheme.swift`, access palette constants via `DesignTokens.LightColors.shared.primary` (the `.shared` accessor pattern for Kotlin objects bridged through SKIE/KMP).

**Warning signs:** Compiler error "cannot call value of non-function type" or "type has no member '()' initializer."

### Pitfall C: Missing `surfaceContainer*` roles in `ColorScheme` constructor

**What goes wrong:** Developers familiar with Material3 pre-1.2 may omit the 7 `surfaceContainer*` / `surfaceDim` / `surfaceBright` family roles because they are less well-known. The `ColorScheme` constructor with only 29 parameters without these roles is deprecated in M3 1.4.

**How to avoid:** The `DesignTokens.kt` example above includes all 36 roles. The `ColorScheme(...)` in `AppTheme.kt` maps all 36. Count parameters before compiling.

**Warning signs:** Deprecation warnings in the Compose `ColorScheme` constructor call.

### Pitfall D: `letterSpacing` semantic mismatch between Compose and SwiftUI

**What goes wrong:** `TextStyleToken.letterSpacing` stores the M3 spec value in `sp` (e.g., `0.15f` for titleMedium). Compose's `TextStyle(letterSpacing = 0.15.sp)` applies it correctly. SwiftUI's `Font.tracking(_:)` accepts a value in points, not a fraction — passing `0.15` pt is nearly invisible. For iOS, the correct conversion is: `letterSpacingPt = token.letterSpacing / token.size * systemFontSize` (approximately), or accept a slight visual difference and use `0` for most text styles.

**How to avoid:** The `TextStyleToken.toFont()` helper in Pattern 4 above uses `Font.system(size:weight:)` without applying letter spacing, which is acceptable for a skeleton identity palette. Per-role letter spacing can be added via `.tracking()` modifier at the call site if needed.

**Warning signs:** Type scale looks slightly tighter or looser on iOS compared to Android at the same scale.

---

## Files to Create / Files to Modify

### New files

| Path | Purpose | Phase Requirement |
|------|---------|-------------------|
| `shared-core/src/commonMain/kotlin/dev/viethung/core/theme/DesignTokens.kt` | Token definitions (`TextStyleToken`, `LightColors`, `DarkColors`, `Typography`, `Spacing`, `Radius`) | THEME-01, THEME-02 |
| `shared-core/src/commonTest/kotlin/dev/viethung/core/theme/DesignTokensTest.kt` | `noColorConstantIsNegative()` assertion | THEME-02 |
| `androidApp/src/main/kotlin/dev/viethung/skeleton/android/theme/AppTheme.kt` | Compose `AppTheme` wrapper | THEME-03 |
| `iosApp/iosApp/Theme/AppTheme.swift` | SwiftUI `AppTheme` struct + `AppThemeKey` + sub-structs | THEME-04 |

### Modified files

| Path | Change | Phase Requirement |
|------|--------|-------------------|
| `androidApp/src/main/kotlin/dev/viethung/skeleton/android/MainActivity.kt:17` | Replace `MaterialTheme {` with `AppTheme {`; swap import | THEME-03 |
| `iosApp/iosApp/iosApp.swift` | Add `@Environment(\.colorScheme)` + `.environment(\.appTheme, ...)` at `WindowGroup` | THEME-04, THEME-05 |
| `iosApp/iosApp/Greeting/GreetingScreen.swift:28` | Add `@Environment(\.appTheme) var theme`; replace `.foregroundColor(.red)` with `.foregroundColor(theme.colors.error)` | THEME-04 |

### No Gradle changes required

`DesignTokens.kt` uses only Kotlin built-in types. `AppTheme.kt` uses `material3` which is already in the `androidApp` BOM dependency block. No new entries in `libs.versions.toml`.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | `kotlin.test` (KMP) + Kotest assertions 5.9.1 |
| Config file | (inherits `shared-core/build.gradle.kts` — no separate test config) |
| Quick run command | `./gradlew :shared-core:jvmTest` |
| Full suite command | `./gradlew :shared-core:allTests` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| THEME-01 | `DesignTokens.kt` compiles for Android + iOS with no platform imports | Build gate | `./gradlew :shared-core:build` | Will exist (Wave 0) |
| THEME-02 | Every color `Long` constant > 0 (no Int overflow) | unit (`commonTest`) | `./gradlew :shared-core:allTests` | Wave 0 gap |
| THEME-02 | Test runs on `iosSimulatorArm64` target | unit (iOS target) | `./gradlew :shared-core:iosSimulatorArm64Test` | Wave 0 gap |
| THEME-03 | Android app renders with token-sourced colors (no hex literals) | Compose UI smoke | `./gradlew :androidApp:assembleDebug` + visual check | manual only |
| THEME-03 | `MaterialTheme.colorScheme.error` renders indigo-derived red, not black | Compose UI smoke | manual: run on emulator | manual only |
| THEME-04 | iOS app renders with token-sourced colors (no hex literals) | SwiftUI smoke | `open iosApp/iosApp.xcodeproj` + ⌘R | manual only |
| THEME-04 | iOS error text is token red, not system `.red` | SwiftUI smoke | manual: simulator + inspect | manual only |
| THEME-05 | Switching macOS/iOS dark mode updates both apps without restart | Manual smoke | `xcrun simctl ui booted appearance dark` then `light` | manual only |
| THEME-05 | 10-rapid-toggle test: no flash of wrong palette on iOS | Manual stress | 10x toggle in iOS Simulator Settings | manual only |

### Sampling Rate

- **Per task commit:** `./gradlew :shared-core:jvmTest` (tests the `noColorConstantIsNegative` assertion in seconds)
- **Per wave merge:** `./gradlew :shared-core:allTests` (adds `iosSimulatorArm64Test`)
- **Phase gate:** `./gradlew :shared-core:allTests :androidApp:assembleDebug` + iOS build + manual dark-mode smoke

### Wave 0 Gaps

- `shared-core/src/commonTest/kotlin/dev/viethung/core/theme/DesignTokensTest.kt` — covers THEME-02 (the file does not exist yet)
- `shared-core/src/commonTest/kotlin/dev/viethung/core/` directory must be created (currently only `shared-app` has `commonTest`)

*(Android and iOS UI smoke tests are manual-only — no automated Compose or XCTest infra required for this phase.)*

---

## Security Domain

No user-facing authentication, data persistence, or network surface is touched in Phase 2. The only data flowing is compile-time color constants and system appearance state. ASVS categories V2, V3, V4, V6 are not applicable. V5 (input validation) is not applicable (no user input). No security controls are required.

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `ColorScheme` with ~29 roles (no surface container) | Full `ColorScheme` with 36 roles including `surfaceContainer*`, `surfaceDim`, `surfaceBright` | M3 1.2 (stable 1.3) | Must supply all roles; old constructor deprecated in 1.4 |
| `MaterialTheme { }` with default color scheme | `MaterialTheme(colorScheme = ..., typography = ..., shapes = ...)` with all explicit roles | Best practice enforced since M3 1.0 | Default scheme leaks M3 baseline colors; conflicts with token bridge |
| `isSystemInDarkTheme()` + `dynamicColorScheme()` | Token-based explicit palette; dynamic color explicitly opted out | Skeleton decision | Deterministic; cloned products always see the Skeleton palette, not wallpaper-seeded colors |
| `Color.RGBColorSpace.sRGB` implicit in SwiftUI | `Color(.sRGB, red:green:blue:opacity:)` explicit | Always explicit in this adapter | Avoids display-P3 color space assumption on recent iPhones |

**Deprecated / outdated:**
- `MaterialTheme { }` with zero parameters: compiles but leaks M3 baseline colors. Replace with fully explicit `MaterialTheme(colorScheme, typography, shapes)`.
- `Color(Int)` in Compose for ARGB: always use `Color(Long)` when the source is a `Long` constant to prevent silent truncation.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Kotlin `object` (`LightColors`, `DarkColors`) is accessed in Swift as `LightColors.shared` via SKIE/KMP | Pattern 4 (Swift adapter) | Code won't compile on iOS; planner must verify actual SKIE accessor name for Kotlin objects |
| A2 | `DesignTokens.Typography.shared` and `DesignTokens.Spacing.shared` accessor pattern is stable in SKIE 0.10.11 | Pattern 4 (Swift adapter) | If the `.shared` accessor is renamed by SKIE, all Swift constant accesses must be updated |
| A3 | `Color(argb: Int64)` extension calling `Color(.sRGB, red:green:blue:opacity:)` is compatible with iOS 17.0+ | Pattern 4 (color conversion) | If `Color.RGBColorSpace` or this initializer changed between iOS 16 and 17, the initializer call may need adjustment — iOS 17 is locked deployment target so this should be safe |

> **A1 and A2 are the highest-risk assumptions.** The planner should verify the exact SKIE-generated accessor name for Kotlin `object` declarations (is it `.shared` or a different name?) by inspecting the generated `SkeletonKit.framework/Headers/` from Phase 1. If the accessor name differs, adjust all Swift calls accordingly.

---

## Open Questions

1. **SKIE accessor name for Kotlin `object`**
   - What we know: SKIE bridges Kotlin `object` as a Swift singleton. The standard Kotlin/ObjC bridge exposes `object` as `+ (instancetype)shared` in ObjC, and SKIE typically preserves this as `.shared` in Swift.
   - What's unclear: SKIE 0.10.11 may rename the accessor or generate a different pattern for constants declared in nested objects.
   - Recommendation: At the start of Wave 1 implementation, build the iOS framework and inspect `SkeletonKit.framework/Headers/` for `DesignTokens` accessor names before writing any Swift adapter code.

2. **`ColorScheme` constructor parameter count in Compose BOM 2026.05.00 / Material3 1.4.0**
   - What we know: M3 1.3 added surface container family (7 roles). M3 1.4 added `Fixed` color roles (8 more roles: `primaryFixed`, `primaryFixedDim`, `onPrimaryFixed`, `onPrimaryFixedVariant`, plus secondary/tertiary equivalents). The 36-parameter constructor in Pattern 3 covers the M3 1.3 stable surface container roles but not the 1.4 Fixed roles.
   - What's unclear: Does the 1.4.0 `ColorScheme` constructor require the Fixed roles, or are they optional/defaulted?
   - Recommendation: The planner should check whether `ColorScheme(...)` with 36 parameters (no Fixed roles) is the current stable overload or is deprecated in 1.4.0. The search result indicates a "legacy constructor without Fixed roles" exists — confirm it's still non-deprecated in 1.4.0 stable or add the Fixed roles to `DesignTokens.kt`.

---

## Environment Availability

Step 2.6: SKIPPED — Phase 2 is a code/config-only change. No external tools, services, databases, or CLI utilities beyond the project's existing build chain are required. No new dependencies are added to `gradle/libs.versions.toml`.

---

## Sources

### Primary (HIGH confidence)
- [Context7: AndroidX Compose Material3 — ColorScheme, Typography, Shapes constructors] verified via `npx ctx7@latest docs`
- [Context7: SwiftUI — EnvironmentKey, EnvironmentValues, Color init] verified via `npx ctx7@latest docs`
- [Context7: SwiftUI — colorScheme environment value, @Environment] verified via `npx ctx7@latest docs`
- [M3 Typography type scale tokens table](https://m3.material.io/styles/typography/type-scale-tokens) — 15 roles, default size/weight/lineHeight/letterSpacing values
- [Composables.com Material3 ColorScheme 1.4.0 class reference](https://composables.com/docs/androidx.compose.material3/material3/1.4.0-alpha18/classes/ColorScheme) — complete constructor parameter list including surface container family
- [Composables.com Material3 Shapes class reference](https://composables.com/docs/androidx.compose.material3/material3/classes/Shapes) — Shapes(extraSmall, small, medium, large, extraLarge) stable constructor
- CONTEXT.md (D-01 through D-16) — locked decisions, verbatim binding for this research
- PITFALLS.md §Pitfall 6, §Pitfall 7 — documented failure modes and prevention patterns

### Secondary (MEDIUM confidence)
- [Apple SwiftUI EnvironmentKey documentation](https://developer.apple.com/documentation/swiftui/environmentkey) — protocol shape, EnvironmentValues extension idiom, @Environment usage
- [Apple SwiftUI Color init(red:green:blue:opacity:)](https://developer.apple.com/documentation/swiftui/color/init%28_%3Ared%3Agreen%3Ablue%3Aopacity%3A%29) — Double [0,1] components, sRGB default

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all libraries pre-existing; BOM + Material3 1.4.0 verified
- Architecture: HIGH — patterns derived from locked CONTEXT.md decisions + verified API docs
- Pitfalls: HIGH — Pitfalls 6 and 7 are verified, test assertions documented
- SKIE accessor names: MEDIUM — `.shared` is standard Kotlin/ObjC bridge pattern but not verified against SKIE 0.10.11 generated headers

**Research date:** 2026-05-10
**Valid until:** 2026-06-10 (Compose BOM updates quarterly; re-verify `ColorScheme` constructor if BOM is bumped before implementation)

---

## RESEARCH COMPLETE
