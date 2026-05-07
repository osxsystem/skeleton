# Architecture

**Status:** Accepted
**Date:** 2026-05-07
**Owner:** Do Viet Hung
**Companion to:** `README.md`, `compose-multiplatform-core/` (read-only reference for AndroidX / Compose libraries)

---

## TL;DR

- The project is a **Kotlin Multiplatform (KMP)** skeleton: shared Kotlin business logic, native UI per platform (Jetpack Compose on Android, SwiftUI on iOS).
- The pattern is **MVVM with a shared `ViewModel`** built on `StateFlow`, following **unidirectional data flow (UDF)**. This matches the *official* JetBrains and Google guidance for KMP — see references at the bottom.
- C/C++ is out of scope for this project.

---

## Goals & Non-Goals

**Goals**
- One source of truth for state and business rules.
- Native, idiomatic UI on Android and iOS.
- Stay aligned with the official AndroidX / Kotlin Multiplatform guidance so future contributors and AI tools recognize the patterns immediately.

**Non-Goals**
- Sharing UI code (no Compose Multiplatform for iOS UI).
- Building a C/C++ shared core.
- Designing for a third platform today (KMP keeps that door open without us paying for it now).

---

## High-level architecture

```mermaid
flowchart TB
    subgraph Android["androidApp/  (Jetpack Compose)"]
        AC["@Composable screens<br/>(View)"]
        AC -->|collectAsStateWithLifecycle| SharedVM
    end

    subgraph iOS["iosApp/  (SwiftUI)"]
        SC["SwiftUI Views<br/>(View)"]
        SC -->|@StateObject IosViewModelStoreOwner<br/>SKIE-bridged StateFlow| SharedVM
    end

    subgraph Shared["shared/  (KMP — commonMain)"]
        SharedVM["ViewModel<br/>androidx.lifecycle.ViewModel<br/>StateFlow&lt;UiState&gt;"]
        UC["Use Cases"]
        Repo["Repositories"]
        Net["Networking · Ktor"]
        DB["Persistence · SQLDelight"]
        DI["DI · Koin"]
        Tokens["Design Tokens"]

        SharedVM --> UC --> Repo
        Repo --> Net
        Repo --> DB
        DI -.wires.-> SharedVM
        DI -.wires.-> Repo
        Tokens -.consumed by both UIs.-> AC
        Tokens -.consumed by both UIs.-> SC
    end
```

The shape is the same as `README.md`'s diagram; this document fixes the pattern and the libraries.

---

## The Pattern: MVVM with shared ViewModel

This is the **single chosen pattern** for the project. We do not entertain alternatives in this skeleton; if a future use case strains MVVM, that's a separate ADR.

**Rationale (grounded in official docs):**

- JetBrains documents [Common ViewModel](https://kotlinlang.org/docs/multiplatform/compose-viewmodel.html) as the way to build UI in shared KMP code: a `ViewModel` defined in `commonMain` exposes `StateFlow<UiState>` and is consumed by Compose on Android and SwiftUI on iOS.
- Google's Android Developers site has an explicit [Set up ViewModel for KMP](https://developer.android.com/kotlin/multiplatform/viewmodel) guide that describes the AndroidX `ViewModel` as *"a bridge, establishing a clear contract between your shared business logic and your UI components."* The official sample is [Fruitties](https://github.com/android/kotlin-multiplatform-samples/tree/main/Fruitties).
- Google's [Android architecture recommendations](https://developer.android.com/topic/architecture/recommendations) mandate `ViewModel` + `StateFlow` + unidirectional data flow as the canonical UI-layer pattern.

**Concrete contract for this skeleton:**

1. Each screen has exactly one `ViewModel` class in `shared/commonMain/.../ui/<feature>/`.
2. The `ViewModel` extends `androidx.lifecycle.ViewModel` (the artifact is KMP-capable in 2.8.0+ — we pin 2.10.0).
3. State is exposed as `val state: StateFlow<UiState>` where `UiState` is a `sealed interface`.
4. Events flow up: the View calls plain methods on the `ViewModel` (`onAppear`, `onSubmit(input)`); the View never mutates state.
5. The `ViewModel` never knows the View exists — no callbacks, no view interfaces.

### Required dependencies (`gradle/libs.versions.toml`)

```toml
[versions]
androidx-lifecycle = "2.10.0"

[libraries]
androidx-lifecycle-viewmodel = { module = "androidx.lifecycle:lifecycle-viewmodel", version.ref = "androidx-lifecycle" }
```

### `shared/build.gradle.kts`

```kotlin
kotlin {
    sourceSets {
        commonMain.dependencies {
            // `api` so the type is visible in the iOS framework.
            api(libs.androidx.lifecycle.viewmodel)
        }
    }

    listOf(iosX64(), iosArm64(), iosSimulatorArm64()).forEach {
        it.binaries.framework {
            baseName = "shared"
            export(libs.androidx.lifecycle.viewmodel)   // expose ViewModel APIs to Swift
        }
    }
}
```

### Canonical ViewModel (commonMain)

```kotlin
// shared/src/commonMain/kotlin/dev/skeleton/ui/profile/ProfileViewModel.kt
package dev.skeleton.ui.profile

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

class ProfileViewModel(
    private val loadProfile: LoadProfileUseCase,
) : ViewModel() {

    private val _state = MutableStateFlow<UiState>(UiState.Loading)
    val state: StateFlow<UiState> = _state.asStateFlow()

    fun onAppear(userId: String) {
        viewModelScope.launch {
            _state.value = UiState.Loading
            _state.value = runCatching { loadProfile(userId) }.fold(
                onSuccess = { UiState.Ready(it) },
                onFailure = { UiState.Error(it.message ?: "Unknown error") },
            )
        }
    }

    sealed interface UiState {
        data object Loading : UiState
        data class Ready(val profile: Profile) : UiState
        data class Error(val message: String) : UiState
    }
}
```

### Android consumer (Compose)

```kotlin
@Composable
fun ProfileScreen(viewModel: ProfileViewModel = viewModel()) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    LaunchedEffect(Unit) { viewModel.onAppear(userId = "me") }
    when (val s = state) {
        ProfileViewModel.UiState.Loading -> CircularProgressIndicator()
        is ProfileViewModel.UiState.Ready -> ProfileContent(s.profile)
        is ProfileViewModel.UiState.Error -> ErrorBanner(s.message)
    }
}
```

### iOS consumer (SwiftUI)

iOS does not own a `ViewModelStoreOwner` natively. We follow the [official Google sample's approach](https://developer.android.com/kotlin/multiplatform/viewmodel#use-viewmodel-from-swiftui): an `IosViewModelStoreOwner` that conforms to both `ObservableObject` and `ViewModelStoreOwner`, plus SKIE to bridge `StateFlow` to a SwiftUI-friendly `AsyncSequence`.

```swift
// iosApp/iosApp/Profile/ProfileScreen.swift
import SwiftUI
import shared

struct ProfileScreen: View {
    @StateObject private var owner = IosViewModelStoreOwner()
    @State private var uiState: ProfileViewModelUiState = .loading

    var body: some View {
        let vm: ProfileViewModel = owner.viewModel(factory: ProfileViewModelFactoryKt.profileViewModelFactory)
        Group {
            switch uiState {
            case .loading:        ProgressView()
            case .ready(let p):   ProfileContent(profile: p)
            case .error(let msg): ErrorBanner(message: msg)
            }
        }
        .task {
            vm.onAppear(userId: "me")
            for await s in vm.state {        // SKIE bridges StateFlow → AsyncSequence
                uiState = s
            }
        }
    }
}
```

`IosViewModelStoreOwner` is implemented exactly as in [Google's KMP ViewModel guide](https://developer.android.com/kotlin/multiplatform/viewmodel#use-viewmodel-from-swiftui).

---

## Layering rules

1. **Direction of dependency:** UI → ViewModel → Use Case → Repository → (Network / DB). Never reverse.
2. **`commonMain` knows nothing about `android.*` or `UIKit`.** Add an `expect`/`actual` if shared code needs platform glue.
3. **No business logic in `androidApp/` or `iosApp/`.** Those modules wire DI and render state.
4. **No raw colors, fonts, or sizes in UI code.** Pull from `shared/.../theme/DesignTokens.kt`.
5. **One ViewModel per screen.** Cross-screen state lives in a Repository.
6. **State down, events up** (UDF). Views never mutate `_state`.

---

## Tech stack

Choices are pinned by the official KMP guidance referenced below.

| Layer | Choice | Source of authority |
|---|---|---|
| Shared language | Kotlin (KMP) | kotlinlang.org/docs/multiplatform |
| Shared UI-layer pattern | **MVVM with `androidx.lifecycle.ViewModel`** | developer.android.com/kotlin/multiplatform/viewmodel |
| Shared state primitive | `StateFlow<UiState>` + UDF | developer.android.com/topic/architecture/ui-layer/state-production |
| Shared HTTP | Ktor Client | KMP-canonical |
| Shared DB | SQLDelight (or Room-KMP) | developer.android.com/kotlin/multiplatform/room |
| Shared DI | **Koin** (Hilt is *not* KMP-compatible — official note) | developer.android.com/kotlin/multiplatform/viewmodel |
| Android UI | Jetpack Compose + Material 3 | Compose docs |
| iOS UI | SwiftUI | — |
| iOS Flow interop | **SKIE** (or KMP-NativeCoroutines) | developer.android.com/kotlin/multiplatform/viewmodel |
| iOS ViewModel host | `IosViewModelStoreOwner` per Google sample | developer.android.com/kotlin/multiplatform/viewmodel |
| Build | Gradle KMP plugin | kotlinlang.org |

> **Why not Hilt?** Google's KMP ViewModel guide explicitly says: *"Hilt is not available for Kotlin Multiplatform projects, you can't directly use ViewModels with `@HiltViewModel` annotation in `commonMain`. In that case you need to use some alternative DI framework, for example, Koin..."* We use Koin.

---

## Project layout (relevant slice)

```
skeleton/
├─ shared/                            # KMP module
│  └─ src/commonMain/kotlin/dev/skeleton/
│     ├─ ui/<feature>/                # ViewModel + UiState  (one folder per screen)
│     ├─ domain/usecases/             # business rules
│     ├─ data/                        # repositories, network, persistence
│     ├─ di/                          # Koin modules
│     └─ theme/                       # design tokens
├─ androidApp/                        # Compose; depends on :shared
├─ iosApp/                            # Xcode project; consumes the shared framework via SPM
│  └─ iosApp/Common/IosViewModelStoreOwner.swift
├─ compose-multiplatform-core/        # READ-ONLY reference. Source of AndroidX / Compose libs.
├─ README.md
└─ architecture.md                    # this file
```

---

## Relationship to `compose-multiplatform-core/`

That tree is the JetBrains fork of AndroidX — the upstream source for `lifecycle`, `compose-runtime`, `navigation`, `room`, `paging`. It is checked out locally for **reference only**; we depend on the published Maven artifacts, not the source.

Useful entry points:

- `compose-multiplatform-core/lifecycle/` — the AndroidX `ViewModel` source we extend.
- `compose-multiplatform-core/compose/runtime/` — the recomposition engine that powers `collectAsStateWithLifecycle()`.
- `compose-multiplatform-core/navigation/` — Navigation 3 (typed routes).
- `compose-multiplatform-core/MULTIPLATFORM.md` — JetBrains' KMP setup notes.

Rule: don't import from this tree. Pin versions in `gradle/libs.versions.toml`.

---

## Action items

1. [ ] Add `androidx-lifecycle-viewmodel = "2.10.0"` to `gradle/libs.versions.toml`.
2. [ ] Wire it into `shared/build.gradle.kts` with `api(...)` and `framework { export(...) }`.
3. [ ] Create `shared/.../ui/profile/ProfileViewModel.kt` from the template above.
4. [ ] Wire SKIE into `shared/` so `StateFlow` bridges to `AsyncSequence` in Swift.
5. [ ] Add `iosApp/iosApp/Common/IosViewModelStoreOwner.swift` per the Google sample.
6. [ ] Stand up Koin modules in `shared/.../di/Modules.kt` and call `startKoin` from both apps.
7. [ ] Implement one Compose screen and one SwiftUI screen consuming the same `ProfileViewModel`; assert state stays in sync.
8. [ ] Write a `commonTest` driving `ProfileViewModel` through `Loading → Ready → Error`.
9. [ ] Pin Kotlin / AndroidX / Compose versions in `libs.versions.toml`. Don't drift.

---

## What changed in this revision

- **Renamed file** `achitecture.md` → `architecture.md`.
- **Removed the MVVM-vs-MVP comparison.** MVVM with shared `ViewModel` is the *officially endorsed* pattern from both JetBrains and Google for KMP; this is the only path the skeleton supports.
- **Added concrete library coordinates** (`androidx.lifecycle:lifecycle-viewmodel:2.10.0`) and `framework { export(...) }` setup, matching Google's guide.
- **Added the iOS-specific contract** (`IosViewModelStoreOwner` + SKIE) referenced from the official sample, instead of hand-waving "consume via SKIE".
- **Pinned DI to Koin** with the explicit reason from Google's docs (Hilt is not KMP-compatible).

---

## References (official sources)

1. [Common ViewModel — Kotlin Multiplatform Documentation (kotlinlang.org)](https://kotlinlang.org/docs/multiplatform/compose-viewmodel.html)
2. [Set up ViewModel for KMP — Android Developers (developer.android.com)](https://developer.android.com/kotlin/multiplatform/viewmodel)
3. [Recommendations for Android architecture — Android Developers](https://developer.android.com/topic/architecture/recommendations)
4. [UI layer / State production — Android Developers](https://developer.android.com/topic/architecture/ui-layer/state-production)
5. [StateFlow and SharedFlow — Android Developers](https://developer.android.com/kotlin/flow/stateflow-and-sharedflow)
6. [Get started with Kotlin Multiplatform — kotlinlang.org](https://kotlinlang.org/docs/multiplatform/get-started.html)
7. [Fruitties sample — official Google KMP sample (github.com/android)](https://github.com/android/kotlin-multiplatform-samples/tree/main/Fruitties)
8. [SKIE — Kotlin↔Swift bridge (touchlab.co)](https://skie.touchlab.co/)
