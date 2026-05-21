# Login Authentication — Product Requirements Document

| Field | Value |
|---|---|
| **Status** | Draft — §14 decisions resolved; ready for implementation |
| **Owner** | _unassigned_ |
| **Companion plan** | [`LOGIN-IMPLEMENTATION-PLAN.md`](./LOGIN-IMPLEMENTATION-PLAN.md) |
| **Phase** | Foundational feature (precedes Dashboard, Profile, Settings) |
| **Target sprint** | 1 sprint (~3–5 days, sequential 8-step build per plan §4) |
| **Document version** | 1.0 (2026-05-16) |

---

## 1. Problem Statement

1. **The skeleton has zero authentication.** A grep across `shared-core`, `shared-components`, `androidApp`, `iosApp` returns no `auth`/`login`/`session` references — every future feature that needs a signed-in user is currently blocked.
2. **No reference pattern exists for a multi-state ViewModel.** The only shared VM today is `GreetingViewModel` (`shared-app/.../greeting/GreetingViewModel.kt:14`), which has a 3-state `UiState` (`Loading | Ready | Error`) and no user input. Login introduces input fields, validation, an in-flight network state, and a one-shot navigation signal — a more complex state machine the codebase has not yet had to support.
3. **The skeleton has no expect/actual secure-storage layer.** Tokens cannot be persisted today — the only `expect`/`actual` is `DatabaseDriverFactory` (SQLDelight). Without a `SessionStore`, the success of `LoginUseCase` would be discarded on app restart, defeating the point of authenticating.
4. **iOS bindings work via a SKIE-less helper pattern.** `shared-components/build.gradle.kts:66-71` has `skie { isEnabled = false }` because SKIE 0.10.11 does not yet support Kotlin 2.3.21. The skeleton already ships a SKIE-less iOS bridge (commit `d61d3f2`): per-VM Kotlin helpers wrap `ViewModelProvider.create(...)` and `StateFlow.collect(...)` for Swift. See `GreetingViewModelHelper.kt` (`createGreetingViewModel(store:)`, `subscribeGreetingState(vm:, onState:)`) and `GreetingScreen.swift:5-30`. iOS builds today. Login mirrors this pattern (§11.3).

---

## 2. Goals & Success Metrics

| Goal | Measurement | Target |
|---|---|---|
| Unblock downstream features | # of features now able to gate on `UserSession` | ≥ 1 (Dashboard) |
| Establish multi-state VM pattern | A `commonTest` proves Editing → Submitting → Succeeded/Failed transitions | 100% of state branches covered by Turbine assertions |
| Cross-platform parity | Same `LoginViewModel` consumed by both UIs without duplication | 0 duplicate state logic in `:androidApp` or `:iosApp` |
| Secure token storage | Token survives app restart; never appears in logs | Manual verification + log scan |
| No architectural drift | Zero violations of CLAUDE.md §2 rules | `./gradlew check` clean |

---

## 3. User Stories

- **US-01.** As a **first-time user**, I want to **enter my email and password and tap Submit**, so that **I can access the app's features that require an account**.
- **US-02.** As a **user who typed the wrong password**, I want to **see a clear error message and retry without re-entering my email**, so that **I don't lose progress on a typo**.
- **US-03.** As a **user with a slow network**, I want to **see a loading indicator while the server responds**, so that **I know the app hasn't frozen and I don't double-submit**.
- **US-04.** As an **authenticated user**, I want **my session to persist across app restarts**, so that **I don't have to log in every time I open the app**.
- **US-05.** As an **engineer building the next feature (Dashboard)**, I want to **query `SessionStore` for the current `UserSession`**, so that **I can gate UI on auth state without re-implementing the auth flow**.

---

## 4. Scope

### In scope
- Email/password login screen on Android (Jetpack Compose) and iOS (SwiftUI).
- Mock `AuthApi` (`FakeAuthApi` with `delay(800)`) returning success for one hardcoded credential and failure otherwise.
- `AuthRepository`, `LoginUseCase`, `LoginViewModel`, `LoginUiState` (sealed interface, 4 branches).
- `SessionStore` `expect`/`actual` for Android (EncryptedSharedPreferences) and iOS (Keychain).
- Koin wiring: data/domain in `:shared-core`; VM in `:shared-app`.
- Navigation hook: signal `Succeeded` → caller-supplied callback. Root composable / `NavigationStack` swaps `LoginScreen` for `DashboardPlaceholder` via a hoisted `isAuthenticated` flag (§14.C).
- Unit tests covering state-machine transitions (success, failure, dismissal, empty inputs).
- Sample test credential `test@example.com` / `password` documented for QA.

### Out of scope (see §13)
- Real backend (`KtorAuthApi`) — interface only; impl deferred.
- Token refresh / 401 retry interceptor.
- "Remember me" / biometric unlock.
- Forgot-password and sign-up flows.
- Multi-factor authentication.
- Social login (Google/Apple).
- Account lockout / rate limiting after N failed attempts.

---

## 5. Functional Requirements

| ID | Requirement | Plan ref |
|---|---|---|
| **FR-01** | The system SHALL render a login form with two text inputs (Email, Password) and one Submit button. | §5, §10, §11 |
| **FR-02** | The Submit button SHALL be disabled when either Email or Password is empty (after trimming whitespace from email). | §8 `onEmailChange`/`onPasswordChange` |
| **FR-03** | On Submit with valid inputs, the system SHALL call `LoginUseCase` and transition state from `Editing` → `Submitting` → (`Succeeded` ∨ `Failed`). | §8 `onSubmit` |
| **FR-04** | While in `Submitting` state, the UI SHALL show a loading indicator and disable the Submit button to prevent double-submit. | §8, §10 |
| **FR-05** | On `AuthException` (known domain error), the system SHALL surface the exception's message verbatim to the user. On any other `Exception`, the system SHALL substitute a generic "Something went wrong. Please try again." | §8 two-catch pattern |
| **FR-06** | On a `Failed` state, the system SHALL preserve the entered email but clear the password field. | §5 Editing/Failed contract |
| **FR-07** | On `Failed`, dismissing the error alert SHALL transition back to `Editing` with email preserved and password empty. | §8 `onErrorDismissed` |
| **FR-08** | On `Succeeded`, the system SHALL signal navigation to Dashboard exactly once (subsequent re-collections must not re-trigger). | §8 `onNavigatedToDashboard` |
| **FR-09** | On successful login, `SessionStore` SHALL persist the `UserSession` (userId + token) using platform-secure storage (Keychain on iOS, EncryptedSharedPreferences on Android). | §7 AuthRepository + new `SessionStore` |
| **FR-10** | The system SHALL NOT log the password value in any code path (no `println`, no Ktor body logging, no exception toString). Email MAY be logged. | CLAUDE.md §2; plan §15 ❌ list |
| **FR-11** | The same `LoginViewModel` SHALL be consumed by both `:androidApp` and `:iosApp` without any platform-specific state logic. | CLAUDE.md §1 state-ownership |
| **FR-12** | `commonMain` SHALL contain zero references to `android.*`, `androidx.compose.*`, or `UIKit.*`. | CLAUDE.md §2 |

---

## 6. Acceptance Criteria

| ID | Criterion | Verifies |
|---|---|---|
| **AC-01** | **GIVEN** the user opens the login screen, **WHEN** no input has been typed, **THEN** the Submit button is disabled and `state` is `Editing(email="", password="", isSubmitEnabled=false)`. | FR-01, FR-02 |
| **AC-02** | **GIVEN** the user types `test@example.com` in Email, **WHEN** the Password field is still empty, **THEN** Submit remains disabled. | FR-02 |
| **AC-03** | **GIVEN** the user has filled both fields, **WHEN** they tap Submit, **THEN** within 50 ms `state` emits `Submitting(email, password)` and the loading indicator becomes visible. | FR-03, FR-04 |
| **AC-04** | **GIVEN** valid credentials `test@example.com` / `password`, **WHEN** the mock API returns success after ~800 ms, **THEN** `state` emits `Succeeded` exactly once and `SessionStore.read()` returns a non-null `UserSession`. | FR-03, FR-08, FR-09 |
| **AC-05** | **GIVEN** invalid credentials, **WHEN** the API throws `AuthException`, **THEN** `state` emits `Failed(email=<original>, password="", message="Invalid email or password")`. | FR-05, FR-06 |
| **AC-06** | **GIVEN** the API throws an unexpected exception (e.g., `IOException`), **WHEN** caught, **THEN** `state` emits `Failed(message="Something went wrong. Please try again.")` and the raw message is NOT shown. | FR-05 |
| **AC-07** | **GIVEN** `state` is `Failed`, **WHEN** the user calls `onErrorDismissed()`, **THEN** `state` becomes `Editing(email=<preserved>, password="", isSubmitEnabled=false)`. | FR-07 |
| **AC-08** | **GIVEN** `state` is `Succeeded`, **WHEN** the consumer calls `onNavigatedToDashboard()`, **THEN** `state` returns to `Editing()` with empty fields so back-press cannot re-trigger navigation. | FR-08 |
| **AC-09** | **GIVEN** any login attempt succeeds, **WHEN** the app is force-closed and re-launched, **THEN** `SessionStore.read()` still returns the same `UserSession` on both Android (EncryptedSharedPreferences) and iOS (Keychain). | FR-09 |
| **AC-10** | **GIVEN** a `LoginViewModelTest` in `commonTest`, **WHEN** running `./gradlew :<module>:allTests`, **THEN** all branches (Editing→Submitting→Succeeded, Editing→Submitting→Failed, Failed→Editing via dismiss, empty-input guard) pass with Turbine assertions. | FR-03, FR-05, FR-07, FR-11 |
| **AC-11** | **GIVEN** a grep of the entire repository, **WHEN** searching for `println.*password\|Log\..*password`, **THEN** zero matches are found in source code. | FR-10 |
| **AC-12** | **GIVEN** Android `:androidApp:installDebug` and iOS `⌘R`, **WHEN** completing the full happy-path end-to-end, **THEN** both platforms successfully transition to the Dashboard placeholder on `test@example.com` / `password`. | FR-11, plan §14 DoD |

---

## 7. Non-Functional Requirements

| ID | Category | Requirement | Target |
|---|---|---|---|
| **NFR-01** | Performance | State transition from tap-Submit to first `Submitting` emission | < 50 ms (excluding network) |
| **NFR-02** | Performance | UI feedback during in-flight network call (loading indicator visible) | 100% of network duration; never a frozen UI |
| **NFR-03** | Security | Password storage in memory | Cleared from `LoginUiState` immediately on entering `Submitting` or `Failed` (plan §8) |
| **NFR-04** | Security | Token storage | Encrypted at rest via platform keystore (iOS Keychain `kSecAttrAccessibleAfterFirstUnlock`, Android EncryptedSharedPreferences AES256-GCM) |
| **NFR-05** | Security | Ktor logging | `LogLevel.HEADERS` only — no body logging (already enforced in `KtorClient.kt:18`, T-02-01) |
| **NFR-06** | Accessibility | Form labels and error alerts | Read aloud by TalkBack (Android) and VoiceOver (iOS); error alert receives focus on appearance |
| **NFR-07** | Testability | `LoginViewModel` unit-testability | No `android.*` / `UIKit.*` imports; constructable with a fake `LoginUseCase` in `commonTest` |
| **NFR-08** | Maintainability | Design tokens vs raw values | MUST use `DesignTokens.*` for spacing (Android `.dp`, iOS via `\.appTheme`) and `MaterialTheme.typography/colorScheme` (Android) / SwiftUI `Color`/`Font` semantic equivalents (iOS) for type and color. Mirrors `GreetingScreen.kt` precedent. |

---

## 8. Data Model

### 8.1 Public types (Kotlin, `commonMain`)

```kotlin
// :shared-core/.../data/remote/auth/AuthApi.kt
interface AuthApi {
    suspend fun login(email: String, password: String): UserSession
}

data class UserSession(
    val userId: String,
    val token: String,
)

class AuthException(message: String) : RuntimeException(message)
```

```kotlin
// :shared-core/.../data/auth/SessionStore.kt
interface SessionStore {
    val session: StateFlow<UserSession?>
    suspend fun save(session: UserSession)
    suspend fun read(): UserSession?
    suspend fun clear()
}
```

> **Refinement (2026-05-19).** Shipped as `interface SessionStore` rather than the `expect class` originally sketched here. Reason: `commonTest` constructs `SessionStore` directly in four test files; the interface keeps those tests portable via an in-line `FakeSessionStore` private class, whereas an `expect class` with Android's Context-taking actual would require a JVM-only `actual` or major test churn. Architectural intent is unchanged — one common API, two platform implementations (`EncryptedSessionStore` on Android, `KeychainSessionStore` on iOS), bound via Koin platform modules. The `session: StateFlow` accessor was added to the contract for reactive auth gating; the three suspend methods match the original §8.1 spec.

```kotlin
// :shared-app/.../auth/login/LoginUiState.kt
sealed interface LoginUiState {
    data class Editing(
        val email: String = "",
        val password: String = "",
        val emailError: String? = null,
        val passwordError: String? = null,
        val isSubmitEnabled: Boolean = false,
    ) : LoginUiState

    data class Submitting(val email: String, val password: String) : LoginUiState

    data class Failed(
        val email: String,
        val password: String,   // always "" — kept in the type for shape symmetry
        val message: String,
    ) : LoginUiState

    data object Succeeded : LoginUiState
}
```

### 8.2 Persistence schema (no SQLDelight changes)

`SessionStore` is **key/value, not relational** — does not touch `AppDatabase`. No `.sq` files added.

| Platform | Storage | Key | Value |
|---|---|---|---|
| Android | `EncryptedSharedPreferences` (`androidx.security.crypto`) | `"user_session"` | JSON-serialized `UserSession` |
| iOS | Keychain (`SecItemAdd`/`SecItemCopyMatching`) | service: `"dev.viethung.skeleton.auth"`, account: `"current"` | UTF-8 JSON of `UserSession` |

**Why JSON over individual fields?** Future-proof for adding `expiresAt`, `refreshToken` (§16 out-of-scope items) without migrating storage.

---

## 9. Architecture

### 9.1 Data flow

```
   [Compose LoginScreen]                      [SwiftUI LoginScreen]
        │ onSubmit / onChange                      │ onSubmit / onChange
        ▼                                          ▼
        ─────────── LoginViewModel  (commonMain) ───────────
                       │  state: StateFlow<LoginUiState>
                       │  - onEmailChange / onPasswordChange
                       │  - onSubmit / onErrorDismissed
                       │  - onNavigatedToDashboard
                       ▼
                  LoginUseCase  (commonMain)
                       │  validates non-blank, trims email
                       ▼
                  AuthRepository  (commonMain)
                       │  delegates to AuthApi
                       │  on success: SessionStore.save(...)
                       ▼
                ┌──────────────┬──────────────┐
                AuthApi   SessionStore (expect)
                  │              │
                  │              ├── android: EncryptedSharedPreferences
                  │              └── ios:     Keychain
                  │
                  └── FakeAuthApi (Phase 1)
                      KtorAuthApi (Phase 2, out of scope here)
```

### 9.2 Module placement

| Component | Module + path |
|---|---|
| `AuthApi`, `UserSession`, `AuthException` | `:shared-core/data/remote/auth/` |
| `SessionStore` expect + actuals | `:shared-core/data/auth/` (+ androidMain / iosMain) |
| `AuthRepository` | `:shared-core/data/auth/` |
| `LoginUseCase` | `:shared-core/domain/auth/` |
| `LoginViewModel` + `LoginUiState` + Factory + Helper | `:shared-app/auth/login/` |
| Koin data/domain bindings | `:shared-core/di/AuthModule.kt` |
| Koin VM binding | `:shared-app` `authVmModule` (Plan §9) |

### 9.3 iOS lifecycle pattern (`IosViewModelStoreOwner`)

Mirror the existing contract verbatim — `iosApp/iosApp/Common/IosViewModelStoreOwner.swift:14`:
- `@StateObject` (never `@ObservedObject`) — D-12 / Pitfall 1+2.
- `deinit` clears the store → cancels `viewModelScope` coroutines.
- `owner.viewModel(factory: LoginViewModelFactoryKt.loginViewModelFactory)` follows `GreetingViewModelFactory.kt:23` exactly (top-level `val Factory` resolves use case from Koin, constructs VM inside `create()`).

---

## 10. Dependencies

### 10.1 Already present in `gradle/libs.versions.toml`
| Dependency | Version | Purpose |
|---|---|---|
| `kotlin` | 2.3.21 | Kotlin compiler |
| `androidx-lifecycle-viewmodel` | 2.10.0 | Shared `ViewModel` base class |
| `kotlinx-coroutines-core` | 1.10.2 | `StateFlow`, `viewModelScope` |
| `kotlinx-serialization-json` | 1.10.0 | JSON for `UserSession` persistence |
| `koin-core` | 4.2.1 | DI |
| `ktor` (client) | 3.4.0 | HTTP (future `KtorAuthApi`) |
| `turbine` | 1.2.1 | `StateFlow` testing |
| `kotest-assertions` | 5.9.1 | Test assertions |
| `kotlinx-coroutines-test` | 1.10.2 | `runTest`, `StandardTestDispatcher` |

### 10.2 New dependencies needed
| Dependency | Module | Coordinate | Why |
|---|---|---|---|
| `androidx.security:security-crypto` | `:shared-core` `androidMain` | `androidx.security:security-crypto:1.1.0-alpha06` (or current GA) | `EncryptedSharedPreferences` for token storage |
| (iOS) `Security.framework` | `:shared-core` `iosMain` | First-party framework (cinterop or direct expect/actual) | Keychain access |

⚠️ Both additions MUST be added via `gradle/libs.versions.toml` per CLAUDE.md §2 ("`libs.versions.toml` is the single source for every version").

---

## 11. Cross-Platform Bindings — Code Contracts

### 11.1 Factory (Kotlin)
```kotlin
// :<module>/.../auth/login/LoginViewModelFactory.kt
val loginViewModelFactory: ViewModelProvider.Factory = object : ViewModelProvider.Factory {
    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: KClass<T>, extras: CreationExtras): T {
        val useCase = KoinPlatformTools.defaultContext().get().get<LoginUseCase>()
        return LoginViewModel(useCase) as T
    }
}
```
**Pattern source:** `shared-app/.../greeting/GreetingViewModelFactory.kt:23` (CR-05 / D-12 lifecycle contract).

### 11.2 Compose binding (Android)
```kotlin
@Composable
fun LoginScreen(onSuccess: () -> Unit, viewModel: LoginViewModel = koinViewModel()) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    LaunchedEffect(state) {
        if (state is LoginUiState.Succeeded) { onSuccess(); viewModel.onNavigatedToDashboard() }
    }
    // when (state) { ... } — see plan §10
}
```

### 11.3 SwiftUI binding (iOS) — follow the SKIE-less helper pattern

Login adds `LoginViewModelHelper.kt` (in the same module as `LoginViewModel`) mirroring `GreetingViewModelHelper.kt`:
- `fun createLoginViewModel(store: ViewModelStore): LoginViewModel` — hides `KClass` from the K/N Obj-C bridge.
- `fun subscribeLoginState(vm: LoginViewModel, onState: (LoginUiState) -> Unit): Job` — replaces `for await s in vm.state`.

Swift consumes them in `LoginScreen.swift`:
- `LoginViewModelHelperKt.createLoginViewModel(store: owner.viewModelStore)`
- `LoginViewModelHelperKt.subscribeLoginState(vm: vm) { state in uiState = state }` — store the returned `Kotlinx_coroutines_coreJob?` and cancel in `.onDisappear`.
- State branching uses `as?` casts: `if let editing = uiState as? LoginUiState.Editing { ... }`.

No Combine, no `@Published` bridge. Reference: `GreetingScreen.swift:5-30`. Re-enabling SKIE later is additive — `for await` / `onEnum` become alternatives, not replacements.

---

## 12. Testing Strategy (summary — full plan in QA doc)

| Layer | Framework | Coverage target |
|---|---|---|
| `LoginViewModel` state machine | `kotlin.test` + Turbine + `StandardTestDispatcher` | All 4 state branches, both error paths, dismissal, navigation reset |
| `LoginUseCase` validation | `kotlin.test` | Blank email → throws; blank password → throws; trims email |
| `AuthRepository` | `kotlin.test` with fake `AuthApi` + fake `SessionStore` | Save called on success; save NOT called on failure |
| `SessionStore` android | Android instrumented | Round-trip survives process kill |
| `SessionStore` ios | XCTest | Round-trip survives app re-launch |
| `LoginScreen` Compose | Compose UI test | Submit disabled when empty; alert appears on failure |
| `LoginScreen` SwiftUI | XCTest (XCUI) | Same scenarios as Compose |

**Test placement** — `kotlin.test.Test` NOT `org.junit.Test` (D-17 / Pitfall 18; enforced in `shared-app/build.gradle.kts:55-60`).

---

## 13. Out of Scope (explicit non-goals)

1. **Real backend** (`KtorAuthApi`). Plan §16 item 1. Swap-in via Koin module change only.
2. **Token refresh / 401 interceptor.** Plan §16 item 2.
3. **"Remember me" / biometric unlock.** Plan §16 item 3.
4. **Forgot-password flow.** Plan §16 item 4.
5. **Sign-up flow.** Plan §16 item 5.
6. **Social login** (Google/Apple/Facebook).
7. **MFA / 2FA.**
8. **Account lockout** after N failed attempts.
9. **Analytics / telemetry** on login events.
10. **Internationalization** of error messages — English-only for v1.

---

## 14. Open Decisions Needed

These must be resolved **before implementation starts**. Each is presented as a binary choice with the leaning highlighted.

### 14.A — Module placement for `LoginViewModel` (resolved as A2)

`LoginViewModel` lives in `:shared-app`, mirroring `GreetingViewModel`. Rationale:

- **`:shared-components` is a published Maven artifact** (`shared-components/build.gradle.kts:83-107`) reserved for the four named reusable widgets — forms, amount input, sidebar navigation, notifications. Auth is not one of them; shipping it there would force every downstream consumer to inherit product-specific auth types.
- **Login is product-specific**, not a domain-agnostic widget. Different products cloned from this skeleton will diverge on auth (SSO, magic link, MFA, biometrics).
- **`:shared-app` is the showcase module** (CLAUDE.md §3 — "showcase wiring; never published") where pattern demonstrations live. `GreetingViewModel` is already there.

Plan §3 has been updated to match.

### 14.B — Design tokens (resolved)

`shared-core/src/commonMain/kotlin/dev/viethung/core/theme/DesignTokens.kt` shipped in commit `ff2e505` (Phase 2 Wave 1). The Android Greeting reference is hybrid: `DesignTokens.*.dp` for spacing, `MaterialTheme.typography.*` and `MaterialTheme.colorScheme.*` for type and semantic colors (`GreetingScreen.kt:19, :44, :49, :52`). The iOS adapter exposes tokens via the `\.appTheme` environment value (`GreetingScreen.swift:8, :15, :40`).

**Decision: Login MUST use `DesignTokens.*` for spacing and `MaterialTheme` / SwiftUI semantic equivalents for type and color.** No `// TODO(D-03)` comments needed.

### 14.C — Navigation (resolved as C2)

`MainActivity.kt` has no `NavHost`. `ContentView.swift:7` already wraps a single screen in `NavigationStack { GreetingScreen(...) }`. A full nav graph is out of scope for Phase 1.

**Decision: hoist `isAuthenticated: Boolean` state to the root composable (Android) and the root `NavigationStack` view (iOS).** Login signals `Succeeded` → root flips the flag → root swaps `LoginScreen` for `DashboardPlaceholder`. Refactor to a proper nav graph when Phase 5 navigation lands. The VM's `onSuccess` callback decouples it from any nav choice.

### 14.D — SKIE status (resolved)

`shared-components/build.gradle.kts:66-71`: `skie { isEnabled = false }` (waiting on Kotlin 2.3.21 support). The skeleton has already adopted a SKIE-less iOS bridge pattern in commit `d61d3f2`: per-VM Kotlin helpers wrap `ViewModelProvider.create(...)` and `StateFlow.collect(...)` for Swift consumption. iOS builds today.

**Decision: Login follows the SKIE-less helper pattern (§11.3) — same as `GreetingViewModelHelper.kt`.** No Combine wrapper required; iOS code volume is comparable to the SKIE version, not doubled. Re-enabling SKIE later is additive and requires no rewrite of this code.

---

## 15. Risks

| ID | Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|---|
| **R-01** | Engineer drifts from the SKIE-less helper pattern (e.g., wraps `StateFlow` in Combine, accesses `vm.state` from Swift directly) — iOS code won't compile, or breaks when SKIE is later re-enabled. | Low | Medium | Code review: verify `LoginViewModelHelper.kt` exists with `createLoginViewModel(store:)` + `subscribeLoginState(vm:, onState:)`; verify `LoginScreen.swift` uses `as?` casts and the helper job pattern. Reference: `GreetingViewModelHelper.kt` + `GreetingScreen.swift:5-30`. |
| **R-02** | Token leaks to logs via `Throwable.toString()` or stack traces (especially `AuthException` carrying error context). | Medium | High | FR-10 + AC-11 grep gate. Code review checklist item. `AuthException` constructor must not accept the password as a parameter. |
| **R-03** | `EncryptedSharedPreferences` is in `1.1.0-alpha06` as of writing — alpha status. API may change. | Medium | Medium | Pin the version; abstract behind `SessionStore` so swap-out is one-file. Track alpha → stable promotion. |
| **R-04** | iOS Keychain access fails when device is locked at first launch (`kSecAttrAccessibleWhenUnlocked`). | Low | Medium | Use `kSecAttrAccessibleAfterFirstUnlock` (NFR-04). Document the trade-off. |
| **R-05** | Mock `delay(800)` masks real-world timeout behavior; first `KtorAuthApi` integration will surface new failure modes. | High | Low | Design FR-05 to handle generic exceptions today (timeouts, JSON parse) so the Phase 2 swap is a no-op in `LoginViewModel`. |
| **R-06** | Junior engineer following the plan introduces `koinViewModel<LoginViewModel>()` directly on iOS via SwiftUI — bypassing `IosViewModelStoreOwner` — and breaks the lifecycle contract. | Medium | High | Document in plan §11 (already present) + code review must check `@StateObject` + `IosViewModelStoreOwner`. |
| **R-07** | Plan §3 originally placed `LoginViewModel` in `:shared-components`; engineer reads the plan first and wires the VM into the wrong (published) module. | Low | Medium | Plan §3 has been updated to `:shared-app` (PRD §14.A resolution). Code review: verify Koin binding lives in `appModule` / `authVmModule`, not `componentsModule`. |

---

## 16. Phase Breakdown

Sequential, per plan §4. Each phase produces a verifiable artifact:

| # | Phase | Output | Verify |
|---|---|---|---|
| 1 | State design | `LoginUiState.kt` compiles in target module | `./gradlew :<module>:compileKotlinMetadata` |
| 2 | Mock API | `AuthApi.kt`, `FakeAuthApi.kt`, `UserSession.kt` | Unit test asserts success + failure paths |
| 3 | Repository + UseCase | `AuthRepository.kt`, `LoginUseCase.kt` | Unit tests (happy path, blank inputs) |
| 4 | `SessionStore` expect/actual | `commonMain` expect + Android + iOS actuals | Round-trip test on each platform |
| 5 | `LoginViewModel` + Factory | `LoginViewModel.kt`, `LoginViewModelFactory.kt` | `commonTest` with Turbine — 4 branches |
| 6 | Koin wiring | `AuthModule.kt` (data/domain, `:shared-core`) + `authVmModule` (VM, `:shared-app`) | `startKoin {}` succeeds in both apps |
| 7 | Android Compose UI | `LoginScreen.kt` | `:androidApp:installDebug`, manual smoke |
| 8 | iOS SwiftUI UI + helper | `LoginScreen.swift` + `LoginViewModelHelper.kt` (mirrors Greeting pattern, §11.3) | `⌘R` in Xcode, manual smoke |
| 9 | Navigation hook-up | Root-level `isAuthenticated` flag flips on success | Manual end-to-end smoke |

---

## 17. Traceability Matrix

| FR | ACs | Plan section | New file(s) |
|---|---|---|---|
| FR-01 | AC-01 | §5, §10, §11 | `LoginUiState.kt`, `LoginScreen.kt`/`.swift` |
| FR-02 | AC-01, AC-02 | §5, §8 | `LoginViewModel.kt` (`onEmailChange`/`onPasswordChange`) |
| FR-03 | AC-03, AC-04 | §8 (`onSubmit`) | `LoginViewModel.kt` |
| FR-04 | AC-03 | §10 (`SubmittingOverlay`) | `LoginScreen.kt`/`.swift` |
| FR-05 | AC-05, AC-06 | §8 (two-catch) | `LoginViewModel.kt` |
| FR-06 | AC-05 | §5, §8 | `LoginUiState.kt`, `LoginViewModel.kt` |
| FR-07 | AC-07 | §8 (`onErrorDismissed`) | `LoginViewModel.kt` |
| FR-08 | AC-08 | §8 (`onNavigatedToDashboard`) | `LoginViewModel.kt` |
| FR-09 | AC-04, AC-09 | new (extends plan §7) | `SessionStore.kt` (+ actuals) |
| FR-10 | AC-11 | plan §15 ❌ | enforced by code review |
| FR-11 | AC-10, AC-12 | §11, §10 | both `LoginScreen` files share same VM |
| FR-12 | AC-11 (extended) | CLAUDE.md §2 | enforced by `./gradlew check` |

---

## 18. References

- [`LOGIN-IMPLEMENTATION-PLAN.md`](./LOGIN-IMPLEMENTATION-PLAN.md) — technical plan, 498 lines
- [`../../CLAUDE.md`](../../CLAUDE.md) — §1 Core Principles, §2 Coding Standards, §4 Platform Bindings
- [`../../architecture.md`](../../architecture.md) — §Platform Bindings (`IosViewModelStoreOwner` contract)
- [`../../README.md`](../../README.md) — setup, prerequisites, commands
- `shared-app/.../greeting/GreetingViewModel.kt:14` — reference VM (sealed `UiState`)
- `shared-app/.../greeting/GreetingViewModelFactory.kt:23` — reference Factory (CR-05 / D-12)
- `iosApp/iosApp/Common/IosViewModelStoreOwner.swift:14` — iOS lifecycle host (D-12 / Pitfall 1+2)
- `shared-core/.../network/KtorClient.kt:10` — HTTP client config (T-02-01 no body logging)
- `gradle/libs.versions.toml` — version catalog (single source per CLAUDE.md §2)
- `shared-app/.../greeting/GreetingViewModelHelper.kt` — reference SKIE-less iOS bridge (commit `d61d3f2`)

---

**Next docs in pipeline:** UI specs (`docs/auth/LOGIN-UI.md`), QA test plan (`docs/auth/LOGIN-QA.md`), edge-case scenarios (`docs/auth/LOGIN-SCENARIOS.md`).
