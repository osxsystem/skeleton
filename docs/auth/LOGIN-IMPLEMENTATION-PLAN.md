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

```swift
// :iosApp/.../Auth/LoginScreen.swift
struct LoginScreen: View {
    @StateObject private var owner = IosViewModelStoreOwner()
    @State private var uiState: LoginUiState = LoginUiState.Editing()
    let onSuccess: () -> Void

    var body: some View {
        let vm: LoginViewModel = owner.viewModel(
            factory: LoginViewModelFactoryKt.loginViewModelFactory
        )

        ZStack {
            switch uiState {
            case let editing as LoginUiState.Editing:
                LoginForm(state: editing, vm: vm)
            case let submitting as LoginUiState.Submitting:
                SubmittingOverlay(email: submitting.email)
            case let failed as LoginUiState.Failed:
                LoginForm(
                    state: LoginUiState.Editing(email: failed.email, password: "", emailError: nil, passwordError: nil, isSubmitEnabled: false),
                    vm: vm
                )
            case is LoginUiState.Succeeded:
                EmptyView()
            default:
                EmptyView()
            }
        }
        .alert(
            "Login failed",
            isPresented: .constant(uiState is LoginUiState.Failed),
            actions: { Button("OK") { vm.onErrorDismissed() } },
            message: {
                if let f = uiState as? LoginUiState.Failed { Text(f.message) }
            }
        )
        .task {
            for await s in vm.state {            // SKIE bridges StateFlow → AsyncSequence
                uiState = s
                if s is LoginUiState.Succeeded {
                    onSuccess()
                    vm.onNavigatedToDashboard()
                }
            }
        }
    }
}
```

**Why `@StateObject` + `IosViewModelStoreOwner`?** SwiftUI doesn't have AndroidX's `ViewModel` lifecycle. The owner ties the VM's lifetime to the View's lifetime exactly the way Android does it. This pattern is the official Google recommendation — see [`../../architecture.md`](../../architecture.md) §Platform Bindings.

---

## 12. Navigation to Dashboard

- **Android:** Navigation 3 — the parent `NavHost` listens for the `onSuccess` callback and pops to `Dashboard`.
- **iOS:** A `NavigationStack` at the app root reacts to a binding flipped by `onSuccess`.

Navigation is platform-specific and lives in each app module. The shared ViewModel only signals "Succeeded" — it does **not** know what screen comes next.

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
