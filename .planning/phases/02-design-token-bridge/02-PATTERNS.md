# Phase 2: Design Token Bridge - Pattern Map

**Mapped:** 2026-05-10
**Files analyzed:** 8 (3 CREATE, 5 MODIFY)
**Analogs found:** 8 / 8

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `shared-core/src/commonMain/kotlin/dev/viethung/core/theme/DesignTokens.kt` | config (primitives object) | transform | `shared-components/src/commonMain/kotlin/dev/viethung/components/SampleUiState.kt` | structural-match (sealed hierarchy pattern; data-class + nested objects) |
| `shared-core/src/commonTest/kotlin/dev/viethung/core/theme/DesignTokensTest.kt` | test | transform | `shared-components/src/commonTest/kotlin/dev/viethung/components/SkieGenericsTest.kt` | exact (kotlin.test, explicit-list assertions, multi-target commonTest) |
| `androidApp/src/main/kotlin/dev/viethung/skeleton/android/theme/AppTheme.kt` | provider (Compose theme adapter) | request-response | `androidApp/src/main/kotlin/dev/viethung/skeleton/android/greeting/GreetingScreen.kt` | role-match (same package structure, Compose @Composable, MaterialTheme API usage) |
| `iosApp/iosApp/Theme/AppTheme.swift` | provider (SwiftUI environment adapter) | request-response | `iosApp/iosApp/Common/IosViewModelStoreOwner.swift` | structural-match (SwiftUI protocol conformance + extension pattern; `import SkeletonKit`) |
| `androidApp/src/main/kotlin/dev/viethung/skeleton/android/MainActivity.kt` (MODIFY) | config | request-response | itself (current Phase 1 content) | exact — one-line swap |
| `iosApp/iosApp/iosApp.swift` (MODIFY) | config | request-response | itself (current Phase 1 content) | exact — surgical addition |
| `iosApp/iosApp/Greeting/GreetingScreen.swift` (MODIFY) | component | request-response | itself (current Phase 1 content) | exact — add one property + swap one line |
| `androidApp/src/main/kotlin/dev/viethung/skeleton/android/greeting/GreetingScreen.kt` (no-op) | component | request-response | itself | no-op — already uses `MaterialTheme.colorScheme.error` correctly |

---

## Pattern Assignments

### `shared-core/src/commonMain/kotlin/dev/viethung/core/theme/DesignTokens.kt`
*Role: config (primitives object) — Data Flow: transform*

**Analog:** `shared-components/src/commonMain/kotlin/dev/viethung/components/SampleUiState.kt` (nested sealed hierarchy / data-class pattern) + RESEARCH.md Pattern 1 (no codebase analog exists yet for a design-token object — this is the first one)

**Package/module placement pattern** (from every existing `commonMain` file):
```kotlin
// Exact package path established by Phase 1 D-03 / D-04
package dev.viethung.core.theme
```

**Nested object/data-class pattern** — copy from `SampleUiState.kt` (lines 20-33) for structural shape; tokens use `object` instead of `sealed interface`:
```kotlin
// SampleUiState.kt:20-33 — the nested-type idiom Phase 2 mirrors
sealed interface SampleUiState {
    data object Loading : SampleUiState
    data class Ready(val message: String) : SampleUiState
    data class Error(val message: String) : SampleUiState
}
// Delta for DesignTokens: use `object DesignTokens { object LightColors { ... } }` —
// same nesting depth, same package style, but objects not sealed interfaces.
```

**Pitfall 6 mandatory pattern** — every color constant:
```kotlin
// CRITICAL: L suffix forces Long on all KMP targets (Pitfall 6)
// Omitting L → Kotlin infers Int → overflow to negative for any color where high byte sets sign bit
const val primary: Long = 0xFF3F51B5L   // correct
// const val primary = 0xFF3F51B5      // WRONG — compiles, silently corrupts on JVM + Native
```

**`data class` in commonMain** — no platform imports allowed (compiler enforces):
```kotlin
// CLAUDE.md rule: "No platform types in commonMain — design tokens are primitives only"
data class TextStyleToken(
    val size: Float,
    val weight: Int,
    val lineHeight: Float,
    val letterSpacing: Float,
)
// NO: androidx.compose.ui.text.TextStyle — does not compile on iosSimulatorArm64 target
// NO: SwiftUI.Font — does not exist in Kotlin
```

**Delta vs analog:** SampleUiState uses `sealed interface` + `data class`/`data object`; DesignTokens uses nested `object`s with `const val` and a standalone `data class TextStyleToken`. Package discipline and no-platform-import rules are identical.

---

### `shared-core/src/commonTest/kotlin/dev/viethung/core/theme/DesignTokensTest.kt`
*Role: test — Data Flow: transform*

**Analog:** `shared-components/src/commonTest/kotlin/dev/viethung/components/SkieGenericsTest.kt`

**Imports pattern** (SkieGenericsTest.kt lines 1-8):
```kotlin
package dev.viethung.components

import kotlin.test.Test                    // kotlin.test.Test — NEVER org.junit.Test (D-17 / Pitfall 18)
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertIs
import kotlin.test.assertTrue
```

**Test class shape** (SkieGenericsTest.kt lines 16-18):
```kotlin
class SkieGenericsTest {

    @Test
    fun loadingIsDistinctFromReadyAndError() {
```

**Explicit-list assertion pattern** (SkieGenericsTest.kt lines 44-56) — same pattern needed for color completeness check:
```kotlin
    val states: List<SampleUiState> = listOf(
        SampleUiState.Loading,
        SampleUiState.Ready("ok"),
        SampleUiState.Error("fail"),
    )
    // ...
    assertEquals(listOf("loading", "ready:ok", "error:fail"), labels)
```

**GreetingViewModelTest dispatcher setup pattern** (GreetingViewModelTest.kt lines 1-17) — copy `@BeforeTest`/`@AfterTest` only if coroutines are involved (DesignTokensTest is pure data, no coroutines needed):
```kotlin
import kotlin.test.AfterTest
import kotlin.test.BeforeTest
import kotlin.test.Test                   // kotlin.test.Test — NEVER org.junit.Test
```

**Delta vs analog:** SkieGenericsTest uses `assertIs`/`assertFalse`; DesignTokensTest uses `assertTrue(color > 0L, ...)` on explicit `List<Long>`. Same kotlin.test import style, same no-JUnit rule, same `commonTest` source set. No `@BeforeTest`/dispatcher setup needed (no coroutines).

**Key pattern — explicit list, not reflection** (RESEARCH.md Pattern 2 / CONTEXT.md D-15):
```kotlin
// Reflection is not reliable on all KMP targets (iosSimulatorArm64)
// Use an explicit list that must stay in sync with DesignTokens.kt
val lightColors: List<Long> = listOf(
    DesignTokens.LightColors.primary,
    DesignTokens.LightColors.onPrimary,
    // ... all ~36 constants
)
(lightColors + darkColors).forEachIndexed { i, color ->
    assertTrue(color > 0L,
        "Color at index $i is negative ($color). Missing L suffix — see Pitfall 6.")
}
```

---

### `androidApp/src/main/kotlin/dev/viethung/skeleton/android/theme/AppTheme.kt`
*Role: provider (Compose theme adapter) — Data Flow: request-response*

**Analog:** `androidApp/src/main/kotlin/dev/viethung/skeleton/android/greeting/GreetingScreen.kt`

**Imports pattern** (GreetingScreen.kt lines 1-16) — establish the androidApp Compose import style:
```kotlin
package dev.viethung.skeleton.android.greeting

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import dev.viethung.showcase.greeting.GreetingViewModel
import org.koin.androidx.compose.koinViewModel
```

**Composable function shape** (GreetingScreen.kt lines 17-20):
```kotlin
@Composable
fun GreetingScreen(
    viewModel: GreetingViewModel = koinViewModel(),
) {
```

**MaterialTheme usage pattern in GreetingScreen** (GreetingScreen.kt lines 33-41) — confirms the M3 API surface AppTheme.kt must populate:
```kotlin
            is GreetingViewModel.UiState.Ready   -> Text(
                text = s.message,
                style = MaterialTheme.typography.headlineMedium,
            )
            is GreetingViewModel.UiState.Error   -> Text(
                text = "Error: ${s.message}",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.error,
            )
```

**AppTheme.kt import block** (RESEARCH.md Pattern 3 — no existing analog in androidApp yet, new `theme/` sub-package):
```kotlin
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
```

**Core adapter pattern** (RESEARCH.md Pattern 3, verified against Material3 1.4.0 API):
```kotlin
@Composable
fun AppTheme(content: @Composable () -> Unit) {
    val isDark = isSystemInDarkTheme()
    val palette = if (isDark) DesignTokens.DarkColors else DesignTokens.LightColors

    val colorScheme = ColorScheme(
        primary    = Color(palette.primary),
        onPrimary  = Color(palette.onPrimary),
        // ... all ~36 roles — no M3 defaults leak in (D-01)
    )
    // Typography: each TextStyleToken → TextStyle via toTextStyle() private extension
    // Shapes: 5 M3 params (extraSmall/small/medium/large/extraLarge) from Radius tokens
    MaterialTheme(colorScheme = colorScheme, typography = typography, shapes = shapes, content = content)
}

private fun TextStyleToken.toTextStyle(): TextStyle = TextStyle(
    fontSize      = size.sp,
    fontWeight    = FontWeight(weight),
    lineHeight    = lineHeight.sp,
    letterSpacing = letterSpacing.sp,
)
```

**Delta vs analog:** GreetingScreen is a consumer; AppTheme.kt is a provider. Same package discipline (`dev.viethung.skeleton.android.*`), same Compose import paths, same `@Composable` function shape. New sub-package `theme/` (mirrors `greeting/` sub-package pattern). No `koinViewModel` — AppTheme has no VM dependency.

---

### `iosApp/iosApp/Theme/AppTheme.swift`
*Role: provider (SwiftUI environment adapter) — Data Flow: request-response*

**Analog:** `iosApp/iosApp/Common/IosViewModelStoreOwner.swift`

**Import pattern** (IosViewModelStoreOwner.swift lines 1-2):
```swift
import SkeletonKit          // D-15 / Pitfall 21: framework umbrella name, not module name
import Foundation
```

**Swift extension pattern** (IosViewModelStoreOwner.swift lines 23-33):
```swift
extension IosViewModelStoreOwner {
    func viewModel<VM: ViewModel>(factory: ViewModelProvider.Factory) -> VM {
        ViewModelProvider(store: viewModelStore, factory: factory).get(modelClass: VM.self)
    }
}
```

**EnvironmentKey pattern** — new in Phase 2, follows SwiftUI idiom verified against iOS 17.0 deployment target:
```swift
// EnvironmentKey: one required static property
private struct AppThemeKey: EnvironmentKey {
    static let defaultValue: AppTheme = AppTheme.build(isDark: false)
}

// EnvironmentValues extension: computed get/set property
extension EnvironmentValues {
    var appTheme: AppTheme {
        get { self[AppThemeKey.self] }
        set { self[AppThemeKey.self] = newValue }
    }
}
```

**Color-from-Long conversion — Pitfall 6 / D-08** (RESEARCH.md Pattern 4):
```swift
// CRITICAL: argb parameter MUST be Int64, not Int32.
// KMP Kotlin Long bridges to Swift Int64. Using Int32 re-introduces sign-bit overflow.
extension Color {
    init(argb: Int64) {
        let a = Double(UInt8((argb >> 24) & 0xFF)) / 255.0
        let r = Double(UInt8((argb >> 16) & 0xFF)) / 255.0
        let g = Double(UInt8((argb >> 8)  & 0xFF)) / 255.0
        let b = Double(UInt8( argb        & 0xFF)) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}
```

**Value-type struct idiom** — mirrors `IosViewModelStoreOwner` using `struct` for SwiftUI environment:
```swift
// struct (not class): idiomatic for SwiftUI environment values (value semantics)
struct ThemeColors { let primary: Color; let onPrimary: Color; /* ... all roles */ }
struct ThemeSpacing { let xxs: CGFloat; let xs: CGFloat; /* ... */ }
struct ThemeRadius  { let none: CGFloat; let xs: CGFloat; /* ... */ }
struct AppTheme {
    let colors: ThemeColors
    let typography: ThemeTypography
    let spacing: ThemeSpacing
    let radius: ThemeRadius
    static func build(isDark: Bool) -> AppTheme { /* ... */ }
}
```

**Accessing KMP Kotlin `object` from Swift** — Kotlin `object LightColors` bridges to Swift as a singleton with `.shared` accessor:
```swift
// Kotlin `object LightColors { const val primary: Long = ... }`
// bridges to Swift as: DesignTokens.LightColors.shared.primary (Int64)
let p = isDark
    ? DesignTokens.DarkColors.shared
    : DesignTokens.LightColors.shared
Color(argb: p.primary)  // p.primary is Int64 on the Swift side
```

**Delta vs analog:** IosViewModelStoreOwner is `final class` (reference type needed for `@StateObject`); AppTheme.swift uses `struct` (value type, correct for environment). Same `import SkeletonKit` convention. New `Theme/` group mirrors existing `Common/`, `Greeting/`, `App/` group structure.

---

### `androidApp/src/main/kotlin/dev/viethung/skeleton/android/MainActivity.kt` (MODIFY)
*Role: config — Data Flow: request-response*

**Analog:** itself (`MainActivity.kt` — current state is the before-image)

**Before** (MainActivity.kt lines 7-21 — current):
```kotlin
import androidx.compose.material3.MaterialTheme
// ...
setContent {
    MaterialTheme {
        Surface {
            GreetingScreen()
        }
    }
}
```

**After** (surgical — swap one import, rename one call site):
```kotlin
import dev.viethung.skeleton.android.theme.AppTheme
// Remove: import androidx.compose.material3.MaterialTheme
// ...
setContent {
    AppTheme {
        Surface {
            GreetingScreen()
        }
    }
}
```

**Lines touched:** import at line 7 (replace) + `MaterialTheme` call at line 17 (rename to `AppTheme`). All other lines unchanged. `enableEdgeToEdge()` and `Surface {}` stay as-is.

---

### `iosApp/iosApp/iosApp.swift` (MODIFY)
*Role: config — Data Flow: request-response*

**Analog:** itself (`iosApp.swift` — current state is the before-image)

**Before** (iosApp.swift lines 1-14 — current):
```swift
import SwiftUI

@main
struct iosApp: App {
    init() {
        AppKoinBridge.start()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

**After** (surgical — add one stored property + one modifier):
```swift
import SwiftUI

@main
struct iosApp: App {
    init() {
        AppKoinBridge.start()
    }

    @Environment(\.colorScheme) private var colorScheme   // ADD

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.appTheme, AppTheme.build(isDark: colorScheme == .dark))  // ADD
        }
    }
}
```

**D-16 contract:** `colorScheme` is a system-provided value; SwiftUI re-renders `body` on appearance change and recomputes `AppTheme.build(isDark:)` synchronously. Kotlin never receives the isDark value.

---

### `iosApp/iosApp/Greeting/GreetingScreen.swift` (MODIFY)
*Role: component — Data Flow: request-response*

**Analog:** itself (`GreetingScreen.swift` — current state is the before-image)

**Before** (GreetingScreen.swift lines 4-8 + line 23):
```swift
struct GreetingScreen: View {
    @StateObject private var owner = IosViewModelStoreOwner()
    @State private var uiState: GreetingViewModelUiState = .loading
    // ...
                Text("Error: \(e.message)")
                    .foregroundColor(.red)          // hardcoded — D-13 removes this
```

**After** (surgical — add one `@Environment` property + swap `.red`):
```swift
struct GreetingScreen: View {
    @StateObject private var owner = IosViewModelStoreOwner()
    @State private var uiState: GreetingViewModelUiState = .loading
    @Environment(\.appTheme) private var theme              // ADD

    // ...
                Text("Error: \(e.message)")
                    .foregroundColor(theme.colors.error)    // was: .foregroundColor(.red)
```

**`@Environment` property ordering convention** — follows `@StateObject` and `@State` at top of struct, before `body`. Matches the ordering pattern in `IosViewModelStoreOwner.swift` where lifecycle-critical properties come before utility extensions.

---

### `androidApp/src/main/kotlin/dev/viethung/skeleton/android/greeting/GreetingScreen.kt` (no-op)
*Role: component — Data Flow: request-response*

**No changes required.** `GreetingScreen.kt` already uses `MaterialTheme.colorScheme.error` and `MaterialTheme.typography.headlineMedium` — the M3 API contract is correct. Phase 2 populates those MaterialTheme slots from tokens via `AppTheme`; the screen code does not change.

**Confirmation** (GreetingScreen.kt lines 33-41):
```kotlin
is GreetingViewModel.UiState.Ready   -> Text(
    text = s.message,
    style = MaterialTheme.typography.headlineMedium,   // correct M3 API — no change
)
is GreetingViewModel.UiState.Error   -> Text(
    text = "Error: ${s.message}",
    style = MaterialTheme.typography.bodyMedium,
    color = MaterialTheme.colorScheme.error,           // correct M3 API — no change
)
```

---

## Shared Patterns

### Kotlin `const val` Long suffix (Pitfall 6)
**Source:** RESEARCH.md §Pitfall 6 Walkthrough + CONTEXT.md D-15
**Apply to:** `DesignTokens.kt` — every color constant in `LightColors` and `DarkColors`
```kotlin
// Mandatory pattern — compiler does not enforce this; only commonTest catches it
const val primary: Long = 0xFF3F51B5L   // L suffix is load-bearing
// 0xFF3F51B5 without L: Int on JVM/Native, overflows to negative, corrupts color
```

### `kotlin.test.Test` import (Pitfall 18 / D-17)
**Source:** `GreetingViewModelTest.kt` line 13; `SkieGenericsTest.kt` line 3
**Apply to:** `DesignTokensTest.kt`
```kotlin
import kotlin.test.Test    // NEVER org.junit.Test — must run on iosSimulatorArm64 target
```

### No platform types in `commonMain`
**Source:** CLAUDE.md §2 "No platform types in commonMain"
**Apply to:** `DesignTokens.kt`, `TextStyleToken` data class
```kotlin
// Enforced by KMP compiler: androidx.compose.* and SwiftUI.* do not exist on both targets
// Only Kotlin primitives: Long, Float, Int, data class with primitive fields
```

### `import SkeletonKit` (not module name, not `shared`)
**Source:** `IosViewModelStoreOwner.swift` line 1; `GreetingScreen.swift` line 2
**Apply to:** `AppTheme.swift`
```swift
import SkeletonKit    // D-15 / Pitfall 21: baseName = "SkeletonKit" — never "shared"
```

### SwiftUI `@Environment` property declaration
**Source:** `GreetingScreen.swift` (after Phase 2 modification)
**Apply to:** Any SwiftUI view that consumes the theme
```swift
@Environment(\.appTheme) private var theme
// Placed after @StateObject / @State properties, before body
```

### Dark mode — Kotlin never selects, Swift always selects (Pitfall 7 / D-16)
**Source:** RESEARCH.md §Pattern 5 + CONTEXT.md D-16
**Apply to:** `AppTheme.swift` + `iosApp.swift`
```swift
// iOS: @Environment(\.colorScheme) at WindowGroup root — system-driven, zero latency
.environment(\.appTheme, AppTheme.build(isDark: colorScheme == .dark))
```
```kotlin
// Android: isSystemInDarkTheme() inside AppTheme composable — Compose-driven, zero latency
val isDark = isSystemInDarkTheme()
// No Boolean parameter ever travels Kotlin ↔ Swift
```

---

## No Analog Found

All 8 files have analogs or are self-modifying (before/after). The following files have **no direct codebase analog** (first of their role in this project) and rely on RESEARCH.md patterns:

| File | Role | Data Flow | Reason |
|---|---|---|---|
| `DesignTokens.kt` | config (token primitives object) | transform | First design token file; closest structural match is `SampleUiState.kt` but it is a different role (sealed UiState vs token constants). RESEARCH.md Pattern 1 is the primary reference. |
| `AppTheme.kt` | provider (Compose adapter) | request-response | First Compose theme adapter; no existing `@Composable` provider function exists. RESEARCH.md Pattern 3 (verified against Material3 1.4.0 API). |
| `AppTheme.swift` | provider (SwiftUI environment adapter) | request-response | First SwiftUI EnvironmentKey file; `IosViewModelStoreOwner.swift` provides structural guidance but is a different role. RESEARCH.md Pattern 4 (verified against iOS 17 SwiftUI API). |

---

## Metadata

**Analog search scope:** `androidApp/src/`, `iosApp/iosApp/`, `shared-core/src/`, `shared-components/src/`, `shared-app/src/`
**Files scanned:** 22 Kotlin + 5 Swift source files (main branch, excluding worktrees and build outputs)
**Pattern extraction date:** 2026-05-10

**Key constraint reminders for planner:**
- `shared-core/build.gradle.kts` needs no changes — tokens are pure Kotlin primitives (RESEARCH.md §Standard Stack)
- `gradle/libs.versions.toml` needs no changes — no new dependencies
- The `iosApp` Xcode project needs a new `Theme/` group added in Xcode's file navigator (new Swift file in new group)
- `DesignTokens.kt` Kotlin `object` constants bridge to Swift as `DesignTokens.LightColors.shared.primary` (`Int64` type)
- `Shapes` in Material3 takes exactly 5 parameters (`extraSmall` through `extraLarge`); `full`/`none` are Compose constants, not constructor params
