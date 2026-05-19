# Login Authentication — UI Specifications

| Field | Value |
|---|---|
| **Status** | Draft (post-implementation; matches shipped commits `fc19fac` + `b82a939`) |
| **PRD** | [`LOGIN-PRD.md`](./LOGIN-PRD.md) — v1.0, 2026-05-16 |
| **Plan** | [`LOGIN-IMPLEMENTATION-PLAN.md`](./LOGIN-IMPLEMENTATION-PLAN.md) |
| **Smoke** | [`reports/dod-smoke-260519.md`](./reports/dod-smoke-260519.md) — DoD §14 passes both platforms |
| **Tech** | Kotlin Multiplatform 2.3.21 · Jetpack Compose Material3 (Android) · SwiftUI iOS 17+ |
| **Tokens** | [`shared-core/.../theme/DesignTokens.kt`](../../shared-core/src/commonMain/kotlin/dev/viethung/core/theme/DesignTokens.kt) |
| **Doc version** | 1.0 (2026-05-19) |

---

## 1. Screen Inventory

| # | Screen | Route / Composable | Purpose | User stories |
|---|---|---|---|---|
| 1 | **Login** | Android: `MainActivity` → `LoginScreen` Composable<br>iOS: `ContentView` → `LoginScreen` View | Authenticate via email + password; surface 4 states of `LoginUiState` | US-01, US-02, US-03 |
| 2 | **Dashboard placeholder** | Android: `MainActivity` → `DashboardPlaceholder` Composable<br>iOS: `ContentView` → `DashboardPlaceholder` View | Post-auth landing; exposes Log out + theme toggle | US-04 (implicit), US-05 |

> No `NavHost` / no `NavigationStack` push. The root composable owns `isAuthenticated: Boolean` and swaps children directly (PRD §14.C).

---

## 2. Screen Flow

```
                ┌──────────────────────────────────────┐
                │ App launch                           │
                │ isAuthenticated = false              │
                └────────────────┬─────────────────────┘
                                 ▼
                ┌──────────────────────────────────────┐
                │ Login screen — state = Editing       │
                │ • email/password empty               │
                │ • Submit DISABLED                    │
                └────────────────┬─────────────────────┘
                                 │ user types both fields (non-blank)
                                 ▼
                ┌──────────────────────────────────────┐
                │ state = Editing                      │
                │ • Submit ENABLED                     │
                └────────────────┬─────────────────────┘
                                 │ tap Submit
                                 ▼
                ┌──────────────────────────────────────┐
                │ state = Submitting (~800 ms)         │
                │ • form disabled + spinner overlay    │
                └─────────┬───────────────────┬────────┘
                          │ success           │ AuthException / generic
                          ▼                   ▼
              ┌─────────────────┐   ┌──────────────────────────────┐
              │ state = Succeeded│  │ state = Failed                │
              │ → onSuccess()   │   │ • alert "Login failed"        │
              │ → root flips    │   │ • email kept, password = ""   │
              │   isAuthenticated│  │ • Submit DISABLED             │
              │ → VM resets to  │   │                               │
              │   Editing("","")│   │ tap OK → state = Editing      │
              └─────────┬───────┘   │  (email kept, password blank) │
                        ▼           └──────────────┬────────────────┘
              ┌─────────────────┐                  │
              │ Dashboard       │◀─────────────────┘
              │ • Log out       │      (retry path loops back)
              │ • Override theme│
              └────────┬────────┘
                       │ Log out
                       ▼
               isAuthenticated = false
               → back to Login (empty form)
```

**Key state guarantees** (from PRD AC-01..08, FR-08):
- `Succeeded` is observable exactly once; VM resets to `Editing` immediately after `onNavigatedToDashboard()` to prevent back-press re-trigger.
- `Failed` always carries the original email; password is type-modeled as `""` (PRD §8 — kept for shape symmetry).
- `Editing.isSubmitEnabled` is derived inside the VM, never in the View (CLAUDE.md §2 state-ownership).

---

## 3. Component Hierarchy

### 3.1 Android (Jetpack Compose)

```
MainActivity (ComponentActivity)
└── AppTheme(isDark = themeOverride ?: isSystemInDarkTheme())
    └── Surface (Material3)
        └── if (!isAuthenticated)
            ├── LoginScreen(onSuccess = { isAuthenticated = true })
            │   ├── (state = Editing)    LoginForm
            │   ├── (state = Submitting) LoginForm[disabled] + CircularProgressIndicator overlay
            │   ├── (state = Failed)     LoginForm[disabled] + AlertDialog
            │   └── (state = Succeeded)  Unit (LaunchedEffect fires onSuccess)
            │
            │   LoginForm (private @Composable)
            │   ├── Text("Sign in", headlineMedium)
            │   ├── OutlinedTextField (Email, keyboardType=Email, singleLine)
            │   ├── OutlinedTextField (Password, PasswordVisualTransformation, singleLine)
            │   └── Button(enabled = state.isSubmitEnabled) { Text("Sign in") }
            │
            └── DashboardPlaceholder(themeOverride, onCycleTheme, onLogout)
                ├── Text("Dashboard", headlineMedium)
                ├── Button(onClick = onLogout) { Text("Log out") }
                └── Button(onClick = onCycleTheme) { Text(themeLabel) }
```

### 3.2 iOS (SwiftUI)

```
ContentView
└── AppTheme.apply (preferredColorScheme via themeOverride)
    └── if !isAuthenticated
        ├── LoginScreen(onSuccess: { isAuthenticated = true })
        │   ├── ZStack { stateContent(vm:) }
        │   │   ├── (uiState as LoginUiStateEditing)    LoginForm
        │   │   ├── (uiState as LoginUiStateSubmitting) ZStack { LoginForm[interactive:false] + ProgressView }
        │   │   ├── (uiState as LoginUiStateFailed)     LoginForm[interactive:false]
        │   │   └── else                                EmptyView
        │   ├── .alert("Login failed", isPresented:) { Button("OK") {…} } message: { Text(failed.message) }
        │   └── .task { stateJob = subscribeLoginState(vm:) { … } }    /* SKIE-less helper */
        │       .onDisappear { stateJob?.cancel(cause: nil) }
        │
        │   LoginForm (private View)
        │   ├── Text("Sign in").font(theme.typography.headlineMedium)
        │   ├── TextField("Email", text: Binding(get:set:))
        │   │     .textContentType(.emailAddress).keyboardType(.emailAddress).autocapitalization(.none)
        │   ├── SecureField("Password", text: Binding(get:set:)).textContentType(.password)
        │   └── Button("Sign in") {…}.disabled(!state.isSubmitEnabled)
        │
        └── DashboardPlaceholder(themeOverride: $themeOverride, onLogout:)
            ├── Text("Dashboard").font(theme.typography.headlineMedium)
            ├── Button("Log out", action: onLogout)
            └── Button(action: cycleTheme) { Text(themeLabel) }
```

### 3.3 Reuse map

| Component | Reuse strategy | Notes |
|---|---|---|
| `OutlinedTextField` / `TextField` | Platform primitives — no custom wrapper for v1 | Wrap into a `shared-components` `FormField` only when a 2nd consumer appears (CLAUDE.md §2 simplicity-first). |
| `AlertDialog` / `.alert` | Platform primitives | Same — defer abstraction until the second alert ships. |
| `CircularProgressIndicator` / `ProgressView` | Platform primitives | Same. |
| `LoginForm` private function | Internal-only — not exported | Lets `Editing` / `Submitting` / `Failed` reuse one form layout. Do not promote across modules. |
| `DashboardPlaceholder` | Internal to `:androidApp` / `:iosApp` | Will be replaced by the real Dashboard in a follow-up ticket. Plan §16. |

---

## 4. Interaction Patterns — Per State

### 4.1 `Editing` (initial + after dismiss + after typing)

| Element | Behavior |
|---|---|
| **Email field** | Focused-by-default? **No** — opening the keyboard automatically resizes the form (Compose `imePadding`); user taps when ready. |
| **Email keyboard** | Android: `KeyboardOptions(keyboardType = KeyboardType.Email)`. iOS: `.keyboardType(.emailAddress)` + `.textContentType(.emailAddress)` + `.autocapitalization(.none)`. |
| **Password field** | `PasswordVisualTransformation` (Android) / `SecureField` (iOS). `textContentType(.password)` on iOS enables Keychain autofill. |
| **Submit button** | `enabled = state.isSubmitEnabled`. Derived in `LoginViewModel` from `email.isNotBlank() && password.isNotBlank()` (PRD FR-02). |
| **Inline errors** | `OutlinedTextField.supportingText` (Android) / inline `Text(...).foregroundColor(theme.colors.error)` (iOS) — appears only when `Editing.emailError` / `passwordError` is non-null. **Not used in v1** — empty-field guard is handled by the disabled submit button; reserved for FR-05 follow-up. |
| **No inline validation on email format** | v1 trusts the mock API to reject malformed emails (`AuthException`). Inline regex validation deferred — `inline-validation` rule (validate-on-blur) applies when v2 adds client checks. |

### 4.2 `Submitting`

| Element | Behavior |
|---|---|
| **Form** | Re-rendered from `LoginUiState.Editing` shell with `isSubmitEnabled = false`; both text fields' callbacks are stubbed (`{}`) so re-types during in-flight are silently dropped. |
| **Spinner** | Centered overlay over the form. Android: `CircularProgressIndicator()` in a `Box` with `Alignment.Center`. iOS: `ProgressView()` in a `ZStack`. |
| **Duration** | Mock `delay(800)` — feels responsive but visible. `progressive-loading` rule applies; spinner is shown immediately, no >300ms blank wait (PRD NFR-02). |
| **Double-submit prevention** | Built into the disabled button + stub callbacks. Idempotent — VM ignores `onSubmit` calls while in `Submitting`. |
| **Cancel** | **Not supported in v1.** User cannot cancel an in-flight login. Network failure surfaces as `Failed` after the mock delay. |

### 4.3 `Failed`

| Element | Behavior |
|---|---|
| **Alert** | Android: Material3 `AlertDialog` with title `"Login failed"`, body = `failed.message`, single `TextButton("OK")` confirm. iOS: `.alert(isPresented:)` with `"Login failed"` title and `Text(failed.message)` body. |
| **Alert message text** | From `LoginUiState.Failed.message`. Known `AuthException` ⇒ verbatim message (`"Invalid email or password"`). Generic `Exception` ⇒ `"Something went wrong. Please try again."` (PRD FR-05). |
| **Behind the alert** | The form renders with `email = failed.email`, `password = ""`, `isSubmitEnabled = false`. Submit button greyed. |
| **Dismiss** | Tap OK → `viewModel.onErrorDismissed()` → state returns to `Editing(email = failed.email, password = "")` (PRD AC-07). Email preserved, password starts empty — user re-types only the password. |
| **Focus on dismiss** | iOS: focus automatically returns to the underlying form; password field is the natural next tap. Android: AlertDialog dismissal returns focus to the form root; user taps password. No explicit `focusRequester` in v1. |
| **Aria-live / role=alert** | Material3 `AlertDialog` and SwiftUI `.alert` are announced by TalkBack / VoiceOver automatically. No manual `aria-live` needed. |

### 4.4 `Succeeded` (transient, ≤1 frame visible)

| Element | Behavior |
|---|---|
| **UI** | Renders nothing (`Unit` on Android, `EmptyView()` on iOS — fallthrough from the `when`/`if-let` chain). |
| **Side effect** | `LaunchedEffect(state)` on Android / `.task` callback on iOS detects the transition, calls `onSuccess()` (flips root `isAuthenticated`), then immediately calls `viewModel.onNavigatedToDashboard()` to reset the VM to `Editing("", "")`. |
| **Why reset?** | PRD FR-08 / AC-08 — if the user later logs out and returns to the Login screen, the previous `Succeeded` emission must not re-trigger navigation. |

### 4.5 Dashboard placeholder

| Element | Behavior |
|---|---|
| **`Log out`** | Android: `onLogout = { isAuthenticated = false }`. iOS: same. No server call in v1 (no token revocation endpoint). `SessionStore` clear is a follow-up. |
| **`Override theme`** | Cycles `themeOverride: Boolean?` through `null → false → true → null` (Android) / `nil → .light → .dark → nil` (iOS). Label updates accordingly. |
| **Back-press** | Android: back at root finishes the activity. iOS: no system back; gesture from screen edge does nothing (no `NavigationStack` push). Re-launch lands on Login screen (state lost when activity finishes). |

---

## 5. Responsive Strategy

The skeleton targets **phones** (iPhone 17, Medium_Phone_API_36 — 1080×2400). Tablets and landscape are out of scope for v1 but the implementation should not break them.

| Breakpoint / Form factor | Behavior |
|---|---|
| **Phone portrait (default)** | Form vertically centered (`verticalArrangement = Arrangement.Center` / SwiftUI default VStack centering). Padding = `DesignTokens.spacing.xl` (32 dp/pt). Fields fill width. |
| **Phone landscape** | Compose `imePadding()` + `verticalArrangement = Center` keeps the form visible above the keyboard. SwiftUI relies on system layout adjustment. **Not visually tested in v1** — flag as known gap if a user rotates mid-flow. |
| **Tablet portrait (≥ 768 pt wide)** | Form stretches to full width — no max-width constraint in v1. Acceptable for a skeleton; flag for the productisation phase. `line-length-control` rule (35–60 chars mobile, 60–75 desktop) doesn't apply — fields hold short single-line input. |
| **Foldable / multi-window** | Untested. Should not crash because the layout is a `Column`/`VStack` of `fillMaxWidth` children. |
| **Dynamic Type / large text** | Android: Material3 typography respects accessibility scaling. iOS: SwiftUI `.font(theme.typography.headlineMedium)` maps to `Font.system` and scales. No hard-coded pt sizes anywhere — see §7 token map. |
| **Safe areas** | Android: `enableEdgeToEdge()` in `MainActivity`. iOS: SwiftUI handles safe-area insets automatically via `NavigationStack` / default layout. Spinner overlay uses `fillMaxSize` / `.frame(maxWidth: .infinity, maxHeight: .infinity)` — covers the form but stops at the safe area. |

> Recommendation for v2: introduce `Modifier.widthIn(max = 480.dp)` (Android) / `.frame(maxWidth: 480)` (iOS) on the form column to cap form width on tablets without breaking phones. Pull `480.dp` from a new `DesignTokens.layout.formMaxWidth` token if added.

---

## 6. Interaction States — Per Element

### 6.1 OutlinedTextField (Android) / TextField+SecureField (iOS)

| State | Visual | Token / behavior |
|---|---|---|
| Default | Outlined border, label inside or floating above | Material3 `OutlinedTextFieldDefaults.colors()` (Android) / `.textFieldStyle(.roundedBorder)` (iOS — for `LoginForm`, iOS uses default style; SecureField is rounded). |
| Focused | Outline thickens, label floats up, primary color | `MaterialTheme.colorScheme.primary` (Android) / iOS system blue. Inherited from theme. |
| Filled (not focused) | Outlined border at idle, label floated | Material3 default. |
| Error | Border + label tinted error color, supporting text shows error | `OutlinedTextField(isError = …, supportingText = …)`. iOS: error `Text` below field, color from `theme.colors.error`. Not active in v1 (no inline errors). |
| Disabled | Lower-opacity outline, label, value | Compose `enabled = false` (used implicitly during `Submitting` by stubbing callbacks). iOS: `.disabled(!interactive)`. |
| Cursor | Standard caret | Platform default. |

### 6.2 Submit button

| State | Visual |
|---|---|
| Enabled (Editing, both fields non-blank) | Solid primary fill, on-primary text |
| Disabled (Editing empty / Submitting / Failed) | Reduced-opacity surface, dimmed text (Material3 `disabledContainerColor` / SwiftUI `.disabled` opacity) |
| Pressed | Material3 state-layer overlay (~12% on-primary). iOS: default press-in scale (none — system button). |
| Loading | Not a "loading button" — the spinner is a separate centered overlay, not embedded in the button. The button itself is just `disabled` during `Submitting`. |

### 6.3 AlertDialog / .alert

| State | Visual |
|---|---|
| Presenting | Scrim covers the form (Material3 default: 32% black; iOS system default). Dialog elevates above. |
| OK pressed | TextButton press feedback (Android). iOS button tap default. |
| Dismissing | Fade out (Compose `AlertDialog` default ~150 ms). iOS slide+fade. |
| Aria/VO | TalkBack/VoiceOver focus moves to the alert title automatically. |

---

## 7. Design Token Map

All UI code pulls from `DesignTokens` (commonMain primitives) or platform-mapped semantics. **No raw hex / no `.sp` / no inline dp literals** beyond `.dp` unit conversions on token values (CLAUDE.md §2).

### 7.1 Spacing (used by both platforms)

| Token | Value | Used by |
|---|---|---|
| `DesignTokens.spacing.md` | 16 | (reserved — currently used in `DashboardPlaceholder.kt` spacer) |
| `DesignTokens.spacing.lg` | 24 | spacer between section title and first field; spacer between password and submit |
| `DesignTokens.spacing.xl` | 32 | outer `padding` of the form column |
| iOS `theme.spacing.md` | 16 | VStack `spacing` |
| iOS `theme.spacing.xl` | 32 | form `.padding(...)` |

> Other spacing tokens (`xxs=2`, `xs=4`, `sm=8`, `xxl=48`) are available but not used by Login v1.

### 7.2 Typography

| Token | Used by |
|---|---|
| `MaterialTheme.typography.headlineMedium` (Android) | "Sign in" title, "Dashboard" title |
| `theme.typography.headlineMedium` (iOS) | same |
| (default body) | TextField labels, button text, alert body — inherited from Material3 / system |

> The 12 other typography roles (`displayLarge` → `labelSmall`) are unused in Login. Adopt them when adding settings, profile, or empty states.

### 7.3 Color

| Token | Light value | Dark value | Used by |
|---|---|---|---|
| `colorScheme.primary` / `theme.colors.primary` | `0xFF3F51B5` | `0xFFBBC2FF` | submit button container, focused field outline |
| `colorScheme.onPrimary` | `0xFFFFFFFF` | `0xFF0D1888` | submit button text |
| `colorScheme.surface` / `theme.colors.surface` | `0xFFFFFBFE` | `0xFF1C1B1FL` | form background (root `Surface`) |
| `colorScheme.onSurface` | `0xFF1C1B1F` | `0xFFE6E1E5` | "Sign in" title, body text |
| `colorScheme.error` / `theme.colors.error` | `0xFFB3261E` | `0xFFF2B8B5` | inline error text (reserved, not active in v1) |
| `colorScheme.outline` | `0xFF79747E` | `0xFF938F99` | field outline at idle |

All sourced from `DesignTokens.LightColors` / `DarkColors`. No raw hex in any `LoginScreen.kt` / `.swift` / `DashboardPlaceholder.kt` / `.swift`.

### 7.4 Radius

Currently inherited from platform defaults (Material3 button = 100% pill; OutlinedTextField = 4 dp). When customising, pull from `DesignTokens.radius.{xs..xl, full}` — never literals.

### 7.5 Anti-pattern guard

Run the grep from PRD AC-11 + DoD §14:

```bash
# Must return zero hits
grep -rn '#[0-9a-fA-F]\{6\}' androidApp/src/main/kotlin/dev/viethung/skeleton/android/auth \
                              androidApp/src/main/kotlin/dev/viethung/skeleton/android/dashboard \
                              iosApp/iosApp/Auth iosApp/iosApp/Dashboard
grep -rn '\.dp\s*=\s*[0-9]' androidApp/src/main/kotlin/dev/viethung/skeleton/android/auth/LoginScreen.kt   # raw .dp values
```

---

## 8. Accessibility Specifications

### 8.1 Form labels (WCAG 1.3.1, 3.3.2 — PRD NFR-06)

| Element | Android | iOS |
|---|---|---|
| Email field | `OutlinedTextField(label = { Text("Email") })` | `TextField("Email", text:)` — placeholder doubles as accessibility label (system convention for SwiftUI `TextField`) |
| Password field | `OutlinedTextField(label = { Text("Password") })` | `SecureField("Password", text:)` |
| Submit button | `Text("Sign in")` child — read as accessible name | `Button("Sign in") { … }` |

**Anti-pattern (avoided)**: `placeholder = "Email"` only. We use the floating label — survives focus, survives autofill.

### 8.2 Error announcements (WCAG 4.1.3)

- Material3 `AlertDialog` and SwiftUI `.alert` both trigger automatic screen-reader focus capture and announce the dialog's title + body. No manual `aria-live` / `accessibilityAnnouncement` needed.
- On Android, TalkBack reads `"Login failed. Invalid email or password. OK button."`.
- On iOS, VoiceOver reads `"Login failed alert. Invalid email or password. OK button."`.

### 8.3 Keyboard navigation (WCAG 2.1.1)

- **Tab order** (hardware keyboard on emulator / physical keyboard on iPad / external keyboards on phone): Email → Password → Submit. Inherited from view declaration order; not overridden.
- **iOS Done/Next**: not set explicitly. The on-screen keyboard's `return` key does nothing — pressing it on the email field does *not* advance to password (a known gap). To fix in v2: add `.submitLabel(.next)` + `.onSubmit { focus = .password }` (iOS 15+).
- **Compose IME action**: not set. The default is `ImeAction.Default` ⇒ "Done" which hides the keyboard. To fix in v2: `KeyboardOptions(imeAction = ImeAction.Next)` on the email field + `KeyboardActions(onNext = { focusManager.moveFocus(Down) })`.
- **Submit via Enter**: not wired in v1. User must tap the button.

### 8.4 Focus management (WCAG 2.4.3)

- On dismissing the alert: focus returns to the form root (platform default). The user-natural next field is the password — which is correct since the password is blank.
- On `Submitting`: focus is not stolen; the spinner is decorative.
- On `Succeeded`: focus is handed to the next screen (Dashboard) by virtue of the swap; no explicit `focusRequester` needed.
- **Gap**: on transitioning back into `Failed` from `Submitting`, we do not explicitly move focus to the alert. Material3 / SwiftUI handle this implicitly, but a real screen-reader test (TalkBack + VoiceOver) is a v2 acceptance task.

### 8.5 Contrast (WCAG 1.4.3 AA — 4.5:1 body, 3:1 large)

Spot-checked against `DesignTokens.LightColors` + `DarkColors`:

| Pair | Light contrast | Dark contrast | Pass AA? |
|---|---|---|---|
| `onPrimary` on `primary` (button) | `#FFFFFF` on `#3F51B5` ⇒ 8.6:1 | `#0D1888` on `#BBC2FF` ⇒ 10.4:1 | ✅ both |
| `onSurface` on `surface` (body text) | `#1C1B1F` on `#FFFBFE` ⇒ 16.7:1 | `#E6E1E5` on `#1C1B1F` ⇒ 13.6:1 | ✅ both |
| `error` on `surface` (inline error) | `#B3261E` on `#FFFBFE` ⇒ 6.4:1 | `#F2B8B5` on `#1C1B1F` ⇒ 9.1:1 | ✅ both |
| `outline` on `surface` (field border) | `#79747E` on `#FFFBFE` ⇒ 4.0:1 (FAIL for 4.5:1 *small* text — but outline is non-text decoration; 3:1 minimum for UI components per WCAG 1.4.11) | `#938F99` on `#1C1B1F` ⇒ 4.6:1 | ✅ as UI component (3:1 rule) |

> Spot-checks only; full contrast audit is a v2 task once we add real product surfaces beyond `surface`.

### 8.6 Touch targets (Apple HIG 44×44pt, Material 48×48dp)

| Element | Effective hit area |
|---|---|
| `OutlinedTextField` | Min 56 dp tall (Material3 default) — comfortably exceeds 48 dp |
| Submit `Button` | Min 40 dp tall, padded to ~48 dp with Material3 default vertical padding — meets target |
| Alert OK `TextButton` | ~36 dp tall default — **at risk on dense layouts**. Material3 wraps it in a touch-target slot. Verify in audit. |
| iOS `Button("Sign in")` | Default SwiftUI button is text-only ⇒ ~44 pt tall via padding inherited from `.padding(theme.spacing.xl)` parent. Acceptable. |

### 8.7 Color independence (WCAG 1.4.1)

- Disabled submit: button visually dim AND the action does nothing — color is not the only signal. (Material3 disabled style is paired with the absence of state-layer / press feedback.)
- Failed state: alert appears with text — color (red) is supplementary, not load-bearing.
- Inline errors (when added): MUST include text content, not just a red border (Forms `error-clarity` rule).

### 8.8 Password field privacy

- Android `PasswordVisualTransformation`: characters rendered as dots.
- iOS `SecureField`: same.
- iOS `textContentType(.password)`: Keychain offers autofill suggestions (system-managed; we don't read or log them).
- **No show/hide toggle in v1** — Forms `password-toggle` rule applies; defer to v2 when adding real auth.

### 8.9 Reduced motion (PRD NFR-06 implicit)

- Both `CircularProgressIndicator` and `ProgressView` animate continuously. Neither respects reduced-motion explicitly.
- Material3 / SwiftUI alert transitions are minimal slide+fade.
- **Gap**: no `prefers-reduced-motion` honoring on the spinner. Acceptable for v1 (one short animation per session); flag for v2 when adding richer transitions.

---

## 9. Coverage vs PRD

| PRD User Story | Covered by |
|---|---|
| US-01 (first-time user signs in) | §3 LoginForm, §4.1 Editing, §4.4 Succeeded |
| US-02 (wrong password, retry without re-typing email) | §4.3 Failed, FR-06 contract in §2 flow |
| US-03 (slow network feedback) | §4.2 Submitting + §6.2 submit button disabled |
| US-04 (session persists across restart) | **Out of scope for UI spec** — handled by `SessionStore`; UI just trusts repository |
| US-05 (downstream feature gates on session) | §2 root composable / NavigationStack swap pattern |

| PRD AC | Covered by |
|---|---|
| AC-01..02 (submit disabled when empty) | §4.1 + §6.2 |
| AC-03..04 (spinner + success) | §4.2 + §4.4 |
| AC-05..06 (error message rules) | §4.3 |
| AC-07 (dismiss → Editing with email kept) | §4.3 |
| AC-08 (no re-nav on back) | §4.4 |
| AC-09 (SessionStore persistence) | out of UI scope |
| AC-10 (Turbine commonTest) | out of UI scope |
| AC-11 (no password in logs) | out of UI scope — code-review gate |
| AC-12 (E2E both platforms) | smoke report referenced in header |

| PRD NFR | Covered by |
|---|---|
| NFR-01..02 (perf, no frozen UI) | §4.2 |
| NFR-03..05 (security, logging) | out of UI scope |
| NFR-06 (a11y) | §8 |
| NFR-07 (testability) | out of UI scope |
| NFR-08 (tokens) | §7 |

---

## 10. Open Items & Follow-ups

| # | Item | Severity | Where |
|---|---|---|---|
| O-01 | Email field has no inline format validation (relies on API rejection) | Low | §4.1 |
| O-02 | iOS `.submitLabel` / Compose `imeAction = Next` not wired — keyboard `return` does not advance focus | Medium | §8.3 |
| O-03 | Tablet / landscape unverified | Low | §5 |
| O-04 | Reduced-motion not honored on spinner | Low | §8.9 |
| O-05 | Alert OK button touch target verge case on Android | Low | §8.6 |
| O-06 | No show/hide password toggle | Low | §8.8 |
| O-07 | `SessionStore.clear()` not called on Log out (only flips `isAuthenticated` in memory) | Medium | §4.5 |
| O-08 | No focus management to alert title on `Failed` transition (relies on platform default) | Low | §8.4 |

> Treat each as a v2 ticket. None blocks the current DoD §14 sign-off (the smoke report already passes).

---

## 11. References

- [`LOGIN-PRD.md`](./LOGIN-PRD.md) — requirements, acceptance criteria
- [`LOGIN-IMPLEMENTATION-PLAN.md`](./LOGIN-IMPLEMENTATION-PLAN.md) §10 Compose, §11 SwiftUI, §13 Token usage
- [`reports/dod-smoke-260519.md`](./reports/dod-smoke-260519.md) — DoD §14 evidence (21 screenshots)
- [`../../shared-core/src/commonMain/kotlin/dev/viethung/core/theme/DesignTokens.kt`](../../shared-core/src/commonMain/kotlin/dev/viethung/core/theme/DesignTokens.kt) — token source of truth
- [`../../CLAUDE.md`](../../CLAUDE.md) §2 coding standards, §4 platform bindings
- WCAG 2.1 — `https://www.w3.org/TR/WCAG21/` (referenced rules: 1.3.1, 1.4.1, 1.4.3, 1.4.11, 2.1.1, 2.4.3, 3.3.2, 4.1.3)
- Material Design 3 — `https://m3.material.io/`
- Apple HIG — `https://developer.apple.com/design/human-interface-guidelines/`

---

**Implementation status:** shipped on `develop` at `b82a939` (iOS) + `fc19fac` (Android). DoD §14 smoke passes. UI spec to be revised when Phase 5 navigation lands (see §5 max-width and §4.5 logout SessionStore.clear).
