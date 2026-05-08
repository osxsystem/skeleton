# Requirements: Skeleton

**Defined:** 2026-05-08
**Core Value:** Cloning this skeleton must give a new product, on day one, a correct KMP scaffold and the four UI primitives that every mobile product re-implements badly: forms, amount input, navigation, and notifications.

## v1 Requirements

Each requirement is a behaviour the *template* must exhibit when consumed by a cloned product or by the showcase app — not just code-on-disk. Mapped to roadmap phases by `/gsd-roadmapper`.

### Scaffold (SCAF)

- [ ] **SCAF-01**: Multi-module Gradle project compiles green: `:shared-core`, `:shared-components`, `:shared-app`, `:androidApp` build with no warnings on a clean machine
- [ ] **SCAF-02**: Xcode project compiles an iOS framework named `SkeletonKit` (not `shared`) and the iOS app links and runs
- [ ] **SCAF-03**: All KMP modules apply `com.android.kotlin.multiplatform.library` plugin (AGP 9 requirement); no `com.android.library` in KMP modules
- [ ] **SCAF-04**: `libs.versions.toml` pins Kotlin / KSP / SKIE / AGP as a single locked unit with comment `# Update these four together`
- [ ] **SCAF-05**: `IosViewModelStoreOwner` declared `@StateObject` in iOS root view; `deinit` clears the `ViewModelStore` and logs a deinit message verified to fire on navigation pop
- [ ] **SCAF-06**: Koin DI graph wires `:shared-core` modules; sample ViewModel resolvable from both Android and iOS entry points
- [ ] **SCAF-07**: Ktor client scaffolded (no real endpoints yet) with platform engines (OkHttp Android, Darwin iOS) and JSON serialization
- [ ] **SCAF-08**: SQLDelight schema scaffolded with `-lsqlite3` linker flag on iOS (or `BundledSQLiteDriver`); a hello-world query runs green on both platforms
- [ ] **SCAF-09**: CI on GitHub Actions: Android build/test on `ubuntu-latest` and iOS build/test on `macos-14` with `timeout-minutes: 30`; both pass on a hello-world feature commit
- [ ] **SCAF-10**: `kotlin.test` test harness; one `commonTest` test passes against both Android and iOS targets
- [ ] **SCAF-11**: Generated `SkeletonKit.framework/Headers/` contains no `Any?` from generic erasure on a sample sealed `UiState` (validation gate against SKIE generics trap)

### Theming (THEME)

- [ ] **THEME-01**: `DesignTokens` in `:shared-core/commonMain` defines colors (Long ARGB), typography (`TextStyleToken`), spacing, and radius — primitives only, no Compose or SwiftUI types
- [ ] **THEME-02**: `LightColors` and `DarkColors` palettes defined; every color is `Long` with `L` suffix; `commonTest` asserts no constant overflowed to negative
- [ ] **THEME-03**: Compose `AppTheme` adapter maps tokens to `MaterialTheme` (`ColorScheme`, `Typography`, `Shapes`) on Android
- [ ] **THEME-04**: SwiftUI `AppTheme` adapter maps tokens to environment values (`Color`, `Font`, spacing modifiers) on iOS
- [ ] **THEME-05**: Dark mode follows system setting on both platforms; switching the system theme updates both apps without restart

### Forms (FORM)

- [ ] **FORM-01**: `FormViewModel` in `commonMain` runs a per-field state machine (Pristine → Dirty → Valid → Invalid)
- [ ] **FORM-02**: Validation runs on field blur and on form submit; errors render below the relevant field on both platforms
- [ ] **FORM-03**: Submit CTA shows loading state and disables itself during async submit; cannot be double-tapped
- [ ] **FORM-04**: Keyboard avoidance: focused field remains visible above the software keyboard on both platforms
- [ ] **FORM-05**: Focus chain: `Next` IME action advances to the next field; `Done` on the last field dismisses the keyboard
- [ ] **FORM-06**: First empty field receives focus programmatically on screen mount
- [ ] **FORM-07**: Password field with show/hide toggle on both platforms; raw password value never appears in `UiState`
- [ ] **FORM-08**: Per-field native keyboard types: email, phone, numeric, URL — selectable per `FormField` instance
- [ ] **FORM-09**: Each field exposes accessible labels; validation errors are announced by TalkBack (Android) and VoiceOver (iOS)
- [ ] **FORM-10**: Validation messages use a `UiText` abstraction (localizable resource keys, not raw strings in `commonMain`)
- [ ] **FORM-11**: Compose forms use `rememberTextFieldState()` (Compose 1.7 API), not `MutableState<String> + onValueChange` — prevents IME composing-text race

### Amount Input (AMT)

- [ ] **AMT-01**: `AmountInputViewModel` exposes raw `BigDecimal` value separate from formatted display string; raw integer cents is never leaked into `UiState`
- [ ] **AMT-02**: Thousands separator detected from device locale at runtime (`,` for en-US, ` ` for fr-FR, `.` for de-DE)
- [ ] **AMT-03**: Decimal separator detected from device locale at runtime
- [ ] **AMT-04**: Currency symbol placement (prefix or suffix) per locale rendered correctly
- [ ] **AMT-05**: Digits-right-to-fill UX (POS-terminal style): new digits enter at right and shift previous digits left
- [ ] **AMT-06**: Fixed 2-decimal precision by construction; the field never displays a malformed value like `1.2.3`
- [ ] **AMT-07**: Keyboard is `KeyboardType.NumberPassword` (Android) / `.numberPad` (iOS) — multiple decimals or non-digits structurally impossible
- [ ] **AMT-08**: Empty / zero state renders placeholder, not literal `0.00`
- [ ] **AMT-09**: Max-digit guard (configurable cap) prevents overflow on paste or rapid input
- [ ] **AMT-10**: Cross-locale tests pass on `en-US`, `de-DE`, `fr-FR` (`commonTest` for the formatter; UI tests for at least one locale per platform)

### Navigation Drawer (NAV)

- [ ] **NAV-01**: `NavDrawerViewModel` in `commonMain` owns route tree, current route, and expanded-group state as `StateFlow`
- [ ] **NAV-02**: Android renders `ModalNavigationDrawer`; iOS renders a custom sheet drawer (no `NavigationSplitView` on phones)
- [ ] **NAV-03**: Hamburger / menu button in the top app bar is present as a visible open affordance — not gesture-only
- [ ] **NAV-04**: Edge-swipe to open works on Android; iOS opens via hamburger only (system back-swipe gesture is preserved)
- [ ] **NAV-05**: Tap on scrim dismisses the drawer (modal behaviour)
- [ ] **NAV-06**: Currently selected route is visually highlighted in the drawer
- [ ] **NAV-07**: Two-level collapsible groups: parents expand/collapse using `AnimatedVisibility` (Compose) / conditional `if` (SwiftUI) — collapsed children are removed from the accessibility tree, not just alpha-hidden
- [ ] **NAV-08**: Drawer items expose accessible labels and selection state to TalkBack and VoiceOver
- [ ] **NAV-09**: Deep link to a nested route opens the drawer with the correct branch pre-expanded and the target item highlighted
- [ ] **NAV-10**: `NavDrawerViewModel` emits `NavIntent.RouteSelected(route)` events; platform UI (NavController on Android, NavigationPath on iOS) executes navigation — no `NavController` reference in `commonMain`

### In-App Notifications (INAPP)

- [ ] **INAPP-01**: `NotificationViewModel` owns a notification queue using `MutableSharedFlow(replay = 0, extraBufferCapacity = 64)` — one notification displayed at a time
- [ ] **INAPP-02**: Snackbar component (auto-dismiss, single action) on both platforms, styled from `DesignTokens`
- [ ] **INAPP-03**: Toast component (no-action, short duration) on both platforms; Android implementation does **not** use `Toast.makeText` (deprecated for app-context)
- [ ] **INAPP-04**: Banner component (persistent until dismissed, up to two actions) on both platforms
- [ ] **INAPP-05**: Inline alert component (static, embedded in layout) on both platforms
- [ ] **INAPP-06**: Auto-dismiss after configurable timeout; honors Android Accessibility Timeout setting
- [ ] **INAPP-07**: Manual dismiss button on every floating notification — WCAG persistent-affordance requirement
- [ ] **INAPP-08**: Accessibility announcements: TalkBack live-region (Android), `UIAccessibility.post(.announcement)` (iOS)
- [ ] **INAPP-09**: Auto-dismiss is paused while TalkBack or VoiceOver focus is on the notification (Material accessibility spec)
- [ ] **INAPP-10**: Theme variants — success / warning / error / info — derive all colors from `DesignTokens`, no hex literals

### Push Notifications (PUSH)

- [ ] **PUSH-01**: FCM token registration + `onNewToken` refresh on Android; new tokens POST to the server stub `/token` endpoint on every refresh
- [ ] **PUSH-02**: APNs registration + `didRegisterForRemoteNotificationsWithDeviceToken` on iOS; FCM iOS token derived after `apnsToken` is set
- [ ] **PUSH-03**: Foreground push display routes through the in-app notification component (re-uses INAPP-* infrastructure)
- [ ] **PUSH-04**: Background / killed-state push renders as a system notification on both platforms
- [ ] **PUSH-05**: Android notification channels created in `Application.onCreate()` — before any push can arrive
- [ ] **PUSH-06**: Runtime `POST_NOTIFICATIONS` permission requested on Android 13+ via the opt-in flow
- [ ] **PUSH-07**: `UNUserNotificationCenter` permission requested on iOS via the opt-in flow
- [ ] **PUSH-08**: Pre-permission opt-in screen demonstrates value before triggering the OS prompt — both platforms
- [ ] **PUSH-09**: Tap on push notification deep-links to a specific route; routing works from cold-start (push fires before ViewModel init) — covered by a cold-start smoke test
- [ ] **PUSH-10**: Minimal Ktor server stub exposes `POST /token` (store device token by user/device id) and `POST /send` (call FCM HTTP v1 + APNs HTTP/2)
- [ ] **PUSH-11**: Server stub runs locally via `./gradlew :server:run` (one command) **and** ships with a `Dockerfile` + GitHub Actions deploy recipe targeting a free-tier host (Fly.io or Render) — local default, deploy documented
- [ ] **PUSH-12**: End-to-end push verified: send via stub → device receives → tap → app opens to correct deep link. iOS verified on a physical device (sim cannot receive push); Android verified on emulator + device.

### Networking Demo (NET)

- [ ] **NET-01**: Showcase makes a real Ktor call against a public API (final API selected at plan-phase 6 kickoff — likely a free currency-rates API to double as data for amount-input)
- [ ] **NET-02**: Network results render via `StateFlow<UiState>` with explicit loading / success / error states
- [ ] **NET-03**: Network errors surface to the user via the in-app notification component (re-uses INAPP-*)

### Persistence Demo (DB)

- [ ] **DB-01**: SQLDelight schema persists at least one entity in the showcase (e.g. saved searches, recently-viewed items, draft data)
- [ ] **DB-02**: At least one showcase screen reads from and writes to SQLDelight on both Android and iOS

### Showcase App (SHOW)

- [ ] **SHOW-01**: Android showcase app builds and demonstrates every component family — runs on emulator and physical device
- [ ] **SHOW-02**: iOS showcase app builds and demonstrates every component family — runs on simulator and physical device
- [ ] **SHOW-03**: Showcase home lists each component family with a link to its demo screen
- [ ] **SHOW-04**: Showcase exposes a runtime light/dark toggle that reflects through `DesignTokens` end-to-end

### Published Artifacts (PUB)

- [ ] **PUB-01**: `:shared-core` publishes to Maven Central via the vanniktech plugin under a domain-verified group ID (final ID resolved before Phase 7)
- [ ] **PUB-02**: `:shared-components` publishes to Maven Central via the vanniktech plugin
- [ ] **PUB-03**: iOS umbrella framework (`SkeletonKit`) publishes as a Swift Package via KMMBridge to a separate `Package.swift` repository
- [ ] **PUB-04**: `:shared-app` (showcase) consumes published modules with `implementation` (not `api`) — never published itself; verified via a `publishToMavenLocal` dry-run check
- [ ] **PUB-05**: A fresh project can add the Android artifact via Gradle OR the SPM package via Xcode and consume any of the four component families without copying source
- [ ] **PUB-06**: GitHub Actions: separate publish workflows for Maven Central (`ubuntu-latest`) and SPM/KMMBridge (`macos-14`); both run on tag push

## v1.x Requirements

Deferred to a follow-up release. Tracked but not in the current roadmap.

### Forms

- **FORM-x01**: Async debounced field validation (e.g. username availability) with cancellation
- **FORM-x02**: Multi-step wizard with progress indicator; state survives step navigation
- **FORM-x03**: Autosave draft to SQLDelight or DataStore on background kill
- **FORM-x04**: Field dependency / conditional visibility ("Other" → text field appears)
- **FORM-x05**: Paste sanitization (strip non-digits from phone, trim whitespace from name)

### Amount Input

- **AMT-x01**: RTL layout correctness for Arabic / Hebrew locales
- **AMT-x02**: Negative-number entry (debit/credit toggle)
- **AMT-x03**: Currency switcher (multi-currency app pattern)
- **AMT-x04**: Paste sanitization (strip symbols, deduplicate decimal separators)
- **AMT-x05**: Haptic feedback on max-digit reached

### Navigation Drawer

- **NAV-x01**: Badge counts on nav items (unread messages / pending actions)
- **NAV-x02**: Tablet persistent rail mode at ≥600dp width breakpoint
- **NAV-x03**: Scroll-position restore when drawer re-opens
- **NAV-x04**: Programmatic scroll-to-selected on drawer open

### In-App Notifications

- **INAPP-x01**: Global overlay anchor (notifications above sheets, modals, full-screen covers)
- **INAPP-x02**: Priority lanes (urgent notifications bump queue head)
- **INAPP-x03**: Swipe-to-dismiss gesture
- **INAPP-x04**: Spring / physics-based entry animation

### Push

- **PUSH-x01**: Notification categories with inline reply (iOS `UNTextInputNotificationAction`)
- **PUSH-x02**: Android notification actions (reply, mark read) via `RemoteInput`
- **PUSH-x03**: Silent / background push for data refresh (`content-available`)
- **PUSH-x04**: Rich media push (image attachment)

## v2+ Requirements

- **FORM-y01**: Rich input masks (IBAN, phone, date)
- **AMT-y01**: BigDecimal precision beyond 2 decimals (configurable)
- **NAV-y01**: 3+ depth recursive nav tree
- **INAPP-y01**: Notification history log screen with SQLDelight backing
- **PUSH-y01**: FCM topic subscriptions for cohort broadcast

## Out of Scope

Explicit exclusions. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Compose Multiplatform for iOS UI | `architecture.md` non-goal — SwiftUI is the iOS UI; we accept the duplication |
| C/C++ shared core | `architecture.md` non-goal |
| Third platform target (desktop / web) | KMP keeps the door open without paying for it now |
| Tablet-first or desktop-class adaptive layouts | Phones are primary; tablets just get a larger drawer. Persistent rail at ≥600dp is v1.x |
| Real backend / auth server | Push server stub is `POST /token` + `POST /send` only — anything more is a product, not a primitive |
| OAuth / social login in showcase | Not one of the four primitives; auth is a separate concern |
| Custom keyboard replacement | Breaks password managers, system autofill, hardware keyboards, accessibility |
| Real-time as-you-type validation | Validate on blur instead — industry-standard UX |
| Multiple simultaneous floating notifications | Visual chaos and conflicting a11y announcements; queue serialises one at a time |
| `Toast.makeText` with application context (Android) | Deprecated 12+, leak-prone; use Snackbar or custom overlay |
| `SharedFlow(replay > 0)` for notification events | Re-emits on collector restart (e.g. rotation) → duplicate notifications |
| Persistent rail on phones | Material 3 reserves persistent side nav for ≥600dp |
| `Double` for financial arithmetic | IEEE 754 loses cents at scale — `BigDecimal` only |
| Raw password storage in `StateFlow` | ViewModel state is observable; passwords must never appear in `UiState` |
| Hilt, KAPT, KSP1 | Hilt is JVM-only; KAPT and KSP1 incompatible with AGP 9 |
| `firebase-*-ktx` modules | Removed at Firebase BoM v34 — depend on main modules directly |
| CocoaPods for iOS distribution | SPM only — single distribution channel reduces maintenance |

## Traceability

Phase mapping populated by `/gsd-roadmapper`.

| Requirement | Phase | Status |
|-------------|-------|--------|
| (populated by roadmapper) | | |

**Coverage:**
- v1 requirements: 67 total
- Mapped to phases: 0 (pending roadmap)
- Unmapped: 67 ⚠️ (will resolve at roadmap creation)

---
*Requirements defined: 2026-05-08*
*Last updated: 2026-05-08 after initialization*
