# Login Authentication — Technical Implementation Plan

**Status:** Plan
**Owner:** _to be assigned_
**Audience:** Junior engineer implementing their first feature in this skeleton
**Companion docs:** [`../../CLAUDE.md`](../../CLAUDE.md), [`../../architecture.md`](../../architecture.md)

---

## Related Docs (READ before implementing)

- **PRD:** [`LOGIN-PRD.md`](./LOGIN-PRD.md) — requirements, acceptance criteria, open architectural decisions (§14)
- **UI Specs:** _pending_ (`LOGIN-UI.md`)
- **QA Test Plan:** _pending_ (`LOGIN-QA.md`)

**Status:** PRD §14 decisions are resolved. This plan has been updated to match — §3 places `LoginViewModel` in `:shared-app` (A2); design tokens (B), navigation (C), and SKIE bridge (D) all reference the PRD's resolved guidance.

---

## 1. Goal

Build a Login screen that:

1. Lets the user type an **email** and **password**.
2. Calls a **mock authentication API** when the user taps Submit.
3. On **success** → navigates to the Dashboard screen.
4. On **failure** → shows an error alert; the user can correct and retry.

This document tells you **what to build, in what order, where to put it, and why**. It does not contain the final source code.

---

## 2. Why This Plan Looks the Way It Does

The skeleton's pattern is **MVVM with a shared `ViewModel` exposing `StateFlow<UiState>`** (see [`../../architecture.md`](../../architecture.md)). That means:

- **The ViewModel is the brain.** It holds state, calls the use case, and emits new states.
- **The UI is dumb.** It only renders whatever state the ViewModel currently emits and forwards user actions back as plain method calls (`onSubmit`, `onEmailChange`).
- **Both Android and iOS consume the same ViewModel.** So if you implement the logic correctly once in `commonMain`, both platforms get it for free.

Keep this picture in your head while you read the rest:

```
   [Compose Screen]                   [SwiftUI Screen]
        │ onSubmit(email, password)        │ onSubmit(email, password)
        ▼                                  ▼
        ────────── LoginViewModel  (commonMain) ──────────
                       │  state: StateFlow<LoginUiState>
                       │
                       ▼
                  LoginUseCase
                       │
                       ▼
                  AuthRepository  ←──── (mocked Ktor client)
```

---

## 3. Where Each Piece Lives

This skeleton has multiple modules. Putting things in the wrong module is the most common rookie mistake — it causes circular dependencies that are painful to undo. Use this map:

| What you're building | Module | Path |
|---|---|---|
| `AuthApi` (Ktor client interface + mock) | `:shared-core` | `data/remote/auth/` |
| `AuthRepository` | `:shared-core` | `data/auth/` |
| `LoginUseCase` | `:shared-core` | `domain/auth/` |
| `LoginViewModel`, `LoginUiState`, events, helper | `:shared-app` | `auth/login/` |
| Koin bindings for the above | `:shared-core` (data/domain) + `:shared-app` (VM) | `di/` |
| Compose `LoginScreen` | `:androidApp` | `auth/LoginScreen.kt` |
| SwiftUI `LoginScreen` | `:iosApp` | `Auth/LoginScreen.swift` |

**Why this split?** Authentication's data and domain layers live in `:shared-core` because every future feature (Dashboard, Profile, Settings) needs to know who the user is — foundational things go there. The `LoginViewModel` lives in `:shared-app` (the "showcase" module), not `:shared-components`, because Login is a product feature, not a reusable widget. `:shared-components` is reserved for the four genuinely-reusable component VMs the skeleton promises: forms, amount input, sidebar navigation, notifications.

---

## 4. Implementation Order

Build in this order. Each step is small and produces something you can verify before moving on.

| # | Step | Verify by |
|---|---|---|
| 1 | Define `LoginUiState` and the event surface | Code compiles in `commonMain` |
| 2 | Define `AuthApi` interface + a mock implementation with `delay(...)` | Unit-test the mock returns success/failure |
| 3 | Implement `AuthRepository` and `LoginUseCase` | Unit-test happy path + failure path |
| 4 | Implement `LoginViewModel` driving the use case | `commonTest` with Turbine asserts state transitions |
| 5 | Wire Koin modules | `startKoin {}` succeeds in both apps |
| 6 | Build the Compose `LoginScreen` | Run `:androidApp:installDebug`; tap through the flow |
| 7 | Build the SwiftUI `LoginScreen` | Open Xcode, ⌘R, tap through the flow |
| 8 | Hook up navigation to Dashboard on success | Manual smoke on both platforms |

Don't skip ahead. The ViewModel must be tested green **before** you touch any UI — that way if the UI behaves oddly, you already know the brain is correct.

---

## 5. Step 1 — State Design

**Why this matters:** the shape of `UiState` is the single most important design decision in MVVM. Get it right and the UI is trivial. Get it wrong and you'll patch it forever.

Use a `sealed interface` so the view can `when (state)` exhaustively (the compiler will yell if you miss a case):

```kotlin
// :shared-app/.../auth/login/LoginUiState.kt
sealed interface LoginUiState {

    /** Form is editable; user can type and submit. */
    data class Editing(
        val email: String = "",
        val password: String = "",
        val emailError: String? = null,
        val passwordError: String? = null,
        val isSubmitEnabled: Boolean = false,
    ) : LoginUiState

    /** Network call in progress; UI must disable the submit button and show a spinner. */
    data class Submitting(val email: String, val password: String) : LoginUiState

    /** Auth failed; UI shows alert and lets the user retry. Preserves inputs. */
    data class Failed(
        val email: String,
        val password: String,
        val message: String,
    ) : LoginUiState

    /** Auth succeeded; UI navigates to Dashboard. */
    data object Succeeded : LoginUiState
}
```

**Why preserve `email`/`password` in `Submitting` and `Failed`?** Because if the user typo'd a password and the API rejects it, you don't want to wipe their email — that's hostile UX. Only the password field gets cleared.

**Events** the View can fire (these are just methods on the ViewModel):
- `onEmailChange(value: String)`
- `onPasswordChange(value: String)`
- `onSubmit()`
- `onErrorDismissed()` — closes the alert and returns to `Editing`
- `onNavigatedToDashboard()` — tells the VM the success was consumed (prevents re-navigation on config change)

---

## 6. Step 2 — The Mock API

**Why a mock first?** No real backend exists yet. We want to build the entire UI flow today, and swap in the real API later by changing only the Koin binding.

Define the API as an **interface** in `commonMain`:

```kotlin
// :shared-core/.../data/remote/auth/AuthApi.kt
interface AuthApi {
    suspend fun login(email: String, password: String): UserSession
}

data class UserSession(val userId: String, val token: String)
```

Then provide a **fake implementation** that simulates a real network call:

```kotlin
// :shared-core/.../data/remote/auth/FakeAuthApi.kt
class FakeAuthApi : AuthApi {
    override suspend fun login(email: String, password: String): UserSession {
        delay(800)  // simulate network latency
        if (email == "test@example.com" && password == "password") {
            return UserSession(userId = "u-1", token = "fake-token-abc")
        }
        throw AuthException("Invalid email or password")
    }
}

class AuthException(message: String) : RuntimeException(message)
```

**Why `delay(800)`?** A real API takes time to answer. If you don't simulate that, you can't see your loading state on screen — and you'll discover that bug only in production. `delay` is suspended and cancellation-aware, so it behaves like a real `suspend` network call.

**Why throw an exception, not return `Result`?** Throwing is the natural Kotlin idiom and matches what Ktor will do later. We'll catch it in the repository layer.

When you swap the real Ktor client in later, you replace `FakeAuthApi` with a `KtorAuthApi : AuthApi` and change one line in your Koin module. The rest of the code doesn't notice.

---

## 7. Step 3 — Repository and Use Case

**Why a repository?** It's the only layer allowed to talk to the API and the database. The ViewModel must never call Ktor or SQLDelight directly. This keeps the ViewModel testable without a network.

**Why a use case?** For Login it looks like a passthrough, but use cases give you one place to add validation, telemetry, or to combine multiple data sources later.

```kotlin
// :shared-core/.../data/auth/AuthRepository.kt
class AuthRepository(
    private val api: AuthApi,
    private val sessionStore: SessionStore,  // saves token; provided by expect/actual
) {
    suspend fun login(email: String, password: String): UserSession {
        val session = api.login(email, password)
        sessionStore.save(session)
        return session
    }
}
```

```kotlin
// :shared-core/.../domain/auth/LoginUseCase.kt
class LoginUseCase(private val repository: AuthRepository) {

    suspend operator fun invoke(email: String, password: String): UserSession {
        require(email.isNotBlank()) { "Email is required" }
        require(password.isNotBlank()) { "Password is required" }
        return repository.login(email.trim(), password)
    }
}
```

**`require {}` throws `IllegalArgumentException` for blank inputs.** This is a safety net; the form should already prevent empty submits via `isSubmitEnabled`.

---

## 8. Step 4 — The ViewModel (the heart of the feature)

This is where the four-step lifecycle lives: **idle → submitting → success/failure**.

```kotlin
// :shared-app/.../auth/login/LoginViewModel.kt
class LoginViewModel(
    private val login: LoginUseCase,
) : ViewModel() {

    private val _state = MutableStateFlow<LoginUiState>(LoginUiState.Editing())
    val state: StateFlow<LoginUiState> = _state.asStateFlow()

    fun onEmailChange(value: String) {
        val current = _state.value as? LoginUiState.Editing ?: return
        _state.value = current.copy(
            email = value,
            emailError = null,
            isSubmitEnabled = value.isNotBlank() && current.password.isNotBlank(),
        )
    }

    fun onPasswordChange(value: String) {
        val current = _state.value as? LoginUiState.Editing ?: return
        _state.value = current.copy(
            password = value,
            passwordError = null,
            isSubmitEnabled = current.email.isNotBlank() && value.isNotBlank(),
        )
    }

    fun onSubmit() {
        val current = _state.value as? LoginUiState.Editing ?: return
        if (!current.isSubmitEnabled) return

        viewModelScope.launch {
            _state.value = LoginUiState.Submitting(current.email, current.password)
            try {
                login(current.email, current.password)
                _state.value = LoginUiState.Succeeded
            } catch (e: AuthException) {
                _state.value = LoginUiState.Failed(
                    email = current.email,
                    password = "",                       // clear password only
                    message = e.message ?: "Login failed",
                )
            } catch (e: Exception) {
                _state.value = LoginUiState.Failed(
                    email = current.email,
                    password = "",
                    message = "Something went wrong. Please try again.",
                )
            }
        }
    }

    fun onErrorDismissed() {
        val failed = _state.value as? LoginUiState.Failed ?: return
        _state.value = LoginUiState.Editing(
            email = failed.email,
            password = "",
            isSubmitEnabled = false,
        )
    }

    fun onNavigatedToDashboard() {
        // Reset so a back-press doesn't immediately re-trigger navigation.
        _state.value = LoginUiState.Editing()
    }
}
```

### Key things a junior must understand

- **`viewModelScope.launch`** runs the network call on a coroutine that is automatically cancelled if the ViewModel is destroyed. Never use `GlobalScope`.
- **Two `catch` blocks.** The first catches the *known* domain error (`AuthException`) — its message is safe to show. The second catches everything else (timeouts, JSON parse errors, etc.) — its raw message is **not** safe to show and we substitute a friendly fallback.
- **State is set before and after the call.** The `Submitting` state is what makes the spinner appear. Without it, the UI would freeze visually until the call returns.
- **The ViewModel never knows the View exists.** No callbacks, no view interfaces, no `Activity`/`UIViewController` references. That's why the same VM works on both platforms.

---

## 9. Step 5 — Dependency Injection (Koin)

Wire the new types into the Koin graph so the platform apps can get a `LoginViewModel` without knowing what's behind it.

```kotlin
// :shared-core/.../di/AuthModule.kt
val authDataModule = module {
    single<AuthApi> { FakeAuthApi() }                      // swap to KtorAuthApi later
    single { AuthRepository(get(), get()) }
    factory { LoginUseCase(get()) }
}
```

```kotlin
// :shared-app/.../di/AuthVmModule.kt
val authVmModule = module {
    factory { LoginViewModel(get()) }
}
```

**Why `factory` for use cases and ViewModels?** A new instance per request — important so two screens don't accidentally share the same VM.
**Why `single` for the API and repository?** Stateless or shared-state services should be process-singletons.

---

## 10. Step 6 — Compose UI (Android)

```kotlin
// :androidApp/.../auth/LoginScreen.kt
@Composable
fun LoginScreen(
    onSuccess: () -> Unit,
    viewModel: LoginViewModel = koinViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    LaunchedEffect(state) {
        if (state is LoginUiState.Succeeded) {
            onSuccess()
            viewModel.onNavigatedToDashboard()
        }
    }

    when (val s = state) {
        is LoginUiState.Editing -> LoginForm(
            state = s,
            onEmailChange = viewModel::onEmailChange,
            onPasswordChange = viewModel::onPasswordChange,
            onSubmit = viewModel::onSubmit,
        )
        is LoginUiState.Submitting -> SubmittingOverlay(s.email)
        is LoginUiState.Failed -> {
            // Render the form behind the alert so the user sees their inputs.
            LoginForm(
                state = LoginUiState.Editing(email = s.email, password = ""),
                onEmailChange = viewModel::onEmailChange,
                onPasswordChange = viewModel::onPasswordChange,
                onSubmit = viewModel::onSubmit,
            )
            ErrorAlert(message = s.message, onDismiss = viewModel::onErrorDismissed)
        }
        LoginUiState.Succeeded -> Unit  // navigation handled by LaunchedEffect
    }
}
```

**Why `LaunchedEffect(state)`?** Side effects (like navigation) belong inside `LaunchedEffect`, not directly in the composition. Otherwise you'll navigate twice on recomposition and crash.

---

## 11. Step 7 — SwiftUI UI (iOS)

SKIE is disabled in this repo (`shared-components/build.gradle.kts:66-71`, see PRD §14.D). Two SKIE-only idioms — `KClass<T>` for `ViewModelProvider.get` and `for await` on a `Flow` — don't bridge ergonomically to Swift, so we add a per-VM Kotlin helper file in `commonMain` that hides those types behind plain functions. Mirror `GreetingViewModelHelper.kt`.

```kotlin
// :shared-app/.../auth/login/LoginViewModelHelper.kt
package dev.viethung.showcase.auth.login

import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.ViewModelStore
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.launch

fun createLoginViewModel(store: ViewModelStore): LoginViewModel =
    ViewModelProvider.create(store, loginViewModelFactory)[LoginViewModel::class]

fun subscribeLoginState(
    vm: LoginViewModel,
    onState: (LoginUiState) -> Unit,
): Job = CoroutineScope(Dispatchers.Main).launch {
    vm.state.collect { onState(it) }
}
```

```swift
// :iosApp/iosApp/Auth/LoginScreen.swift
import SwiftUI
import SkeletonApp

struct LoginScreen: View {
    @StateObject private var owner = IosViewModelStoreOwner()
    @State private var uiState: LoginUiState = LoginUiStateEditing(
        email: "", password: "",
        emailError: nil, passwordError: nil,
        isSubmitEnabled: false
    )
    @State private var stateJob: Kotlinx_coroutines_coreJob?
    let onSuccess: () -> Void

    var body: some View {
        let vm: LoginViewModel = LoginViewModelHelperKt.createLoginViewModel(
            store: owner.viewModelStore
        )

        ZStack {
            stateContent(vm: vm)
        }
        .alert(
            "Login failed",
            isPresented: .constant(uiState is LoginUiStateFailed),
            actions: { Button("OK") { vm.onErrorDismissed() } },
            message: {
                if let failed = uiState as? LoginUiStateFailed {
                    Text(failed.message)
                }
            }
        )
        .task {
            stateJob = LoginViewModelHelperKt.subscribeLoginState(vm: vm) { state in
                uiState = state
                if state is LoginUiStateSucceeded {
                    onSuccess()
                    vm.onNavigatedToDashboard()
                }
            }
        }
        .onDisappear {
            stateJob?.cancel(cause: nil)
            stateJob = nil
        }
    }

    @ViewBuilder
    private func stateContent(vm: LoginViewModel) -> some View {
        if let editing = uiState as? LoginUiStateEditing {
            LoginForm(state: editing, vm: vm)
        } else if let submitting = uiState as? LoginUiStateSubmitting {
            SubmittingOverlay(email: submitting.email)
        } else if let failed = uiState as? LoginUiStateFailed {
            // Render the form behind the alert so the user sees their email preserved.
            LoginForm(
                state: LoginUiStateEditing(
                    email: failed.email, password: "",
                    emailError: nil, passwordError: nil,
                    isSubmitEnabled: false
                ),
                vm: vm
            )
        } else {
            // LoginUiStateSucceeded — navigation is handled by the subscribe callback.
            EmptyView()
        }
    }
}
```

**Why `@StateObject` + `IosViewModelStoreOwner`?** SwiftUI doesn't have AndroidX's `ViewModel` lifecycle. The owner ties the VM's lifetime to the View's lifetime the way Android does. When SwiftUI deallocates the owner, its `deinit` calls `viewModelStore.clear()`, which fires `onCleared()` on the ViewModel and cancels `viewModelScope`. See [`../../architecture.md`](../../architecture.md) §Platform Bindings.

**Why `as?` casts instead of `switch case let _ as _`?** The K/N bridge exports the sealed-interface subtypes as flat Obj-C classes (`LoginUiStateEditing`, `LoginUiStateSubmitting`, `LoginUiStateFailed`, `LoginUiStateSucceeded`). Swift's `switch case let _ as` is awkward on bridged Obj-C class hierarchies; `if let _ = x as? T` reads cleaner. Matches `GreetingScreen.swift:34-44`.

**Why cancel `stateJob` on `.onDisappear`?** The job is rooted in a `CoroutineScope(Dispatchers.Main)` *outside* `viewModelScope` (the helper creates a fresh scope per subscription so multiple Swift views can subscribe independently). Without an explicit cancel, the collection coroutine leaks for the lifetime of the process. Matches `GreetingScreen.swift:27-30`.

---

## 12. Navigation to Dashboard (Phase 1: hoist `isAuthenticated` at root)

Phase 1 has no nav graph — `MainActivity.kt` has no `NavHost`, and `ContentView.swift:7` wraps a single `NavigationStack { GreetingScreen(...) }`. Per PRD §14.C, both platforms hoist an `isAuthenticated: Boolean` flag at the root view and swap `LoginScreen` ↔ `DashboardPlaceholder` based on it. The shared ViewModel only signals `Succeeded` via the `onSuccess` callback — it doesn't know what screen comes next.

- **Android:** `MainActivity` holds `isAuthenticated` in `rememberSaveable`; pass `onSuccess = { isAuthenticated = true }` to `LoginScreen`. The root `Surface` renders `LoginScreen` when false, `DashboardPlaceholder` when true.
- **iOS:** `ContentView` holds `@State var isAuthenticated: Bool`; pass `onSuccess = { isAuthenticated = true }` to `LoginScreen`. The `NavigationStack` swaps `LoginScreen` ↔ `DashboardPlaceholder` based on the flag.

When Phase 5 navigation lands, both platforms refactor to a proper nav graph; the VM's `onSuccess` callback stays unchanged.

---

## 13. Testing

Write the test **before** you wire any UI. If the test passes, the brain works.

```kotlin
// :shared-app/src/commonTest/.../LoginViewModelTest.kt
@Test
fun login_success_emits_Submitting_then_Succeeded() = runTest {
    val vm = LoginViewModel(login = FakeLoginUseCase(success = true))
    vm.state.test {
        assertIs<LoginUiState.Editing>(awaitItem())
        vm.onEmailChange("test@example.com")
        awaitItem()  // updated Editing
        vm.onPasswordChange("password")
        awaitItem()  // updated Editing with isSubmitEnabled=true
        vm.onSubmit()
        assertIs<LoginUiState.Submitting>(awaitItem())
        assertIs<LoginUiState.Succeeded>(awaitItem())
    }
}

@Test
fun login_failure_emits_Failed_with_message_and_clears_password() = runTest {
    val vm = LoginViewModel(login = FakeLoginUseCase(success = false))
    /* drive onEmailChange, onPasswordChange, onSubmit ... */
    /* assert final state is Failed with password == "" */
}
```

**Why Turbine?** `StateFlow` emits on every change; without Turbine you'd race the assertions. Turbine gives you a queue of emissions and `awaitItem()` to consume them deterministically.

**Use a fake use case** in the test, not the real one. The point is testing *the ViewModel's logic*, not the network.

---

## 14. Definition of Done

The feature is done when **all** of these are true:

- [ ] `:shared-app:allTests` passes the new `LoginViewModelTest` (success + failure + dismissal).
- [ ] `./gradlew :androidApp:installDebug` runs; the Android login screen completes the full flow end-to-end with `test@example.com` / `password`.
- [ ] iOS build runs in Xcode (⌘R); SwiftUI login screen completes the full flow end-to-end.
- [ ] Tapping submit with valid creds shows a spinner for ~800 ms, then navigates to Dashboard.
- [ ] Tapping submit with invalid creds shows an alert; dismissing the alert restores the form with the email preserved and the password empty.
- [ ] Submit button is disabled when either field is empty.
- [ ] No raw colors / fonts / sizes in either UI — everything pulls from `DesignTokens`.
- [ ] Zero references to `android.*` or `UIKit.*` in any `commonMain` source set.

---

## 15. Things You Should *Not* Do (Common Junior Mistakes)

- ❌ Calling `repository.login(...)` directly from a `@Composable` — the network must run via the VM.
- ❌ Storing the password in plain logs (`println(password)`) — easy to forget; never do it.
- ❌ Using `GlobalScope.launch` instead of `viewModelScope.launch`.
- ❌ Throwing the raw exception's message to the user (`e.message`). Catch known exceptions for user-readable messages; substitute a generic message for the rest.
- ❌ Putting a Compose `Color` or SwiftUI `Color` into `commonMain`. Tokens are primitives only.
- ❌ Skipping the `Submitting` state. Without it the UI looks frozen during the network call.
- ❌ Forgetting to reset `Succeeded` → `Editing` after navigation. A back press will re-trigger `onSuccess`.

---

## 16. Out of Scope (for follow-up tickets)

- Real Ktor `KtorAuthApi` against a real backend.
- Token refresh / 401 retry interceptor.
- "Remember me" + biometric unlock.
- Forgot-password flow.
- Sign-up flow.

Each of these is a separate plan; do not bundle them into this ticket.

---

**Read [`../../CLAUDE.md`](../../CLAUDE.md) §2 (Coding Standards) one more time before you start. Every rule there applies to this feature.**
