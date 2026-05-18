# Phase 2: Design Token Bridge - Context

**Gathered:** 2026-05-10
**Status:** Ready for planning

<domain>
## Phase Boundary

`DesignTokens.kt` in `:shared-core/commonMain` defines all visual primitives using only `Long` (colors as ARGB), `Float` (sizes, spacing, radius), and `Int` (font weight) — zero Compose or SwiftUI imports. Two color palettes (`LightColors`, `DarkColors`) and a full Material 3 type scale are defined. A Compose `AppTheme` wrapper maps those primitives to a `MaterialTheme` (ColorScheme, Typography, Shapes). A SwiftUI `AppTheme` struct maps them to native SwiftUI types (`Color`, `Font`) and is injected via a single custom `EnvironmentKey` at the `WindowGroup` root. Dark/light selection is always owned by Swift's `@Environment(\.colorScheme)` — Kotlin never selects the palette.

**In scope:** THEME-01, THEME-02, THEME-03, THEME-04, THEME-05. Updating the existing `GreetingScreen` (both platforms) to consume the token bridge and remove hardcoded values.
**Out of scope:** Any color picker or theme-toggle UI (SHOW-04 is Phase 6). Real brand refinement — this phase picks a placeholder palette good enough to make the showcase look intentional.

</domain>

<decisions>
## Implementation Decisions

### Color palette
- **D-01:** `DesignTokens.kt` defines the **full Material 3 ColorScheme mirror** — all ~30 color roles (primary, onPrimary, primaryContainer, onPrimaryContainer, secondary, onSecondary, secondaryContainer, onSecondaryContainer, tertiary, onTertiary, tertiaryContainer, onTertiaryContainer, error, onError, errorContainer, onErrorContainer, background, onBackground, surface, onSurface, surfaceVariant, onSurfaceVariant, outline, outlineVariant, scrim, inverseSurface, inverseOnSurface, inversePrimary, surfaceDim, surfaceBright, surfaceContainerLowest, surfaceContainerLow, surfaceContainer, surfaceContainerHigh, surfaceContainerHighest). Compose adapter passes every role to `ColorScheme(...)` — no M3 defaults leak in.
- **D-02:** Two `object` declarations: `LightColors` and `DarkColors`. Every constant is `Long` with `L` suffix: `const val primary: Long = 0xFF...L`. Pitfall 6 mitigation: `commonTest` asserts `no color constant < 0L` across both palettes.
- **D-03:** Palette values are a **real Skeleton identity palette** — an intentional indigo-primary / teal-tertiary / neutral-grey palette so the showcase looks finished and cloned products see a real override example. Planner selects exact hex values. The goal is presentable, not perfect.

### Typography tokens
- **D-04:** `TextStyleToken` is a `data class` in `commonMain` with four fields: `val size: Float`, `val weight: Int`, `val lineHeight: Float`, `val letterSpacing: Float`. No Compose or SwiftUI types. Planner ensures `letterSpacing` semantics match both M3's `sp` convention and SwiftUI's `Font.Leading`/`kerning` parameter.
- **D-05:** **All 15 M3 type scale roles** are defined in `DesignTokens.typography`: `displayLarge`, `displayMedium`, `displaySmall`, `headlineLarge`, `headlineMedium`, `headlineSmall`, `titleLarge`, `titleMedium`, `titleSmall`, `bodyLarge`, `bodyMedium`, `bodySmall`, `labelLarge`, `labelMedium`, `labelSmall`. Compose adapter maps each to `Typography(displayLarge = ..., ...)`. iOS adapter maps each to a `Font` via `Font.system(size:weight:)` with appropriate iOS font size scaling.

### SwiftUI environment injection
- **D-06:** A single `struct AppTheme` in Swift holds sub-properties: `.colors: ThemeColors`, `.typography: ThemeTypography`, `.spacing: ThemeSpacing`, `.radius: ThemeRadius`. Each sub-struct wraps the mapped SwiftUI values. Views access tokens via `@Environment(\.appTheme) var theme` → `theme.colors.primary`.
- **D-07:** A single `AppThemeKey: EnvironmentKey` is defined. Injection happens at **`WindowGroup` root in `iosApp.swift`**: `@Environment(\.colorScheme) var colorScheme` is read there, and `.environment(\.appTheme, AppTheme.build(colorScheme == .dark))` is applied once. All descendent views inherit it automatically.
- **D-08:** The Swift color adapter converts `Long` token values using `Int64` (never `Int32`) to avoid Pitfall 6's sign-bit corruption. Alpha extraction: `let a = UInt8((argb >> 24) & 0xFF)`. This pattern is documented in `PITFALLS.md` Pitfall 6.

### Spacing and radius tokens
- **D-09:** Spacing uses **semantic names** with 7 steps: `xxs = 2f`, `xs = 4f`, `sm = 8f`, `md = 16f`, `lg = 24f`, `xl = 32f`, `xxl = 48f`. Compose uses `theme.spacing.md.dp`; SwiftUI uses `theme.spacing.md`. All values are `Float` in `commonMain`.
- **D-10:** Radius uses **semantic names mirroring spacing**: `none = 0f`, `xs = 4f`, `sm = 8f`, `md = 12f`, `lg = 16f`, `xl = 28f`, `full = 9999f`. Compose adapter maps these to M3 `Shapes(extraSmall = RoundedCornerShape(radius.xs.dp), small = RoundedCornerShape(radius.sm.dp), medium = RoundedCornerShape(radius.md.dp), large = RoundedCornerShape(radius.lg.dp), extraLarge = RoundedCornerShape(radius.xl.dp))`.

### Android Compose adapter
- **D-11:** A `@Composable fun AppTheme(content: @Composable () -> Unit)` is defined in `:androidApp` (or a dedicated `theme/` package). It reads `isSystemInDarkTheme()` internally and selects `LightColors` or `DarkColors` from `DesignTokens`, then calls `MaterialTheme(colorScheme = ..., typography = ..., shapes = ..., content = content)`. `MainActivity.setContent` is updated to wrap `AppTheme { Surface { GreetingScreen() } }` and remove the bare `MaterialTheme { }` call.
- **D-12:** No hex literals anywhere in `androidApp` theme code — every value comes from `DesignTokens`. `GreetingScreen.kt` must have its `MaterialTheme.colorScheme.error` usage retained (correct API) but the token bridge must supply the actual color value, not a hardcoded hex.

### iOS theme update
- **D-13:** `GreetingScreen.swift` hardcoded `.red` for error text is removed and replaced with `theme.colors.error` (from `@Environment(\.appTheme)`). No hex literals in any `.swift` file.
- **D-14:** `ContentView.swift` or `iosApp.swift` root view is updated to inject `.environment(\.appTheme, ...)` as per D-07. `GreetingScreen` gains `@Environment(\.appTheme) var theme` only if it needs to reference a token directly (error color case).

### Pitfall mitigations (Phase 2 owns these)
- **D-15:** Pitfall 6 (ARGB Long overflow) — every color constant ends with `L`; `commonTest` `noColorConstantIsNegative()` runs on both JVM and `iosSimulatorArm64` targets; Swift adapter uses `Int64`.
- **D-16:** Pitfall 7 (dark mode selection on wrong side) — `DesignTokens` only exports both palettes; the platform UI layer (Compose `MainActivity` / SwiftUI `iosApp`) is the sole selector; no `isDark: Boolean` is ever passed from Swift / Compose to `commonMain`. Rapid-switch test (10 toggles via in-app button per D-17) is the smoke test.

### In-app theme toggle (validated 2026-05-18)
- **D-17:** `GreetingScreen` on both platforms gets a single button that cycles the active theme. The toggle **overrides** the system appearance for the app's process; OS-level dark/light setting is bypassed once the user taps the button.
  - **Android:** `MainActivity.setContent` hoists `var themeOverride: Boolean? by rememberSaveable { mutableStateOf<Boolean?>(null) }`. `AppTheme` is invoked with `isDark = themeOverride ?: isSystemInDarkTheme()` (signature: `@Composable fun AppTheme(isDark: Boolean = isSystemInDarkTheme(), content: @Composable () -> Unit)`). `GreetingScreen` receives `themeOverride: Boolean?` and `onCycleTheme: () -> Unit`; tapping advances the cycle **`null → false → true → null`** — three states, matching iOS for UX parity. Button label depends on `themeOverride`: `null → "Override theme"`, `false → "Switch to Dark"`, `true → "Switch to System"`. **AppCompatDelegate.setDefaultNightMode was considered and rejected** — it would require switching `MainActivity` from `ComponentActivity` to `AppCompatActivity` and adding `androidx.appcompat:appcompat`. The pure-Compose state hoist gives the same UX with zero new dependencies. Trade-off: override persists across configuration changes via `rememberSaveable` but resets on process death — acceptable for a demo gesture.
  - **iOS:** `iosApp.swift` `WindowGroup` hoists `@State private var themeOverride: ColorScheme? = nil`. `WindowGroup` content applies `.preferredColorScheme(themeOverride)`. The `.environment(\.appTheme, ...)` modifier reads `(themeOverride ?? systemColorScheme) == .dark` to pick the palette. `ContentView` receives a `Binding<ColorScheme?>` and forwards it to `GreetingScreen`. Toggle cycles `nil → .light → .dark → nil` (three states, symmetric with Android).
  - **Pitfall 7 invariant preserved:** palette selection still lives in each platform's UI layer. No `isDark: Boolean` crosses into `commonMain`. `DesignTokens` continues to export both palettes only.
  - **Verification scope trade-off (accepted):** `02-04-CKP` human-verify gate drives the in-app button instead of the OS Settings path. The "system appearance change → palette" code path is no longer covered by a manual gate (only by the same `AppTheme.build(isDark:)` adapter that the button path exercises).

### Claude's Discretion
- ~~Exact hex values for the Skeleton identity palette~~ — **Resolved 2026-05-18 (V-D1):** hex values committed in `02-01-PLAN.md` (indigo `0xFF3F51B5L` primary, teal `0xFF009688L` tertiary). Treated as skeleton placeholder; cloned products override.
- ~~Whether `DesignTokens` is a Kotlin `object` or top-level `const val`~~ — **Resolved:** `object DesignTokens { object LightColors { ... } ... }` (see `02-01-PLAN.md` §131).
- ~~Whether `ThemeColors`, etc. are `struct` or `class` in Swift~~ — **Resolved:** `struct` (see `02-03-PLAN.md` §200, §279).
- ~~Whether to add a `SHOW-04`-style runtime theme toggle~~ — **Resolved 2026-05-18 (V-D2 / V-D3):** in-scope per **D-17** above. Phase 6 SHOW-04 remains the broader theme-customization picker; D-17 is the minimum visible demonstration.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project requirements + roadmap
- `.planning/PROJECT.md` — Skeleton goals, constraints (commonMain primitives-only rule, state ownership), key decisions table.
- `.planning/REQUIREMENTS.md` §THEME — THEME-01..THEME-05 are the binding success criteria for Phase 2.
- `.planning/ROADMAP.md` §"Phase 2: Design Token Bridge" — Goal, depends-on, success criteria (especially SC4: dark mode owned by Swift), pitfall refs (6, 7).
- `.planning/STATE.md` — Current phase + accumulated decisions log.

### Phase 1 context (patterns already established)
- `.planning/phases/01-kmp-scaffold-tooling/01-CONTEXT.md` — D-01 (iOS targets iosArm64 + iosSimulatorArm64 only), D-03 (group ID `dev.viethung`), D-04 (package layout), D-10 (Greeting feature shape), D-11 (module placement). Phase 2 code must follow the same module structure.

### Pitfall documentation
- `.planning/research/PITFALLS.md` §Pitfall 6 — ARGB Long overflow: `L` suffix, `Int64` in Swift, `commonTest` no-negative assertion.
- `.planning/research/PITFALLS.md` §Pitfall 7 — Dark mode token selection ownership: Swift `@Environment(\.colorScheme)` selects palette; Kotlin never selects.

### Architecture + research
- `.planning/research/SUMMARY.md` §"Phase 2: Design Token Bridge" — Research findings and delivered-artifacts summary.
- `architecture.md` (repo root) — Locked MVVM + StateFlow + UDF pattern; iOS `IosViewModelStoreOwner` contract; commonMain primitives-only constraint.
- `CLAUDE.md` (repo root) — Locked tech stack, library versions, "What NOT to Use" table; Compose BOM 2026.05.00 maps Material3 1.4.0.

### External references
- Material 3 ColorScheme roles: `https://m3.material.io/styles/color/roles` — authoritative naming for the ~30 color roles.
- M3 Typography type scale: `https://m3.material.io/styles/typography/type-scale-tokens` — 15 type scale roles and their default values.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `androidApp/.../MainActivity.kt:15` — bare `MaterialTheme { Surface { GreetingScreen() } }` — Phase 2 replaces this with `AppTheme { Surface { GreetingScreen() } }`.
- `androidApp/.../GreetingScreen.kt:24` — uses `MaterialTheme.typography.headlineMedium` and `MaterialTheme.colorScheme.error` — these are already using the M3 API; Phase 2 just needs the theme to be populated from tokens, no API change needed.
- `iosApp/.../GreetingScreen.swift:28` — hardcoded `.red` on error text — Phase 2 replaces with `theme.colors.error`.
- `iosApp/.../iosApp.swift` — `WindowGroup { ContentView() }` — Phase 2 adds `.environment(\.appTheme, ...)` here.

### Established Patterns
- Module placement: `DesignTokens.kt` goes in `:shared-core/src/commonMain/kotlin/dev/viethung/core/theme/`.
- Compose adapter (`AppTheme.kt`) goes in `:androidApp/src/main/kotlin/dev/viethung/skeleton/android/theme/`.
- Swift adapter (`AppTheme.swift`) goes in `iosApp/iosApp/Theme/`.
- No Compose or SwiftUI import is allowed in any file under `shared-core/src/commonMain/` — this is enforced by the KMP compiler (those classes don't exist on the other target).

### Integration Points
- `:shared-core/build.gradle.kts` — no changes needed for tokens (pure `data class` / `object`, no new dependencies).
- `androidApp/src/main/.../MainActivity.kt` — swap bare `MaterialTheme` for `AppTheme`.
- `iosApp/iosApp/iosApp.swift` — inject `AppTheme` environment at `WindowGroup` root.
- `shared-components/commonMain/.../SampleUiState.kt` — no changes needed in Phase 2; Phase 3 component ViewModels will consume `DesignTokens` from `:shared-core`.

</code_context>

<specifics>
## Specific Ideas

- An intentional Skeleton identity palette — indigo primary (e.g., `0xFF3F51B5`), teal tertiary (e.g., `0xFF009688`), neutral surface greys. Planner selects exact M3-spec-compliant values using the Material Theme Builder tool if desired.
- The `noColorConstantIsNegative()` `commonTest` should check both `LightColors` and `DarkColors` via reflection or an explicit list — use an explicit list (`listOf(LightColors.primary, LightColors.onPrimary, ...)`) since reflection is not available on all KMP targets.
- Swift's `Color(red:green:blue:opacity:)` initializer takes `Double` in [0,1]; the adapter extracts R/G/B/A bytes from the `Int64` ARGB and divides by 255.0.

</specifics>

<deferred>
## Deferred Ideas

- **Runtime light/dark theme toggle in showcase UI** (SHOW-04) — Phase 6. Phase 2 verifies dark mode by switching system appearance, not a UI toggle.
- **Brand refinement / final color values** — out of scope for v1; the skeleton palette is a placeholder that cloned products replace.
- **Custom font loading** (e.g., downloading a brand typeface) — `TextStyleToken.fontFamily` is a `String?` but Phase 2 uses system fonts only. Custom font loading is a per-product concern.
- **Dynamic color / Material You** (Android 12+ wallpaper-seeded palette) — explicit opt-out for a skeleton template; would conflict with the token bridge's deterministic palette contract.

</deferred>

---

*Phase: 2-design-token-bridge*
*Context gathered: 2026-05-10*
