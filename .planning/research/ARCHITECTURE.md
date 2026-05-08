# Architecture Research

**Domain:** KMP skeleton — reusable native UI component library (Compose + SwiftUI)
**Researched:** 2026-05-08
**Confidence:** HIGH (module layout, component contract, build order); MEDIUM (navigation state ownership, notification architecture)

---

## Standard Architecture

### System Overview

```
┌──────────────────────────────────────────────────────────────────────┐
│  androidApp/  (Jetpack Compose)                                       │
│  ┌─────────────┐  ┌──────────────┐  ┌────────────┐  ┌────────────┐   │
│  │ FormField   │  │ AmountInput  │  │ NavDrawer  │  │ Notification│  │
│  │ (Composable)│  │ (Composable) │  │(Composable)│  │ (Composable)│  │
│  └──────┬──────┘  └──────┬───────┘  └─────┬──────┘  └─────┬──────┘  │
│         │  state: FormUiState  etc.        │               │          │
│         └──────────────────┬──────────────┘               │          │
│                            │   collectAsStateWithLifecycle │          │
└────────────────────────────┼──────────────────────────────┼──────────┘
                             │                              │
┌────────────────────────────┼──────────────────────────────┼──────────┐
│  iosApp/  (SwiftUI)        │                              │           │
│  ┌─────────────┐  ┌────────┴──────┐  ┌─────────────┐  ┌──┴─────────┐ │
│  │ FormField   │  │ AmountInput   │  │  NavDrawer  │  │Notification│ │
│  │ (SwiftUI)   │  │ (SwiftUI)     │  │  (SwiftUI)  │  │ (SwiftUI)  │ │
│  └──────┬──────┘  └──────┬────────┘  └──────┬──────┘  └─────┬──────┘ │
│         │  for await s in vm.state (SKIE AsyncSequence)      │        │
└─────────┼──────────────────────────────────────────────────-─┼────────┘
          │                                                     │
┌─────────┴─────────────────────────────────────────────────── ┴────────┐
│  :shared-components  (KMP commonMain)                                  │
│  ┌─────────────┐  ┌──────────────┐  ┌────────────┐  ┌──────────────┐  │
│  │ FormVM      │  │ AmountInputVM│  │ NavDrawerVM│  │Notification  │  │
│  │ FormUiState │  │ AmountUiState│  │ NavUiState │  │  VM + Queue  │  │
│  │ FormIntent  │  │ AmountIntent │  │ NavIntent  │  │  UiState     │  │
│  └─────────────┘  └──────────────┘  └────────────┘  └──────────────┘  │
├────────────────────────────────────────────────────────────────────────┤
│  :shared-core  (KMP commonMain)                                        │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌────────────┐             │
│  │DesignTokens│ │  Koin DI │  │  Ktor    │  │ SQLDelight │             │
│  │LightColors │ │  Modules │  │  Client  │  │            │             │
│  │DarkColors  │ │          │  │          │  │            │             │
│  └──────────┘  └──────────┘  └──────────┘  └────────────┘             │
└────────────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Lives In |
|-----------|---------------|----------|
| `DesignTokens` | ARGB Long / Float / Int primitives only | `:shared-core/commonMain` |
| `FormViewModel` | Field state, validation rules, submission intent processing | `:shared-components/commonMain` |
| `AmountInputViewModel` | Locale + currency formatting, decimal input state | `:shared-components/commonMain` |
| `NavDrawerViewModel` | Route tree data, expanded-group state, current route | `:shared-components/commonMain` |
| `NotificationViewModel` | In-app queue (toasts, banners, snackbars, inline alerts) | `:shared-components/commonMain` |
| `NotificationService` | expect/actual — platform registration (FCM/APNs), token surfacing | `:shared-components/commonMain` (expect) + platform actuals |
| `AppViewModel` / showcase VMs | Showcase-specific orchestration, demo data loading | `:shared-app/commonMain` |
| `AppTheme` (Android) | Maps shared tokens → MaterialTheme + ColorScheme | `androidApp/` |
| `AppTheme` (iOS) | Maps shared tokens → SwiftUI Color / Font env values | `iosApp/` |
| `FormField` (Compose) | Renders `FormUiState`, fires `FormIntent` | `androidApp/` |
| `FormField` (SwiftUI) | Renders `FormUiState`, fires `FormIntent` | `iosApp/` |

---

## Recommended Project Structure

### Gradle Module Diagram

```
skeleton/
├── settings.gradle.kts                 ← includes all modules
├── gradle/
│   └── libs.versions.toml             ← single version catalog
├── build-logic/
│   └── convention/                    ← shared convention plugins
│       ├── KmpLibraryPlugin.kt
│       └── KmpAppPlugin.kt
│
├── shared-core/                        ← :shared-core  (KMP lib)
│   └── src/commonMain/kotlin/dev/skeleton/
│       ├── theme/                      ← DesignTokens, LightColors, DarkColors
│       ├── di/                         ← CoreKoinModule (Ktor, SQLDelight, base repos)
│       ├── data/                       ← repositories, network, persistence
│       └── domain/                     ← use cases, models
│
├── shared-components/                  ← :shared-components  (KMP lib)
│   └── src/
│       ├── commonMain/kotlin/dev/skeleton/components/
│       │   ├── form/
│       │   │   ├── FormViewModel.kt
│       │   │   ├── FormUiState.kt
│       │   │   ├── FormIntent.kt
│       │   │   └── FormField.kt        ← validation helpers, field model
│       │   ├── amount/
│       │   │   ├── AmountInputViewModel.kt
│       │   │   ├── AmountInputUiState.kt
│       │   │   └── AmountInputIntent.kt
│       │   ├── nav/
│       │   │   ├── NavDrawerViewModel.kt
│       │   │   ├── NavDrawerUiState.kt  ← route tree, expanded nodes, current route
│       │   │   └── NavIntent.kt
│       │   └── notification/
│       │       ├── NotificationViewModel.kt
│       │       ├── NotificationUiState.kt  ← in-app queue
│       │       ├── NotificationIntent.kt
│       │       └── NotificationService.kt  ← expect class
│       ├── androidMain/
│       │   └── notification/NotificationService.android.kt  ← FCM actual
│       └── iosMain/
│           └── notification/NotificationService.ios.kt      ← APNs actual
│
├── shared-app/                         ← :shared-app  (KMP lib, showcase-only)
│   └── src/commonMain/kotlin/dev/skeleton/showcase/
│       ├── di/                         ← AppKoinModule wiring showcase VMs
│       └── ui/                         ← showcase-specific screen VMs
│
├── androidApp/                         ← :androidApp  (Android app)
│   └── src/main/
│       ├── theme/AppTheme.kt           ← Compose adapter for DesignTokens
│       ├── components/
│       │   ├── form/FormField.kt       ← @Composable, stateless
│       │   ├── amount/AmountInputField.kt
│       │   ├── nav/NavDrawer.kt
│       │   └── notification/NotificationHost.kt
│       └── showcase/                   ← screen Composables wired to shared-app VMs
│
└── iosApp/                             ← Xcode project
    ├── iosApp/
    │   ├── Theme/AppTheme.swift
    │   ├── Common/IosViewModelStoreOwner.swift
    │   ├── Components/
    │   │   ├── Form/FormField.swift
    │   │   ├── Amount/AmountInputField.swift
    │   │   ├── Nav/NavDrawer.swift
    │   │   └── Notification/NotificationHost.swift
    │   └── Showcase/                   ← SwiftUI screens for showcase
    └── Package.swift                   ← consumes shared framework via SPM
```

### Gradle `settings.gradle.kts` wireframe

```kotlin
// settings.gradle.kts
rootProject.name = "skeleton"
include(
    ":shared-core",
    ":shared-components",
    ":shared-app",
    ":androidApp",
)
// iosApp is an Xcode project; it consumes the shared framework via SPM, not Gradle includes
```

### `:shared-components/build.gradle.kts` wireframe

```kotlin
plugins {
    id("dev.skeleton.kmp-library")  // convention plugin
    id("co.touchlab.skie")
}

kotlin {
    androidTarget()
    listOf(iosX64(), iosArm64(), iosSimulatorArm64()).forEach {
        it.binaries.framework {
            baseName = "shared"          // single framework name — umbrella pattern
            export(project(":shared-core"))
            export(libs.androidx.lifecycle.viewmodel)
        }
    }
    sourceSets {
        commonMain.dependencies {
            api(project(":shared-core"))  // api: types flow through to consumers
            api(libs.androidx.lifecycle.viewmodel)
            implementation(libs.kotlinx.coroutines.core)
        }
    }
}
```

### `:androidApp/build.gradle.kts` wireframe

```kotlin
plugins { id("dev.skeleton.kmp-app") }

dependencies {
    implementation(project(":shared-app"))    // brings shared-components + shared-core transitively
    implementation(libs.compose.ui)
    implementation(libs.material3)
}
```

**Why not a single flat `:shared` module?**

Splitting into `:shared-core` + `:shared-components` + `:shared-app` gives three benefits:
1. **Independent publish**: `:shared-core` and `:shared-components` are the library; `:shared-app` is showcase-only and never published.
2. **Build cache**: editing a form ViewModel does not invalidate the Ktor/SQLDelight build cache.
3. **Explicit boundary**: showcase VMs that have no business being in the published library are physically prevented from entering it.

The Umbrella pattern (confirmed by JetBrains official docs) is maintained: Android can depend on `:shared-app` which chains `:shared-components` → `:shared-core`. iOS gets **one** framework compiled from the umbrella to avoid type-duplication issues.

---

## Architectural Patterns

### Pattern 1: Screen-level ViewModel + Component-level Plain State Holder (Canonical)

**What:** The `ViewModel` in `commonMain` owns business-logic state (form submission, server calls). Reusable UI components (the `FormField` Composable / SwiftUI View) receive *already-reduced* `UiState` and fire *typed Intents* — they hold no ViewModel reference.

**When to use:** Every component in this library.

**Why:** Official Android docs are explicit: "Don't use ViewModels as state holders of reusable UI components such as chip groups or forms." Two instances of the same Composable under the same `ViewModelStoreOwner` receive the same VM instance, causing shared state bugs. The pattern below avoids this entirely.

**Contract:**

```
commonMain ─────────────────────────────────────────────────────────
  FormViewModel              (ViewModel, screen-scoped)
    state: StateFlow<FormUiState>
    fun onIntent(intent: FormIntent)

  FormUiState                (sealed interface, plain data)
    Loading / Ready(fields: List<FieldState>, isSubmitting: Boolean) / Error(msg)

  FormIntent                 (sealed interface)
    FieldChanged(id: String, value: String)
    Submit
    Reset

  FieldState                 (data class, plain data — NOT a ViewModel)
    id, label, value, error: String?, isValid: Boolean
─────────────────────────────────────────────────────────────────────
androidApp ──────────────────────────────────────────────────────────
  @Composable
  fun FormField(
      state: FormViewModel.FormUiState,  // state down
      onIntent: (FormIntent) -> Unit     // events up
  )
  // Usage at screen level:
  val uiState by vm.state.collectAsStateWithLifecycle()
  FormField(state = uiState, onIntent = vm::onIntent)
─────────────────────────────────────────────────────────────────────
iosApp ──────────────────────────────────────────────────────────────
  struct FormField: View {
      let state: FormViewModelFormUiState   // SKIE-generated Swift type
      let onIntent: (FormIntent) -> Void
      var body: some View { ... }
  }
  // Usage at screen level:
  FormField(state: uiState, onIntent: { vm.onIntent(intent: $0) })
─────────────────────────────────────────────────────────────────────
```

### Pattern 2: expect/actual for Platform Services

**What:** Anything that requires a platform SDK — notification permission, token registration, locale number formatting — is an `expect class` in `commonMain` with `actual` implementations in `androidMain` and `iosMain`.

**When to use:** `NotificationService`, `CurrencyFormatter`, any platform-specific sensor/capability.

**Example (notification service):**

```kotlin
// shared-components/commonMain
expect class NotificationService {
    fun requestPermission(onResult: (Boolean) -> Unit)
    suspend fun getToken(): String
    fun onNewToken(callback: (String) -> Unit)
}

// shared-components/androidMain
actual class NotificationService actual constructor() {
    actual fun requestPermission(onResult: (Boolean) -> Unit) { /* Android runtime permission */ }
    actual suspend fun getToken(): String = FirebaseMessaging.getInstance().token.await()
    actual fun onNewToken(callback: (String) -> Unit) { /* FCM service wires this */ }
}

// shared-components/iosMain
actual class NotificationService actual constructor() {
    actual fun requestPermission(onResult: (Boolean) -> Unit) { /* UNUserNotificationCenter */ }
    actual suspend fun getToken(): String = suspendCoroutine { /* APNs / Messaging.messaging() */ }
    actual fun onNewToken(callback: (String) -> Unit) { /* store callback, called from AppDelegate */ }
}
```

### Pattern 3: Design-Token Adapter (no cross-module type leakage)

**What:** `DesignTokens` in `:shared-core/commonMain` uses only `Long`, `Float`, `Int`. Platform adapters in `androidApp/` and `iosApp/` convert these primitives to `Color(Long)`, `TextStyle`, `CGFloat`, `SwiftUI.Color`. Token types never cross the KMP/native boundary as composed types.

**When to use:** All visual primitives — colors, typography, spacing, radius, animation duration.

**Trade-off:** The `AppTheme` adapter must be updated in two places when a new token category is added. Acceptable cost for a 2-platform project; an `expect`/`actual` for `fontFamily` is the only escape hatch needed for platform-specific fonts.

---

## Worked Example: Forms End-to-End

### commonMain

```kotlin
// shared-components/src/commonMain/.../form/FormViewModel.kt
class FormViewModel(
    private val submitForm: SubmitFormUseCase,   // lives in :shared-core
) : ViewModel() {

    private val _state = MutableStateFlow<FormUiState>(FormUiState.Loading)
    val state: StateFlow<FormUiState> = _state.asStateFlow()

    fun onIntent(intent: FormIntent) {
        when (intent) {
            is FormIntent.FieldChanged -> updateField(intent.id, intent.value)
            FormIntent.Submit          -> submit()
            FormIntent.Reset           -> _state.value = FormUiState.Loading
        }
    }

    private fun updateField(id: String, value: String) {
        val current = _state.value as? FormUiState.Ready ?: return
        val updated = current.fields.map { f ->
            if (f.id == id) f.copy(value = value, error = validate(f.id, value))
            else f
        }
        _state.value = current.copy(fields = updated)
    }

    private fun submit() {
        val current = _state.value as? FormUiState.Ready ?: return
        viewModelScope.launch {
            _state.value = current.copy(isSubmitting = true)
            runCatching { submitForm(current.fields) }.fold(
                onSuccess = { _state.value = FormUiState.Success },
                onFailure = { _state.value = FormUiState.Error(it.message ?: "Unknown") },
            )
        }
    }
}

sealed interface FormUiState {
    data object Loading : FormUiState
    data class Ready(
        val fields: List<FieldState>,
        val isSubmitting: Boolean = false,
    ) : FormUiState
    data object Success : FormUiState
    data class Error(val message: String) : FormUiState
}

data class FieldState(
    val id: String,
    val label: String,
    val value: String = "",
    val error: String? = null,
    val isRequired: Boolean = true,
)

sealed interface FormIntent {
    data class FieldChanged(val id: String, val value: String) : FormIntent
    data object Submit : FormIntent
    data object Reset : FormIntent
}
```

### Android (Compose)

```kotlin
// androidApp/.../components/form/FormField.kt
@Composable
fun FormField(
    state: FormUiState,
    onIntent: (FormIntent) -> Unit,
    modifier: Modifier = Modifier,
) {
    when (state) {
        FormUiState.Loading  -> CircularProgressIndicator()
        is FormUiState.Ready -> ReadyForm(state, onIntent, modifier)
        FormUiState.Success  -> SuccessBanner()
        is FormUiState.Error -> ErrorBanner(state.message)
    }
}

// Screen wires it:
@Composable
fun ProfileFormScreen(vm: FormViewModel = viewModel()) {
    val state by vm.state.collectAsStateWithLifecycle()
    FormField(state = state, onIntent = vm::onIntent)
}
```

### iOS (SwiftUI)

```swift
// iosApp/Components/Form/FormField.swift
struct FormField: View {
    let state: FormViewModelFormUiState    // SKIE generates this name
    let onIntent: (FormIntent) -> Void

    var body: some View {
        switch onEnum(of: state) {        // SKIE onEnum helper
        case .loading:           ProgressView()
        case .ready(let s):      ReadyFormView(state: s, onIntent: onIntent)
        case .success:           SuccessBannerView()
        case .error(let e):      ErrorBannerView(message: e.message)
        }
    }
}

// Screen wires it:
struct ProfileFormScreen: View {
    @StateObject private var owner = IosViewModelStoreOwner()
    @State private var uiState: FormViewModelFormUiState = .loading

    var body: some View {
        let vm: FormViewModel = owner.viewModel(factory: FormViewModelFactoryKt.formViewModelFactory)
        FormField(state: uiState, onIntent: { vm.onIntent(intent: $0) })
            .task {
                for await s in vm.state { uiState = s }
            }
    }
}
```

---

## Data Flow Diagrams

### Push Notification → Shared State → Compose + SwiftUI Render

```
Platform layer (device OS)
  │  FCM (Android) / APNs (iOS) delivers push payload
  │
  ▼
Platform-specific entry point
  Android: FirebaseMessagingService.onMessageReceived()
  iOS:     AppDelegate.application(_:didReceiveRemoteNotification:)
  │
  │  calls NotificationService.actual.onNewToken(token)
  │          OR dispatches InAppNotification to shared queue
  ▼
:shared-components — NotificationViewModel (commonMain)
  │  _state.value = current.copy(queue = queue + newNotification)
  │  StateFlow<NotificationUiState> emits new value
  ▼
Both platforms observe simultaneously:
  Android: NotificationHost @Composable
           val state by notifVm.state.collectAsStateWithLifecycle()
           → renders Snackbar / Banner overlay
  iOS:     NotificationHost SwiftUI View
           for await s in notifVm.state → updates @State uiState
           → renders sheet / overlay modifier

Token registration sub-flow:
  Android: NotificationService.android.kt → FirebaseMessaging.getToken()
           → NotificationViewModel.onTokenRefresh(token)
           → RegisterTokenUseCase (in :shared-core) → Ktor POST /api/tokens
  iOS:     AppDelegate sets apnsToken on Messaging, then FCM SDK calls
           MessagingDelegate.messaging(_:didReceiveRegistrationToken:)
           → NotificationService.ios.kt callback → same shared flow
```

### Form Submit Data Flow

```
User types in field
  ↓
FormField (Compose / SwiftUI) fires FormIntent.FieldChanged("email", "...")
  ↓
FormViewModel.onIntent() in commonMain
  ↓
validate(fieldId, value) → updates FieldState.error in-place
  ↓
_state.value updated → StateFlow emits FormUiState.Ready(fields=[...])
  ↓
Both UIs recompose/re-render with inline error display

User taps Submit
  ↓
FormIntent.Submit → viewModelScope.launch { SubmitFormUseCase }
  ↓
isSubmitting = true → both UIs show loading indicator
  ↓
UseCase → Repository → Ktor HTTP call
  ↓
Success → FormUiState.Success   |   Failure → FormUiState.Error
  ↓
Both UIs render success / error state
```

---

## Dimension-by-Dimension Decisions

### 1. Module Layout Decision

**Decision: Three KMP modules — `:shared-core`, `:shared-components`, `:shared-app`**

Rationale:
- `:shared-core` holds what any product built on this skeleton needs: DI scaffold, Ktor client, SQLDelight, design tokens. It has zero component VMs.
- `:shared-components` holds the four component families plus their `expect`/`actual` platform services. It depends on `:shared-core` via `api` (types flow through).
- `:shared-app` is the showcase-only wiring layer — screen-level VMs, demo data, Koin module that registers everything. It is never published.
- iOS sees a **single umbrella framework** (`baseName = "shared"`) compiled from `:shared-components`, which pulls `:shared-core` via `api` + `export`. This avoids the JetBrains-documented type-duplication problem where the same `FieldState` class becomes two incompatible types if two separate frameworks both embed `:shared-core`.

**Rejected: flat single `:shared` module**
A flat module works for a small app but violates the library-vs-showcase boundary: it makes it impossible to publish the component library without also publishing showcase-specific code. Once any showcase VM leaks into the published artifact, adopters get unnecessary dependencies.

### 2. Component Shape

**Decision: `FormViewModel` (screen-level ViewModel in commonMain) + stateless `FormField` (platform UI)**

The Android Architecture guide is explicit that ViewModels should not be used as state holders for reusable components. The correct pattern is:
- `FormViewModel` lives at the **screen** scope (one per screen, scoped to `ViewModelStoreOwner`).
- `FormField` Composable / SwiftUI View is **stateless** — receives `FormUiState` and fires `FormIntent`.
- If a single screen has two independent form sections, each gets its own `FormViewModel` instance created with a distinct key via `viewModel(key = "section1")`.

This makes both platforms' UI components independently testable with snapshot/preview tests that just pass a `FormUiState` directly.

### 3. Component Library Boundary

**The boundary is `:shared-components` / platform `components/` folder — everything else is showcase.**

Concrete rule: a class belongs in `:shared-components` if and only if:
- It concerns one of the four component families (form, amount, nav-drawer, notification), AND
- It has no dependency on showcase-specific data (currency rate API response, user profile, demo navigation graph)

The Koin module in `:shared-components` registers only the component ViewModels and their use cases. The showcase Koin module in `:shared-app` registers everything else. Keeping these two module declarations in separate Gradle modules makes accidental coupling a compile error, not a lint warning.

### 4. Navigation State Ownership

**Decision: shared route-tree data + expanded-group state live in `:shared-components/NavDrawerViewModel`; actual navigation execution lives per-platform.**

The tree sidebar has two concerns:
- **Data**: what items exist, which groups are expanded, which route is active — this is pure state, no platform API needed. Lives in `NavDrawerViewModel.state: StateFlow<NavDrawerUiState>`.
- **Execution**: navigating to a route — on Android this calls `NavController.navigate(route)`, on iOS it mutates a `NavigationPath` or `@State var path`.

The ViewModel fires a navigation *intent* (`NavIntent.RouteSelected(route)`). The platform-side `NavDrawer` composable/view receives this, converts the route to the platform's navigation primitive, and executes. The shared ViewModel never touches `NavController` or `NavigationStack`.

**Why not fully shared nav (Decompose / D-KMP style)?**
The project explicitly targets native UI per platform with native navigation idioms. Fully sharing navigation state (D-KMP / Decompose) gives consistency at the cost of coupling nav to shared code, requiring platform nav APIs to be bridged. For a component skeleton with four screens in the showcase, the added complexity is not justified. The per-platform execution model keeps Android `NavController` and iOS `NavigationStack` idiomatic.

**Rejected: fully per-platform nav state**
If the expanded-group toggle and current-route state live per-platform, they cannot be driven from the same shared ViewModel, and a future product cloning this skeleton would have to re-implement that state on each platform.

### 5. Notification Architecture

**In-app notification queue: shared, in `NotificationViewModel`.**

The in-app notification queue (toasts, banners, snackbars, inline alerts) is pure state — a `List<InAppNotification>` with an `id`, `type` (Toast/Banner/Snackbar/Inline), `message`, and optional `action`. It lives in `NotificationViewModel` in `:shared-components`. Any screen can enqueue a notification by calling `notificationVm.onIntent(NotificationIntent.Show(...))`. Both platform UIs observe the same queue via `StateFlow`.

**Push notification token registration: platform-specific, surfaces into shared via `expect`/`actual`.**

FCM (Android) and APNs (iOS) token registration necessarily touches platform SDKs. The flow:

1. Each platform's app-entry-point (Android `Application.onCreate` / iOS `AppDelegate`) initializes the Firebase/Messaging SDK.
2. The `NotificationService.actual` (per-platform) captures the token from the SDK callback.
3. It delivers the token to `NotificationViewModel.onIntent(NotificationIntent.TokenRefresh(token))`.
4. The ViewModel delegates to `RegisterDeviceTokenUseCase` in `:shared-core`, which calls the server stub via Ktor.
5. The server stub stores the mapping `(userId, token, platform)`.

The token itself is a plain `String` that lives in the shared domain. Platform code does not need to see the server stub at all — the use case handles it.

**Recommendation**: use `KMPNotifier` (by mirzemehdi) as a reference implementation or a direct dependency. It provides exactly this interface: a unified `NotifierManager` with `onNewToken(token: String)` callback, `getToken()`, and local notification support. It is published to Maven Central and available as a Swift Package.

### 6. Build Order

```
Phase 1 ─ Unblocks everything downstream
  :shared-core — DesignTokens, Koin scaffold, Ktor stub, SQLDelight schema
  Rationale: every component VM depends on DI wiring and token primitives

Phase 2 ─ Unblocked by Phase 1
  :shared-components — FormViewModel + AmountInputViewModel (no network deps)
  androidApp + iosApp AppTheme adapters (depend on DesignTokens)
  Rationale: form and amount have no server dependency; can ship and test immediately

Phase 3 ─ Unblocked by Phase 2
  :shared-components — NavDrawerViewModel (depends on route models, no network)
  androidApp FormField + AmountInputField Composables
  iosApp FormField + AmountInputField SwiftUI Views
  Rationale: nav drawer state model is more complex; form/amount UI landed first gives confidence in the contract

Phase 4 ─ Unblocked by Phase 2 + FCM/APNs setup
  :shared-components — NotificationViewModel, NotificationService expect/actual
  Push notification token registration + server stub
  androidApp + iosApp NotificationHost
  Rationale: push notification requires platform SDK configuration (Firebase project, APNs certificate) that is independent of UI work; can be parallelized with Phase 3

Phase 5 ─ Unblocked by all above
  :shared-app — showcase VMs, demo Ktor call, SQLDelight feature
  androidApp + iosApp showcase screens
  Published artifacts (Maven Central + SPM)
```

**Explicit dependency edges:**

```
DesignTokens ──────────────────────────────► AppTheme (both platforms)
DesignTokens ──────────────────────────────► FormField, AmountInputField, NavDrawer, NotificationHost
Koin scaffold ─────────────────────────────► FormViewModel, AmountInputViewModel, NavDrawerViewModel, NotificationViewModel
FormViewModel + UiState contracts ─────────► FormField Composable / SwiftUI View
AmountInputViewModel + UiState contracts ──► AmountInputField Composable / SwiftUI View
NavDrawerViewModel + UiState contracts ────► NavDrawer Composable / SwiftUI View
NotificationService expect/actual ─────────► NotificationViewModel
NotificationViewModel ─────────────────────► NotificationHost Composable / SwiftUI View
All component VMs + AppTheme ──────────────► Showcase screens
```

### 7. Showcase vs Library Separation

**The showcase is a consumer of the library, not a co-author.**

Mechanically enforced: the showcase screens are in `:shared-app` and `androidApp/showcase/` / `iosApp/Showcase/`. They import `:shared-components` and the platform `components/` folder the same way an external consumer would. They never reach into the internal packages of `:shared-components`.

The published artifact is `:shared-components` (KMP) + the platform-specific component Composables/Views packaged in a separate Android library module (`:components-android`) and a Swift Package target. The `:androidApp` and `:iosApp` showcase apps depend on these as versioned artifacts in CI before publishing, or as project-local includes during development.

**A future adopter** clones the skeleton, runs `./gradlew :androidApp:installDebug`, and the showcase demonstrates every component. They then copy `:shared-components` and `:components-android` into their product, pointing their `build.gradle.kts` at the Maven Central coordinates. No showcase code accompanies it.

---

## Anti-Patterns

### Anti-Pattern 1: ViewModel in reusable component

**What people do:** Create a `FormViewModel` and inject it inside the `FormField` composable via `viewModel()`.

**Why it's wrong:** Two `FormField` calls on the same screen receive the same VM instance. State bleeds between fields. Composable becomes impossible to preview or test in isolation.

**Do this instead:** `FormField` takes `state: FormUiState` and `onIntent`. The screen creates the `FormViewModel`, collects state, and passes it down.

### Anti-Pattern 2: Flat `:shared` with no boundary

**What people do:** Put component VMs, showcase VMs, DI wiring, and design tokens all in one `shared/` module.

**Why it's wrong:** The published library contains showcase-specific code. Changing a showcase ViewModel invalidates the entire shared build. The library-vs-app boundary is invisible.

**Do this instead:** Three modules with explicit Gradle dependency declarations as the enforcer.

### Anti-Pattern 3: Multiple iOS frameworks

**What people do:** Compile `:shared-core` and `:shared-components` into separate frameworks and link both to the iOS app.

**Why it's wrong:** JetBrains explicitly documents this causes dependency duplication. `FieldState` from `:shared-core` embedded in both frameworks becomes two incompatible types on the Swift side. Crashes at runtime when passing objects between component families.

**Do this instead:** Single umbrella framework with `api` + `export` in `:shared-components`'s framework block.

### Anti-Pattern 4: Design tokens as Compose types in commonMain

**What people do:** Define `val primary = Color(0xFF3B82F6)` in `commonMain`.

**Why it's wrong:** `Color` is a Compose type. It does not compile in `iosMain`. Build fails.

**Do this instead:** `const val primary: Long = 0xFF3B82F6`. Each platform adapter converts.

### Anti-Pattern 5: Navigation execution in shared ViewModel

**What people do:** `NavDrawerViewModel` holds a `NavController` reference and calls `navController.navigate(route)`.

**Why it's wrong:** `NavController` is an Android-only type. Does not compile in `commonMain`. Even if wrapped, it creates an iOS-incompatible API.

**Do this instead:** VM fires `NavDrawerUiState.NavigateTo(route)` as a one-shot event in the state. Each platform's UI layer observes and executes with its own navigation primitive.

---

## Integration Points

### External Services

| Service | Integration Pattern | Notes |
|---------|---------------------|-------|
| Firebase (FCM) | `NotificationService.android.kt` actual, `FirebaseMessagingService` subclass | Initialize in `Application.onCreate()` |
| APNs / Firebase iOS | `NotificationService.ios.kt` actual, `AppDelegate` delegate methods | Must set `apnsToken` on `Messaging.messaging()` |
| Currency rates API | Ktor call in `:shared-core` repository, `AmountInputViewModel` subscribes | Doubles as networking demo in showcase |
| Server stub | Ktor server (Kotlin) or mock — receives device token, exposes `/api/tokens` | Minimal; not a real backend |
| Maven Central | Published from `:shared-components`, `:shared-core` via `maven-publish` plugin | Separate from `:shared-app` |
| Swift Package Manager | XCFramework from umbrella compiled in CI, published to separate SPM repo | CocoaPods explicitly rejected (deprecating) |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| `:shared-core` ↔ `:shared-components` | Gradle `api` dep; types exported | `DesignTokens`, use cases, repos flow up |
| `:shared-components` ↔ `:shared-app` | Gradle `implementation` dep (not `api`) | Showcase is a consumer, not re-exporter |
| `commonMain` ↔ `androidMain`/`iosMain` | `expect`/`actual` | Only for platform SDK requirements |
| `:shared-components` ↔ `androidApp/components/` | Plain import; no DI framework in UI layer | Composables are pure functions of state |
| `:shared-components` ↔ `iosApp/Components/` | Swift import of umbrella framework | SKIE bridges sealed interfaces → Swift enums |

---

## Open Questions (Key Decisions for Roadmap)

These are unresolved and should become explicit Key Decisions before or during their corresponding phase:

1. **Currency formatter approach**: Roll a custom `expect`/`actual` using `java.text.NumberFormat` / `NSNumberFormatter`, or adopt `Kurrency` / `pale-blue-kmp-core`? Cash App's blog post recommends leaning on native formatters. Decision affects `:shared-components` API surface.

2. **Amount input precision**: Use `BigDecimal` (JVM only, needs KMP wrapper) or represent as `Long` cents + display-only formatting? `Long` cents avoids floating-point drift but constrains the API. `touchlab/kotlin-big-decimal` and `ionspin/kotlin-multiplatform-bignum` are the two KMP options.

3. **In-app notification delivery**: Should `NotificationViewModel` use a `Channel` (fire-and-forget) or `StateFlow` (always-latest-wins)? `StateFlow` risks dropping rapid successive notifications; `Channel` + buffer is more correct for a queue. An `@OptIn(ExperimentalCoroutinesApi::class)` `MutableSharedFlow(replay=0, extraBufferCapacity=64)` is the idiomatic answer but adds API complexity.

4. **KMPNotifier vs custom `expect`/`actual` for push**: `KMPNotifier` adds a transitive Firebase dependency. For a skeleton template that may not need push in every derived product, a thin hand-rolled `expect`/`actual` keeps the dependency optional. Decision: include it in `:shared-components` or make it a separate opt-in `:shared-notifications` module?

5. **NavDrawer route tree representation**: `List<NavItem>` with `children: List<NavItem>` recursive model, or a flat `List<NavItem>` with `parentId`? Recursive is ergonomic for rendering; flat is easier to serialize/persist. Decide before implementing `NavDrawerUiState`.

6. **Published artifact naming before Maven Central**: The `dev.skeleton` group ID is a placeholder. Final group ID (tied to domain ownership) must be locked before the publish phase. This is a non-trivial vanity domain decision for a solo project.

---

## Sources

- [KMP Project Configuration — JetBrains (official)](https://kotlinlang.org/docs/multiplatform/multiplatform-project-configuration.html) — Umbrella module pattern, api vs implementation, iOS single-framework requirement
- [Set up ViewModel for KMP — Android Developers](https://developer.android.com/kotlin/multiplatform/viewmodel) — `IosViewModelStoreOwner`, SKIE bridge, Koin over Hilt
- [State holders and UI state — Android Developers](https://developer.android.com/topic/architecture/ui-layer/stateholders) — ViewModel for screen-level, plain class for component-level
- [Where to hoist state — Jetpack Compose](https://developer.android.com/develop/ui/compose/state-hoisting) — Don't use VM for reusable UI components
- [KMM Umbrella Architecture — Marcin Piekielny (Medium)](https://medium.com/@maruchin/kmm-architecture-4-umbrella-a26a370071d5) — Concrete Gradle configuration for umbrella pattern
- [Modularizing a KMP Mobile Project — akjaw.com](https://akjaw.com/modularizing-a-kotlin-multiplatform-mobile-project/) — api/impl split, showcase separation
- [KMP Navigation Solutions — droidcon 2024](https://www.droidcon.com/2024/04/09/navigating-the-waters-of-kotlin-multiplatform-exploring-navigation-solutions/) — Per-platform vs shared nav tradeoffs
- [Safe ViewModel Navigation in KMP — Medium 2026](https://medium.com/@maranatha.amouzou/safe-viewmodel-navigation-in-kmp-preventing-race-conditions-with-navigation-3-479fcf9421fe) — Ghost navigation / race condition pitfalls
- [KMPNotifier — GitHub](https://github.com/mirzemehdi/KMPNotifier) — Push notification token registration, shared interface
- [KMP Currency Formatting — Cash App Code Blog](https://code.cash.app/kotlin-multiplatform-money-formatter) — Real-world expect/actual for locale formatting
- [Kurrency — GitHub](https://github.com/Kimplify/Kurrency) — Type-safe currency formatting for KMP
- [KStateMachine — GitHub](https://github.com/KStateMachine/kstatemachine) — KMP state machine library
- [D-KMP Sample — GitHub](https://github.com/dbaroncelli/D-KMP-sample) — Shared ViewModel + nav sample

---
*Architecture research for: KMP skeleton — reusable native UI component library*
*Researched: 2026-05-08*
