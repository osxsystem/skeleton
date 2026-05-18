# CLAUDE.md

Behavioral and architectural guidelines for this **Kotlin Multiplatform skeleton**.
Shared Kotlin business logic; native UI per platform (Jetpack Compose on Android, SwiftUI on iOS).

**Tradeoff:** these rules bias toward caution and architectural integrity over speed. Use judgment for trivial tasks.

> **Setup and build commands** live in [`README.md`](README.md). **Architecture rationale, references, and the iOS `IosViewModelStoreOwner` contract** live in [`architecture.md`](architecture.md). When in doubt, those documents are authoritative.

---

## 1. Core Principles

### Think Before Coding
**Don't assume. Don't pick silently. Surface confusion before writing code.**

- State assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them — don't silently pick one.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, name what's confusing. Ask.

### Simplicity First
**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

**Self-check:** "Would a senior engineer say this is overcomplicated?" If yes, simplify.

### Surgical Changes
**Touch only what you must. Clean up only your own mess.**

- Don't improve adjacent code, comments, or formatting.
- Match existing style, even if you'd do it differently.
- Remove imports/variables/functions YOUR change orphaned. Don't delete pre-existing dead code.

**The test:** every changed line traces directly to the user's request.

### Goal-Driven Execution
**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Add a screen" → "Write a `commonTest` for the ViewModel state machine, then wire Compose + SwiftUI projections"

For multi-step work, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
```

---

## 2. Coding Standards

**Project-specific rules. These are load-bearing — violating them breaks the architecture.**

- **State ownership.** Shared `ViewModel`s own state as `StateFlow<UiState>`. Views never mutate state. Events flow up via plain method calls (`onAppear`, `onSubmit(input)`).
- **No platform types in `commonMain`.** Design tokens are primitives only — `Long` for ARGB, `Float`, `Int`. No `androidx.compose.ui.graphics.Color`, no SwiftUI `Color`, no `android.*`, no `UIKit.*`. Those don't compile on the other side.
- **No business logic in `:androidApp` or `:iosApp`.** UI modules wire DI and render state. Push logic into `:shared-core` / `:shared-components` via `expect`/`actual` if it needs platform glue.
- **No raw colors, fonts, sizes, or radii in UI code.** Pull from `shared-core/.../theme/DesignTokens.kt`.
- **`gradle/libs.versions.toml` is the single source for every version.** No inline version literals in module `build.gradle.kts` files.
- **One `ViewModel` per screen.** Cross-screen state lives in a Repository, not a shared VM.
- **Direction of dependency:** UI → ViewModel → Use Case → Repository → Network/DB. Never reverse.
- **No comments unless the *why* is non-obvious.** Code is the contract.

---

## 3. Architecture Overview

**MVVM with a shared `androidx.lifecycle.ViewModel` exposing `StateFlow<UiState>`. Unidirectional data flow.**

```
 androidApp/  (Compose)               iosApp/  (SwiftUI)
    │ collectAsStateWithLifecycle()      │ for await s in vm.state  (SKIE)
    ▼                                    ▼
    ───────────── shared modules (KMP) ─────────────
    ViewModel  →  Use Cases  →  Repository  →  { Ktor, SQLDelight }
                       Koin DI wires the graph.
```

**Modules** (see `settings.gradle.kts`):
- `:shared-core` — DI, Ktor, SQLDelight, base repositories, design tokens.
- `:shared-components` — reusable component ViewModels + `expect`/`actual` services (forms, amount input, sidebar nav, notifications).
- `:shared-app` — showcase wiring; never published.
- `:androidApp` — Jetpack Compose UI.
- `:iosApp` — Xcode project; consumes the shared XCFramework via SPM.
- `:server` — JVM Ktor server stub for push notifications.

Full rationale and references: [`architecture.md`](architecture.md).

---

## 4. Platform Bindings

**The Kotlin↔Swift / Kotlin↔Compose contract. Get this wrong and the build fails or one platform silently drifts.**

### Android (Compose)
```kotlin
@Composable
fun ProfileScreen(viewModel: ProfileViewModel = viewModel()) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    LaunchedEffect(Unit) { viewModel.onAppear() }
    // render based on state
}
```

### iOS (SwiftUI + SKIE)
- iOS has no native `ViewModelStoreOwner`. Use `IosViewModelStoreOwner` (`iosApp/iosApp/Common/IosViewModelStoreOwner.swift`) per Google's KMP ViewModel guide.
- SKIE bridges `StateFlow` to a SwiftUI-friendly `AsyncSequence`. Consume with `for await s in vm.state`.
- `shared-core/build.gradle.kts` must `api(libs.androidx.lifecycle.viewmodel)` **and** `framework { export(...) }` it, so the `ViewModel` type is visible in the iOS framework.

### Design tokens (cross-platform)
- Defined once in `shared-core/.../theme/DesignTokens.kt` as pure primitives.
- Android adapter maps tokens → `MaterialTheme` / `Color(0xFF...)` / `.sp` / `.dp`.
- iOS adapter maps tokens → SwiftUI `Color(.sRGB, ...)` / `Font.custom(...)`.
- Light/dark resolved at the platform root, never in shared.

---

## 5. Testing

- **Shared logic:** `kotlin.test` + `kotest-assertions-core` + **Turbine** for `StateFlow`.
- **Every `ViewModel` needs a `commonTest`** driving the state machine through Loading → Ready → Error.
- **Android UI:** Compose UI tests (instrumented).
- **iOS UI:** XCTest.
- **Targeted before broad.** Run the most local test first; broaden only if it passes or a regression is suspected.

```bash
./gradlew :shared-core:allTests              # shared tests across KMP targets
./gradlew :shared-components:allTests
./gradlew :androidApp:connectedAndroidTest   # Android instrumented
# iOS: ⌘U in Xcode
```

---

## 6. Development Workflow

**Safety:**
- Ask before destructive ops (delete files, force push, reset, DB drop, mass-rename).
- Never commit, push, open PRs, or call external services unless explicitly asked.

**Tooling:**
- Prefer dedicated tools: Read > cat, Edit > sed, Grep/Glob > find.
- Issue parallel tool calls when independent.
- Reference code as `path:line`.
- List changed files in every final response.

**Validation cadence per change:**
1. Edit → 2. Targeted test → 3. Module test → 4. Cross-platform smoke (`./gradlew check`) only if you touched shared API surface.

---

## 7. Setup & Build

Full instructions in [`README.md`](README.md) (Prerequisites, Running, Renaming).

Common commands:
```bash
./gradlew :androidApp:installDebug   # Android: build & install on device/emulator
./gradlew :shared-core:allTests      # Shared tests across all KMP targets
./gradlew check                      # Static analysis
open iosApp/iosApp.xcodeproj         # iOS: open in Xcode, ⌘R
```

Prerequisites: **JDK 21**, Android SDK, **Xcode 16+**. Versions are pinned in `gradle/libs.versions.toml` — don't drift.

---

**These guidelines are working if:** state-ownership is never violated, no platform types leak into `commonMain`, diffs trace cleanly to the request, and clarifying questions come before implementation rather than after mistakes.
