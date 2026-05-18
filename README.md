# Skeleton

A personal Kotlin Multiplatform mobile-app **skeleton template**. Shared Kotlin business logic; **native UI on each platform** — Jetpack Compose on Android, SwiftUI on iOS.

Designed to be cloned, renamed, and used as the foundation for new product ideas.

> **Status**: in active development. Phase 1 (KMP scaffold + tooling) and Phase 2 (design token bridge — shared `DesignTokens.kt` + Compose + SwiftUI adapters + dark-mode toggle) are live. See `.planning/ROADMAP.md` for the full phase plan.
> **Working title** `Skeleton` is a placeholder. See [Renaming](#renaming-the-skeleton) before turning this into a real project.

---

## Why this architecture

Kotlin Multiplatform shares everything *below* the UI; each platform owns its UI in the platform-native idiom. Tradeoff vs Compose Multiplatform iOS:

- ✅ Truly native iOS feel; full SwiftUI ecosystem; iOS toolchain unchanged
- ✅ No risk of Compose-iOS rendering surprises
- ❌ UI is implemented twice (one Compose tree, one SwiftUI tree)
- ❌ Need a Kotlin↔Swift interop layer (solved with [SKIE](https://skie.touchlab.co/))

Shipped at scale by Netflix, Square / Cash App, Philips Hue, McDonald's.

## Architecture at a glance

```
┌──────────────────────────┐  ┌──────────────────────────┐
│ androidApp/              │  │ iosApp/                  │
│   Jetpack Compose UI     │  │   SwiftUI                │
│   collects StateFlow     │  │   subscribes via SKIE    │
└────────────┬─────────────┘  └────────────┬─────────────┘
             │                              │
             │       consumes shared API    │
             ▼                              ▼
        ┌──────────────────────────────────────────┐
        │ shared/  (KMP module)                    │
        │   ViewModels  (StateFlow)                │
        │   Use cases  /  business rules           │
        │   Repositories                           │
        │   Networking  (Ktor)                     │
        │   Persistence  (SQLDelight)              │
        │   DI  (Koin)                             │
        └──────────────────────────────────────────┘
```

**Single source of truth for state** lives in shared `ViewModel` classes built on `StateFlow`. Both UIs are pure projections.

- Android collects the flow with `collectAsStateWithLifecycle()`.
- iOS consumes via SKIE-generated `AsyncSequence` / `@Published` bridges.

## Design tokens (shared global config)

**Principle:** every UI primitive — color, typography (family, size, weight), spacing, corner radius, animation duration — is defined **once in `shared/commonMain/`** and consumed by both apps. Change a font size in shared → both Android and iOS update on next build.

### What lives where

| Layer                          | Contents                                                                          | Why                                                              |
|--------------------------------|-----------------------------------------------------------------------------------|------------------------------------------------------------------|
| `shared/commonMain/.../theme/` | pure data — `Long` (ARGB), `Float`, `Int` primitives in `object`s / `data class`es | no Compose / SwiftUI types; those don't compile on the other side |
| `androidApp/.../theme/`        | adapter — maps shared tokens → `MaterialTheme`, `ColorScheme`, `Typography`        | Compose-specific glue                                            |
| `iosApp/.../Theme/`            | adapter — maps shared tokens → SwiftUI `Color`, `Font`, environment values         | SwiftUI-specific glue                                            |

### Shared token definitions (commonMain)

```kotlin
// shared/src/commonMain/kotlin/dev/skeleton/theme/DesignTokens.kt
package dev.skeleton.theme

object DesignTokens {
    object Typography {
        val fontFamily   = "Inter"
        val titleLarge   = TextStyleToken(size = 24f, weight = 600)
        val titleMedium  = TextStyleToken(size = 20f, weight = 600)
        val body         = TextStyleToken(size = 16f, weight = 400)
        val caption      = TextStyleToken(size = 12f, weight = 400)
    }
    object Spacing { val xs = 4f; val sm = 8f; val md = 16f; val lg = 24f; val xl = 32f }
    object Radius  { val sm = 4f; val md = 8f; val lg = 16f }
}

data class TextStyleToken(val size: Float, val weight: Int)

object LightColors {
    const val primary:   Long = 0xFF3B82F6   // ARGB
    const val surface:   Long = 0xFFFFFFFF
    const val onSurface: Long = 0xFF111827
    const val error:     Long = 0xFFEF4444
}

object DarkColors {
    const val primary:   Long = 0xFF60A5FA
    const val surface:   Long = 0xFF111827
    const val onSurface: Long = 0xFFF9FAFB
    const val error:     Long = 0xFFF87171
}
```

> Use `Long` for ARGB — `0xFF3B82F6` overflows signed `Int`. Compose's `Color(value: Long)` accepts this directly.

### Android adapter (Compose)

```kotlin
// androidApp/.../theme/AppTheme.kt
@Composable
fun AppTheme(dark: Boolean = isSystemInDarkTheme(), content: @Composable () -> Unit) {
    val palette = if (dark) DarkColors else LightColors
    MaterialTheme(
        colorScheme = lightColorScheme(
            primary    = Color(palette.primary),
            surface    = Color(palette.surface),
            onSurface  = Color(palette.onSurface),
            error      = Color(palette.error),
        ),
        typography = Typography(
            titleLarge = DesignTokens.Typography.titleLarge.toCompose(),
            bodyLarge  = DesignTokens.Typography.body.toCompose(),
            // …
        ),
        content = content,
    )
}

private fun TextStyleToken.toCompose() = TextStyle(
    fontFamily = FontFamily.Default,           // wire Inter via res/font once bundled
    fontSize   = size.sp,
    fontWeight = FontWeight(weight),
)
```

In a Composable, consume tokens directly for spacing/radius:
```kotlin
Box(Modifier.padding(DesignTokens.Spacing.md.dp)) { /* … */ }
```

### iOS adapter (SwiftUI)

```swift
// iosApp/iosApp/Theme/AppTheme.swift
import SwiftUI
import SkeletonApp   // umbrella XCFramework emitted by :shared-app

enum AppTheme {
    static func color(_ argb: Int64) -> Color {
        let a = Double((argb >> 24) & 0xFF) / 255
        let r = Double((argb >> 16) & 0xFF) / 255
        let g = Double((argb >>  8) & 0xFF) / 255
        let b = Double( argb        & 0xFF) / 255
        return Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    static func font(_ token: TextStyleToken) -> Font {
        Font.custom(DesignTokens.Typography.shared.fontFamily,
                    size: CGFloat(token.size))
            .weight(swiftUIWeight(Int(token.weight)))
    }

    private static func swiftUIWeight(_ v: Int) -> Font.Weight {
        switch v {
        case ..<200: .ultraLight
        case ..<300: .thin
        case ..<400: .light
        case ..<500: .regular
        case ..<600: .medium
        case ..<700: .semibold
        case ..<800: .bold
        case ..<900: .heavy
        default:     .black
        }
    }
}
```

Usage in a SwiftUI view:
```swift
Text("Hello")
    .font(AppTheme.font(DesignTokens.Typography.shared.titleLarge))
    .foregroundStyle(AppTheme.color(LightColors.shared.onSurface))
    .padding(CGFloat(DesignTokens.Spacing.shared.md))
```

> SKIE turns Kotlin `object`s into Swift singletons accessed via `.shared`.

### Light/dark theming

`LightColors` and `DarkColors` live in shared. Each platform decides at runtime which to apply:
- Android: `isSystemInDarkTheme()` inside `AppTheme`
- iOS: read `@Environment(\.colorScheme)` at the root view, pass into `AppTheme.color(...)` selector

### Per-platform escape hatch

Some primitives are platform-native by design — SF Pro on iOS, Roboto/Inter on Android. Two options:

1. **`expect`/`actual` for `fontFamily`** in `shared/` — each platform supplies its preferred family.
2. **Keep `"Inter"` in shared** and let each platform fall back to its system font if the asset isn't bundled. (Simpler; default in this skeleton.)

### Why custom tokens instead of just Material 3 / Apple defaults?

- Material 3 / SF defaults are great starting points; you can build on top of them.
- A custom token layer future-proofs branding: when design ships a refresh, **one** PR in `shared/.../theme/` updates both apps. No drift.

## Tech stack

| Layer            | Choice                              | Notes                                                                         |
|------------------|-------------------------------------|-------------------------------------------------------------------------------|
| Language         | Kotlin 2.x, Swift 5.9+              | Pin versions in `gradle/libs.versions.toml`                                   |
| Shared HTTP      | **Ktor Client**                     | Canonical KMP networking                                                      |
| Shared DB        | **SQLDelight**                      | Battle-tested; alternative: Room-KMP if you prefer Jetpack ergonomics         |
| Shared DI        | **Koin**                            | Lightweight, runtime; alternative: Kotlin-Inject for compile-time safety      |
| Shared async     | Coroutines + StateFlow              | Standard reactive primitives                                                  |
| Serialization    | kotlinx.serialization               | Standard                                                                      |
| Date/time        | kotlinx-datetime                    | KMP-safe replacement for `java.time`                                          |
| Android UI       | Jetpack Compose + Material 3        | Modern Android idiom                                                          |
| Android nav      | Navigation 3                        | Type-safe                                                                     |
| Android image    | Coil 3                              | KMP-capable                                                                   |
| iOS UI           | SwiftUI                             | Native iOS                                                                    |
| iOS nav          | `NavigationStack`                   | Native (iOS 16+)                                                              |
| **iOS interop**  | **SKIE** (Touchlab)                 | Generates idiomatic Swift over Kotlin: enums, `async`, `AsyncSequence`        |
| iOS distribution | Swift Package Manager (SPM)         | CocoaPods is being deprecated for KMP                                         |
| Build            | Gradle KMP plugin                   | Standard                                                                      |
| Tests            | kotlin.test + Kotest / JUnit + Compose UI / XCTest | per-layer                                                      |

## Project layout

```
skeleton/
├─ shared-core/            # KMP — DI, Ktor client, SQLDelight, base repositories, DesignTokens
│  └─ src/{commonMain,commonTest,androidMain,iosMain}/
│     └─ kotlin/dev/viethung/core/
│        ├─ theme/         # DesignTokens, ColorPalette, LightColors, DarkColors (visual primitives)
│        ├─ db/            # SQLDelight driver factory (expect/actual)
│        └─ network/       # Ktor client setup
├─ shared-components/      # KMP — reusable component ViewModels + expect/actual services
│  └─ src/{commonMain,commonTest,androidMain,iosMain}/
├─ shared-app/             # KMP — showcase wiring; emits SkeletonApp.xcframework for iOS
│  └─ src/{commonMain,commonTest,iosMain}/
│     └─ kotlin/dev/viethung/showcase/
│        ├─ di/            # Koin module wiring (AppModule, IosPlatformModule)
│        └─ greeting/      # Example ViewModel + Factory + iOS construction helpers
├─ androidApp/             # Android Compose app
│  └─ src/main/kotlin/dev/viethung/skeleton/android/
│     ├─ theme/            # AppTheme.kt — Compose adapter (DesignTokens → MaterialTheme)
│     └─ greeting/         # GreetingScreen.kt
├─ iosApp/                 # Xcode app (project.yml + generate-xcodeproj.sh source of truth)
│  ├─ project.yml          # XcodeGen spec — defines iosApp + iosAppTests targets
│  ├─ generate-xcodeproj.sh# bootstraps SkeletonApp.xcframework + runs xcodegen
│  ├─ iosApp.xcodeproj/    # generated; do not hand-edit (regenerated from project.yml)
│  ├─ iosApp/              # SwiftUI sources: App/, Common/, Greeting/, Theme/
│  └─ iosAppTests/         # XCTest: AppThemeTests (Color(argb:) alpha-preservation)
├─ server/                 # JVM Ktor stub (push notifications endpoint; build-gated)
├─ build.gradle.kts        # root
├─ settings.gradle.kts     # registers :shared-core, :shared-components, :shared-app, :androidApp, :server
├─ gradle/libs.versions.toml
└─ README.md               # this file
```

## Prerequisites

| Tool         | Version              | Notes                                              |
|--------------|----------------------|----------------------------------------------------|
| JDK          | 21                   | Set `JAVA_HOME`                                    |
| Android SDK  | latest stable        | Set `ANDROID_HOME` / `ANDROID_SDK_ROOT`            |
| Xcode        | 15.4+                | For iOS builds                                     |
| XcodeGen     | 2.45+                | iOS only — generates `iosApp.xcodeproj` from `iosApp/project.yml`. Install: `brew install xcodegen` |
| Kotlin       | pinned in `libs.versions.toml` | Don't drift                              |
| CocoaPods    | not required         | Using SPM                                          |

## Running

```bash
# Android (build & install on connected device/emulator)
./gradlew :androidApp:installDebug

# Shared tests
./gradlew :shared:allTests

# iOS — generate Xcode project (first time + whenever project.yml changes), then open
./iosApp/generate-xcodeproj.sh    # builds SkeletonApp.xcframework + runs xcodegen
open iosApp/iosApp.xcodeproj      # select simulator, ⌘R

# Static analysis (TBD: ktlint / detekt)
./gradlew check
```

## Renaming the skeleton

When forking for a real product, do these find-and-replaces in order. All identifiers were chosen to be uncommon enough that bulk replace is safe.

1. `Skeleton` → `YourApp` — Pascal-case identifiers, Xcode targets/schemes
2. `skeleton` → `yourapp` — Gradle module names, lowercase package paths, Xcode bundle IDs
3. `dev.skeleton` → `com.yourcompany.yourapp` — `namespace`, `applicationId`, iOS bundle prefix
4. Rename the repo directory itself
5. Replace this README with one that describes the real product
6. `rm -rf .git && git init && git add . && git commit -m "Initial commit"`

**Smoke-test after rename:**
```bash
./gradlew :androidApp:assembleDebug
xcodebuild -scheme YourApp -destination 'generic/platform=iOS Simulator' build
```

## Conventions

- **State lives in `shared/`.** UIs project; they don't decide.
- **Visual primitives are tokens, not literals.** Every color, font, size, spacing, and radius value comes from `shared/.../theme/DesignTokens.kt`. No raw `16.dp`, `Color(0xFF...)`, `Font.system(size: 14)` in UI code — those are red flags in code review.
- **No business logic in `androidApp/` or `iosApp/`.** Push it to `shared/` via `expect`/`actual` if it needs platform glue.
- **`gradle/libs.versions.toml` is the single source for every version.** No inline version literals.
- **One commit per logical change.** Many small commits beat one large one.
- **No comments unless the *why* is non-obvious.** Code is the contract.

## Decisions to revisit per real project

These are pinned for the skeleton; reassess when the product domain is concrete:

- **SQLDelight vs Room-KMP.** SQLDelight is more battle-tested in KMP today. Room-KMP is improving and is the natural fit if the rest of the stack is heavily Jetpack-flavored.
- **Koin vs Kotlin-Inject.** Koin starts faster and is more flexible. Kotlin-Inject gives compile-time safety.
- **Navigation 3 vs Decompose.** Navigation 3 keeps nav per-platform (idiomatic). Decompose enables sharing nav *state* across platforms — useful if iOS deep-link logic must mirror Android exactly.
- **CI.** Mac runners on GitHub Actions are ~10× the cost of Linux. For a personal project, consider self-hosting or running iOS only locally.

## TODO before first implementation pass

- [ ] Create `settings.gradle.kts` with `:shared`, `:androidApp` modules
- [ ] Stand up `shared/` with `commonMain` / `androidMain` / `iosMain` source sets
- [ ] Wire SKIE Gradle plugin into `shared/`
- [ ] Implement `shared/.../theme/DesignTokens.kt`, `LightColors`, `DarkColors`
- [ ] Implement `androidApp/.../theme/AppTheme.kt` (Compose adapter)
- [ ] Implement `iosApp/iosApp/Theme/AppTheme.swift` (SwiftUI adapter)
- [ ] Configure Ktor client + a stub `Repository` and `ViewModel`
- [ ] Scaffold `androidApp` Compose entrypoint that subscribes to the stub VM and uses `AppTheme`
- [ ] Scaffold `iosApp` Xcode project, consume `shared` via SPM, render the same VM in SwiftUI with `AppTheme`
- [ ] Write one passing `commonTest` covering the stub VM's state transitions
- [ ] **Token-drift smoke test:** change `Typography.body.size` from `16f` to `18f` in shared, rebuild both apps, confirm both update without further code changes
- [ ] Pick & wire a CI provider (GitHub Actions to start)

## Installation

```bash
git clone https://github.com/<your-username>/skeleton.git
cd skeleton
```

No additional package manager installation step is required — Gradle downloads all dependencies automatically on first build. Ensure `JAVA_HOME` points to JDK 21 and `ANDROID_HOME` is set before running any Gradle task.

## License

MIT License. See [LICENSE](LICENSE) for the full text.
