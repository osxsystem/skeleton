# Feature Research

**Domain:** KMP mobile skeleton — reusable native UI components (Android Compose + iOS SwiftUI)
**Researched:** 2026-05-08
**Confidence:** HIGH (forms, amount input, notifications) / MEDIUM (tree-sidebar nav)

---

## Component Family 1: Forms

Complex multi-field forms with validation, multi-step flows, and autosave.

### Table Stakes (Users Expect These)

| Feature | Why Expected | Complexity | Dependencies |
|---------|--------------|------------|--------------|
| Field-level error display beneath each input | iOS/Android system controls (UITextField, Compose TextField) both render helpers below field; deviating from this surprises users | S | field-state-machine |
| On-blur validation (validate when field loses focus, not on every keystroke) | Industry-standard UX — showing errors while typing is aggressive; deferring to blur is the expected contract | S | field-state-machine |
| Submit-time full-form re-validation | Users expect all errors to surface on tap of the primary CTA even if some fields were never touched | S | field-state-machine |
| Disable / show loading on CTA during async submit | Prevents double-submit; universally expected on any form with a network call | S | — |
| Keyboard avoidance / scroll-to-focused-field | On both platforms, the form must scroll so the active field is not obscured by the software keyboard | M | — |
| Focus chaining (Next key advances to next field, Done on last) | Android: `ImeAction.Next`/`Done` on `KeyboardOptions`; iOS: `@FocusState` enum + `.onSubmit`; expected by any touch-typist | M | — |
| Programmatic initial focus (auto-focus first empty field on mount) | Native modals and sheets always land focus on the first input; missing this feels broken | S | — |
| SecureField / password toggle (show/hide) | Mandatory for any password or PIN field; app store rejections have historically flagged its absence | S | — |
| Platform-native keyboard types per field (email, phone, numeric, URL) | Compose `KeyboardType`; SwiftUI `.keyboardType`; wrong keyboard type is immediately noticeable | S | — |
| Accessible labels + error announcements (TalkBack / VoiceOver) | Each field needs a semantic label; error state must be announced via `contentDescription` (Android) / `.accessibilityLabel` + `UIAccessibility.post` (iOS) | M | field-state-machine |
| `UiText` abstraction for validation messages | Validation errors must be localizable; raw strings baked into the shared ViewModel fail at localization | S | — |

### Differentiators (Competitive Advantage)

| Feature | Value Proposition | Complexity | Dependencies |
|---------|-------------------|------------|--------------|
| Debounced async-field validation (e.g. username availability) | Real-world forms need server checks; the field-state machine needs an `AsyncValidating` state and cancellation | M | field-state-machine, coroutine cancellation |
| Multi-step wizard with progress indicator | Large registration or onboarding flows are split into steps; state must survive step navigation | L | field-state-machine, shared ViewModel |
| Autosave draft to SQLDelight / DataStore | Prevents data loss on background kill; required for any long-form (insurance, finance, onboarding) | L | SQLDelight persistence, autosave timer |
| Field dependency / conditional visibility | Show/hide fields based on prior answers; e.g. "Other" text field appears only when "Other" is selected | M | field-state-machine |
| Paste sanitization (strip non-numeric chars from phone, trim whitespace from name) | Users paste from clipboard constantly; without cleanup the field state machine sees invalid raw data | S | field-state-machine |
| Rich input masks (phone, date, IBAN) | Speeds entry and reduces errors; `VisualTransformation` on Compose; `UITextFieldDelegate` on iOS | L | — |

### Anti-Features

| Anti-Feature | Why Avoid | Alternative |
|--------------|-----------|-------------|
| Inline validation on every keystroke (real-time as-you-type errors) | Immediately showing "invalid email" while the user is still typing `jane@` is aggressive and reduces perceived quality | Validate on blur; show success state (green checkmark) on-change only after first blur |
| Custom keyboard replacement | Replacing the system keyboard breaks password managers, system autofill, hardware keyboard support, and accessibility | Use `keyboardType` + `VisualTransformation` to shape input within the system keyboard |
| Storing raw password state in `StateFlow` | ViewModel state is observable; password characters must never appear in `UiState` | Clear the field immediately after submission; store only a boolean `passwordEntered: Boolean` |
| Global form-level submit disabled until all fields valid | Forces users to fill every field before receiving any feedback; particularly bad for optional fields | Disable only after first submit attempt; validate per-field on blur |

### Feature Dependencies — Forms

```
field-state-machine (Pristine→Dirty→Valid→Invalid transitions)
    └──required-by──> on-blur validation
    └──required-by──> submit-time validation
    └──required-by──> field error display
    └──required-by──> async debounced validation (adds AsyncValidating state)
    └──required-by──> multi-step wizard (state survives step change)
    └──required-by──> conditional field visibility

focus-chain management
    └──required-by──> keyboard avoidance
    └──required-by──> programmatic initial focus

autosave timer ──requires──> field-state-machine + SQLDelight persistence
multi-step wizard ──requires──> field-state-machine + navigation component (for step routing)
```

---

## Component Family 2: Currency-Aware Amount Input

A specialised text field that bridges a raw `Decimal` value (in the ViewModel) and a locale-formatted display string (in the UI).

### Table Stakes (Users Expect These)

| Feature | Why Expected | Complexity | Dependencies |
|---------|--------------|------------|--------------|
| Locale-correct thousands separator | In `en_US` it is `,`; in `fr_FR` a space; in `de_DE` a `.` — users immediately notice when grouping is wrong for their locale | M | locale detection |
| Locale-correct decimal separator | `.` in most English locales, `,` in most European — wrong separator on a numeric field causes parse failures | M | locale detection |
| Currency symbol placement (prefix vs suffix) | `$` precedes in US; `kr` follows in DK; `€` follows in most EU — symbol position is locale-driven | M | locale detection |
| Digits-right-to-fill UX (payment-terminal style) | Banking and fintech users expect the field to behave like a POS terminal: new digits enter at the right, pushing existing digits left. Any other interaction model produces confusion | M | — |
| Fixed 2-decimal precision with no free cursor | Free-form currency entry leads to `$1.234` or `$1.2` — the fixed-precision model prevents malformed values by construction | M | — |
| `Decimal` type (not `Double`) for the internal value | `Double` arithmetic loses precision (`0.1 + 0.2 != 0.3`); all financial values must use `Decimal` / `BigDecimal` | S | shared ViewModel |
| `NumberPassword` / `.numberPad` keyboard (Android / iOS respectively) | `KeyboardType.Decimal` on Compose does not prevent multiple decimal separators; `NumberPassword` restricts to digits only, giving the component full formatting control | S | — |
| Programmatic value vs display value separation | The ViewModel holds a raw `Decimal`; the UI layer holds the display string; they must never be the same variable | M | field-state-machine |
| Zero / empty state (show placeholder, not `0.00`) | A field pre-filled with `0.00` looks like an already-entered value; placeholder is more conventional | S | — |
| Max digit guard (prevent overflow) | Without a ceiling, users can enter numbers that overflow currency range (e.g. `9999999999999.99`); must silently cap or reject | S | — |

### Differentiators (Competitive Advantage)

| Feature | Value Proposition | Complexity | Dependencies |
|---------|-------------------|------------|--------------|
| RTL layout correctness (Arabic, Hebrew locales) | Symbol and digit order must both respect RTL; iOS `.currency` format style handles this if `Locale` is passed correctly; Compose needs explicit RTL layout direction | M | locale detection |
| Negative number entry (debit/credit toggle) | Accounting UIs require signed amounts; a toggle button flips the sign; the `Decimal` in the ViewModel can hold negative values natively | M | — |
| Currency switcher (multi-currency app) | Fintech apps let users choose a currency code; the formatter re-formats the display when the code changes; the raw `Decimal` is unchanged | L | currency-rates API |
| Paste sanitization (strip non-numeric, deduplicate decimal separator) | Users paste `"$1,234.56"` from other apps; the paste handler must strip symbols, separators, and re-parse | M | — |
| Haptic feedback on max-digit reached | Platform convention: `UISelectionFeedbackGenerator` / Compose `HapticFeedbackType`; reinforces the constraint without an error message | S | — |

### Anti-Features

| Anti-Feature | Why Avoid | Alternative |
|--------------|-----------|-------------|
| `Double` for financial arithmetic | IEEE 754 floating point loses cents at scale; produces wrong totals in aggregate views | Use `Decimal` (Swift) / `BigDecimal` (JVM) in shared ViewModel; format only at the UI boundary |
| Free-form decimal text entry with post-parse validation | Allows the user to type `"1.2.3"` or `"1,2,3"`; requires complex regex to clean; still fails in edge cases | Digits-only keyboard + VisualTransformation/custom formatter constructs the display string at every keystroke |
| Embedding currency formatting logic in a Composable / SwiftUI View | Formatting logic tested only on one platform; locale bugs manifest differently per platform | Put formatter in `shared/commonMain` as a `CurrencyFormatter` use case; call from both UI layers |
| Showing the raw cents integer in the `UiState` | Leaks implementation detail; the ViewModel should expose `displayValue: String` and `rawDecimal: Decimal` separately | Keep raw `Decimal` internal to the ViewModel; expose both a parsed value and a formatted display hint |

### Feature Dependencies — Amount Input

```
locale detection (Locale.current / Locale.getDefault())
    └──required-by──> thousands separator
    └──required-by──> decimal separator
    └──required-by──> currency symbol placement
    └──required-by──> RTL correctness

CurrencyFormatter (commonMain use case)
    └──required-by──> programmatic value / display value separation
    └──required-by──> paste sanitization
    └──required-by──> digits-right-to-fill UX

Decimal type in shared ViewModel
    └──required-by──> CurrencyFormatter
    └──required-by──> negative number support
```

---

## Component Family 3: Tree-Sidebar Navigation Drawer

A collapsible modal drawer on phones showing a two-level (or deeper) nav tree, doubling as a larger persistent rail on tablets.

### Table Stakes (Users Expect These)

| Feature | Why Expected | Complexity | Dependencies |
|---------|--------------|------------|--------------|
| Gesture-driven open/close (edge swipe from leading edge) | Material 3 spec and iOS HIG both specify edge-swipe to open a side drawer; removing it surprises muscle memory | M | DrawerState / custom gesture |
| Hamburger / menu button in top app bar as alternative open trigger | Edge swipe is hard to discover; a visible affordance is mandatory for first-time users and accessibility users who cannot use gestures | S | — |
| Scrim overlay that dismisses drawer on tap (modal behaviour) | `ModalNavigationDrawer` provides this; users expect tapping outside a modal drawer to close it | S | DrawerState |
| Current-route highlighting (selected item visual state) | Users must always know where they are; `NavigationDrawerItem(selected = ...)` provides this; missing it fails basic nav conventions | S | current-route state |
| Collapsible section groups (expand/collapse) | Tree nav implies parent nodes that expand; `AnimatedVisibility` controlled by per-section `expanded` state | M | animated-visibility |
| `AnimatedVisibility` for child branches (not alpha toggling) | Alpha-only hide leaves items in the accessibility tree and allows TalkBack/VoiceOver to read hidden items; `AnimatedVisibility` actually removes them from composition | M | — |
| Smooth open/close animation (follows Material motion spec) | `ModalNavigationDrawer`'s built-in `DrawerState` handles this; custom implementations must match ~250 ms easing | S | — |
| Accessible drawer items (contentDescription, role announcement) | TalkBack must announce item label + selected state; VoiceOver must read `.accessibilityLabel` with selection state | M | — |
| Focus trap inside open drawer (keyboard / switch-access navigation) | Drawer is a modal layer; Tab/Switch access must cycle only within drawer content until dismissed | M | — |
| Deep link support (open app to specific route, highlight correct item) | Push notifications and universal links land on specific screens; the drawer must reflect the active route even when opened from outside the app | M | navigation integration |

### Differentiators (Competitive Advantage)

| Feature | Value Proposition | Complexity | Dependencies |
|---------|-------------------|------------|--------------|
| Badge counts on nav items (unread messages, pending actions) | App-level notification badging on sidebar items is expected in productivity and communication apps; requires a `badge: Int?` param on each item | M | notification state |
| Scroll position restore (remember scroll offset when drawer re-opens) | Long nav trees lose scroll position on close/reopen; storing the `LazyListState` / `ScrollViewProxy` prevents jarring jumps to top | S | — |
| Nested levels beyond two (3+ depth) | Most trees are 2-level; 3+ is rare but the component should accept arbitrary depth by accepting a recursive `NavNode` data structure | L | recursive composable / SwiftUI recursive View |
| Tablet persistent rail mode (same drawer, different presentation) | Architecture doc specifies phones get modal drawer; tablets get it "larger" — this is a layout-width conditional render, not a separate component | M | adaptive layout breakpoint |
| Section header labels with optional dividers | Visual grouping within a long nav tree; low complexity, high perceived quality | S | — |
| Programmatic scroll-to-selected-item on open | When deep linking opens the app mid-tree, the drawer should scroll to make the active item visible | S | scroll state |

### Anti-Features

| Anti-Feature | Why Avoid | Alternative |
|--------------|-----------|-------------|
| Persistent rail on phones | Material 3 explicitly reserves persistent side nav for large-screen breakpoints; a permanent rail on a 360dp phone consumes ~72dp of precious horizontal space | Use `ModalNavigationDrawer` on phones; a `NavigationRail` only at ≥600dp |
| Implementing a custom gesture recogniser that fights system back-swipe (iOS) | iOS system back swipe (NavigationStack) comes from the same screen edge as the drawer open gesture; a conflicting custom recogniser breaks back navigation | Use `UIScreenEdgePanGestureRecognizer` or SwiftUI `.gesture` with `.highPriorityGesture` only when no navigation controller is active |
| Hiding collapsed children with `alpha = 0` / `isHidden` | Items remain in the accessibility tree; screen readers read them aloud; hit testing may still intercept touches | Use `AnimatedVisibility` (Compose) / `if condition { ... }` in SwiftUI to fully remove nodes |
| Putting navigation routing logic in the drawer composable/view | Drawer becomes untestable; routing changes break the component | Drawer emits events (`onItemSelected(NavDestination)`); caller handles routing |

### Feature Dependencies — Tree-Sidebar Navigation

```
NavNode data structure (id, label, icon, children, badge)
    └──required-by──> collapsible groups
    └──required-by──> current-route highlighting
    └──required-by──> badge counts
    └──required-by──> deep-link highlight

AnimatedVisibility per section
    └──required-by──> collapsible groups
    └──required-by──> accessibility correctness (no ghost items)

DrawerState (Compose) / custom binding (SwiftUI)
    └──required-by──> gesture-driven open/close
    └──required-by──> scrim dismiss
    └──required-by──> focus trap

current-route state (from navigation component)
    └──required-by──> current-route highlighting
    └──required-by──> deep-link highlight

adaptive layout breakpoint ──enhances──> tablet persistent rail
badge counts ──requires──> notification state from shared ViewModel
```

---

## Component Family 4a: In-App Notifications

Snackbars, banners, toasts, and inline alerts that appear while the user is inside the app.

### Table Stakes (Users Expect These)

| Feature | Why Expected | Complexity | Dependencies |
|---------|--------------|------------|--------------|
| Snackbar (bottom, auto-dismiss, single action) | Material 3 / iOS HIG standard for transient feedback (delete confirmation, save success, network error) | S | notification-queue |
| Toast (no-action, shorter duration) | Expected for purely informational feedback with no required action; Android has native Toast; iOS requires custom | S | notification-queue |
| Banner / top-sheet (persistent until dismissed, multi-action) | Expected for degraded-state messaging (offline mode, expired session) that must survive until the user acts | M | notification-queue |
| Inline alert (static, embedded in layout, not floating) | Form submission errors, inline warnings; non-floating alerts that live in the view hierarchy | S | — |
| Notification queue (show one at a time, subsequent waits) | `SnackbarHostState` on Compose provides a built-in queue; iOS needs a custom actor-based serialiser | M | — |
| Auto-dismiss after configurable timeout | 2-4s for info; 4-8s for errors; indefinite for actions; must honour Accessibility Timeout setting on Android | S | notification-queue |
| Manual dismiss (explicit "X" button) | Required for WCAG — users who cannot react in time must have a persistent dismiss affordance | S | — |
| Action button(s) on snackbar/banner | "Undo", "Retry", "View" are table-stakes CTA patterns; one action for snackbar, up to two for banners | S | notification-queue |
| Accessibility announcements (TalkBack live-region / VoiceOver `UIAccessibility.post`) | Screen readers must announce appearing notifications; without this blind users miss feedback entirely | M | — |
| TalkBack / VoiceOver: no auto-dismiss while focused | Material accessibility spec: snackbar must not time-out while TalkBack focus is on it | S | — |
| Theme tokens (success/warning/error/info variants) | Colour-coded variants are immediately recognisable; must draw from `DesignTokens` not hard-coded hex | S | DesignTokens / theme bridge |

### Differentiators (Competitive Advantage)

| Feature | Value Proposition | Complexity | Dependencies |
|---------|-------------------|------------|--------------|
| Global overlay anchor (notifications above sheets, modals, full-screen covers) | Pure `Scaffold`-scoped `SnackbarHost` disappears behind bottom sheets; a `WindowInsets`-aware global overlay ensures visibility everywhere | L | platform overlay mechanism |
| Priority lanes (urgent bumps queue head) | Critical errors (session expired, payment declined) should not wait behind an info toast | M | notification-queue |
| Swipe-to-dismiss gesture | Material standard gesture; `SwipeToDismissBox` on Compose; `DragGesture` on SwiftUI | M | notification-queue |
| Notification history / log screen | Useful in complex enterprise apps; in-app list of past alerts that can be reviewed | L | SQLDelight persistence |
| Spring / physics-based entry animation | Feels premium; `spring(dampingRatio = ...)` on Compose; SwiftUI `.animation(.spring(...))` | S | — |

### Anti-Features

| Anti-Feature | Why Avoid | Alternative |
|--------------|-----------|-------------|
| Multiple simultaneous floating notifications | Two snackbars at once creates visual chaos and conflicting accessibility announcements | Single-notification queue; priority lanes for urgency; inline alerts for secondary messages |
| Android `Toast.makeText` with application context | Android 12+ deprecated custom Toast views; app-context Toasts are unreliable in foreground; they leak references | Use `SnackbarHostState` or a custom overlay composable anchored to the `Scaffold` |
| Using `SharedFlow` replay > 0 for notification events | A replay buffer re-emits notifications on collector restart (e.g. screen rotation), causing duplicate snackbars | `SharedFlow(replay = 0)` for one-shot events; `StateFlow` only for persistent UI state |
| Blocking the main thread to show a notification | `showSnackbar()` is a suspending function; calling it on the main thread without a coroutine scope causes ANR | Always call from `rememberCoroutineScope` launch block |

### Feature Dependencies — In-App Notifications

```
notification-queue (serialises multiple enqueue requests)
    └──required-by──> snackbar display
    └──required-by──> toast display
    └──required-by──> banner display
    └──required-by──> auto-dismiss timer
    └──required-by──> priority lanes

DesignTokens / theme bridge
    └──required-by──> success/warning/error/info colour variants

global overlay anchor ──enhances──> all floating notification types
accessibility announcements ──required-by──> TalkBack/VoiceOver no-auto-dismiss rule
```

---

## Component Family 4b: Push Notifications (FCM + APNs)

End-to-end push delivery from a minimal server stub through to the app's in-app routing.

### Table Stakes (Users Expect These)

| Feature | Why Expected | Complexity | Dependencies |
|---------|--------------|------------|--------------|
| FCM token registration + `onNewToken` callback (Android) | Without token refresh handling, stale tokens cause silent delivery failures after app reinstall or data clear | M | FirebaseMessagingService |
| APNs registration + `application(_:didRegisterForRemoteNotificationsWithDeviceToken:)` (iOS) | Required for any push delivery; token must be sent to server on every app launch | M | AppDelegate / UIApplicationDelegateAdaptor |
| Foreground notification handling (show in-app banner while app is open) | iOS silently drops notifications received while foregrounded unless `userNotificationCenter(_:willPresent:)` returns `.banner`; Android requires a custom foreground service or in-app notification | M | in-app notification component |
| Background / killed-state system notification display | System handles this automatically if notification payload is correct; developer must not fight it | S | correct FCM/APNs payload |
| Deep-link routing from notification tap | Users tap notifications to navigate to specific content; `Intent.ACTION_VIEW` (Android) / `onOpenURL` + `UNUserNotificationCenterDelegate` (iOS) | M | navigation component |
| Notification channels (Android 8+) | Required by Android OS; app must declare channels at startup before first notification arrives; wrong timing loses the initial permission prompt | M | — |
| Runtime `POST_NOTIFICATIONS` permission request (Android 13+) | Android 13 requires explicit opt-in just like iOS; apps targeting API 33+ must request this | S | — |
| UNUserNotificationCenter permission request (iOS) | Permission is one-shot on iOS; lost if declined; must be requested after value is demonstrated | S | opt-in flow |
| Pre-permission opt-in screen (both platforms) | iOS opt-in rate climbs ~20% with a value-explaining pre-prompt; best practice for any app that depends on push engagement | M | — |
| Token refresh propagation to server | New token invalidates old one; `onNewToken` / `didRegisterForRemoteNotificationsWithDeviceToken` must POST the new token to the server stub | M | networking (Ktor) |
| Minimal server stub (token storage + send endpoint) | Skeleton ships a push demo; the stub must be minimal but functional enough to prove the end-to-end path | L | Ktor server / minimal backend |

### Differentiators (Competitive Advantage)

| Feature | Value Proposition | Complexity | Dependencies |
|---------|-------------------|------------|--------------|
| Notification categories with inline reply action (iOS) | `UNNotificationCategory` + `UNTextInputNotificationAction` enables "Reply" directly from notification without opening app; advanced but impressive showcase | L | APNs category registration |
| Android notification actions (reply, mark read) | `NotificationCompat.Action` with `RemoteInput`; allows users to act without opening app | L | FCM data message |
| Silent / background push for data refresh (content-available) | Enables background data sync; iOS throttles to ~2-3 per hour; Android via high-priority FCM data message | M | background execution policy |
| Rich media push (image in notification) | `NotificationCompat.BigPictureStyle` (Android) / `UNNotificationAttachment` (iOS); visually differentiated | M | image download at notification receipt |
| Topic subscriptions (broadcast to user cohorts) | FCM topic messaging enables "send to all beta users" or "send to users who opted into sports alerts" without per-device addressing | M | FCM topics API |

### Anti-Features

| Anti-Feature | Why Avoid | Alternative |
|--------------|-----------|-------------|
| Creating notification channels in background / after first notification | Android will not display the notification or show the permission prompt if channels are first created while the app is backgrounded | Create all channels in `Application.onCreate()`, guaranteed to run before any push arrives |
| Storing the FCM/APNs token only in local storage | Token refresh invalidates the local copy; if the server was never updated, future pushes fail silently | Always POST new tokens to the server in `onNewToken` / `didRegisterForRemoteNotificationsWithDeviceToken`; treat server as source of truth |
| Using `notification` FCM message type alone for foreground handling | When app is foregrounded, `notification`-type messages are not delivered to `onMessageReceived`; developer misses the event | Use `data`-only messages or dual payload; always implement `FirebaseMessagingService.onMessageReceived` |
| Requesting notification permission on first app launch (before value demonstrated) | iOS one-shot; declined users cannot be re-prompted natively; Android opt-in rate drops for cold prompts | Delay prompt until after key engagement milestone; show pre-permission value screen first |
| Building a real backend in the skeleton | Out of scope per PROJECT.md; a real auth, queuing, and delivery backend is a product, not a skeleton primitive | Keep the server stub to: POST /token, POST /send (calls FCM/APNs HTTP v1 API directly) — nothing more |

### Feature Dependencies — Push Notifications

```
FCM integration (Android)
    └──required-by──> token registration
    └──required-by──> foreground message handling
    └──required-by──> notification channels
    └──required-by──> deep link from tap

APNs integration (iOS)
    └──required-by──> token registration
    └──required-by──> foreground willPresent delegate
    └──required-by──> deep link from tap
    └──required-by──> notification categories

opt-in flow (pre-permission screen)
    └──required-by──> runtime POST_NOTIFICATIONS (Android 13+)
    └──required-by──> UNUserNotificationCenter permission (iOS)

server stub
    └──required-by──> token storage
    └──required-by──> send endpoint (calls FCM HTTP v1 / APNs HTTP/2)

token refresh propagation
    └──requires──> Ktor networking
    └──requires──> server stub /token endpoint

deep-link routing ──requires──> navigation component (drawer destination resolution)
foreground notification ──requires──> in-app notification component (snackbar/banner)
```

---

## Cross-Family Feature Dependencies

```
DesignTokens (shared/commonMain)
    └──consumed-by──> Form error colours
    └──consumed-by──> Amount input placeholder / active / error state colours
    └──consumed-by──> Drawer selected-item highlight colour
    └──consumed-by──> In-app notification variant colours (success/warning/error/info)

shared ViewModel (StateFlow)
    └──required-by──> Form field-state machine
    └──required-by──> Amount input Decimal value
    └──required-by──> Drawer active-route state
    └──required-by──> In-app notification queue state
    └──required-by──> Push token lifecycle

Navigation component (destination routing)
    └──required-by──> Drawer current-route highlighting
    └──required-by──> Deep link routing (push tap → specific screen)
    └──required-by──> Multi-step form step routing

SQLDelight persistence
    └──enhances──> Form autosave draft
    └──enhances──> In-app notification history log

In-app notification component
    └──required-by──> Push foreground display (push taps routed through in-app banner)
```

---

## MVP Definition

### Launch With (v1 — Skeleton Primitive Quality Bar)

These features, if absent, make the component feel broken or incomplete as a reusable primitive.

- [ ] **Forms**: field-state machine (Pristine→Dirty→Valid→Invalid), on-blur + submit-time validation, error display, keyboard avoidance, focus chain, accessible labels + TalkBack/VoiceOver announcements, `UiText` for localizable errors
- [ ] **Amount Input**: digits-right-to-fill UX, locale-correct thousands/decimal separator, currency symbol placement, `Decimal` type in shared ViewModel, `NumberPassword`/`.numberPad` keyboard, programmatic value/display split, max-digit guard, zero/empty placeholder
- [ ] **Navigation Drawer**: `ModalNavigationDrawer` (Compose) / custom sheet (SwiftUI), edge-swipe + hamburger trigger, scrim dismiss, current-route highlight, 2-level collapsible groups with `AnimatedVisibility`, TalkBack/VoiceOver accessibility, deep-link route highlight
- [ ] **In-App Notifications**: snackbar, toast, banner, inline alert, notification queue, auto-dismiss with accessibility timeout awareness, manual dismiss, action button, TalkBack/VoiceOver announcements, theme token variants
- [ ] **Push Notifications**: FCM + APNs token registration and refresh, foreground handler, background system display, notification channels (Android), permission opt-in flow (both platforms), deep-link routing, minimal server stub (token store + send endpoint)

### Add After Validation (v1.x)

- [ ] **Forms**: async debounced field validation, multi-step wizard + progress, autosave draft to SQLDelight
- [ ] **Amount Input**: RTL correctness, paste sanitization, currency switcher
- [ ] **Drawer**: badge counts, tablet persistent rail mode, scroll-to-selected on open
- [ ] **In-App Notifications**: global overlay anchor (above modals/sheets), priority lanes, swipe-to-dismiss
- [ ] **Push**: notification categories with inline reply (iOS), notification actions (Android), silent background refresh

### Future Consideration (v2+)

- [ ] **Forms**: input masks (IBAN, phone), rich field dependency graphs
- [ ] **Amount Input**: negative number entry toggle, haptic feedback on max-digit
- [ ] **Drawer**: 3+ depth recursive nav tree
- [ ] **In-App Notifications**: notification history log screen
- [ ] **Push**: topic subscriptions, rich media push (images)

---

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Form field-state machine | HIGH | MEDIUM | P1 |
| On-blur + submit-time validation | HIGH | LOW | P1 |
| Keyboard avoidance / focus chain | HIGH | MEDIUM | P1 |
| TalkBack / VoiceOver form announcements | HIGH | MEDIUM | P1 |
| Amount input digits-right-to-fill | HIGH | MEDIUM | P1 |
| Locale-correct separators | HIGH | MEDIUM | P1 |
| Decimal type in shared ViewModel | HIGH | LOW | P1 |
| Drawer edge-swipe + hamburger open | HIGH | MEDIUM | P1 |
| Drawer 2-level collapsible groups | HIGH | MEDIUM | P1 |
| Drawer current-route highlight | HIGH | LOW | P1 |
| In-app notification queue | HIGH | MEDIUM | P1 |
| In-app a11y announcements + no-auto-dismiss-while-focused | HIGH | MEDIUM | P1 |
| FCM + APNs token registration | HIGH | MEDIUM | P1 |
| Push foreground handler | HIGH | MEDIUM | P1 |
| Push deep-link routing | HIGH | MEDIUM | P1 |
| Notification channels + opt-in flow | HIGH | MEDIUM | P1 |
| Server stub (token + send) | HIGH | HIGH | P1 |
| Async debounced form validation | MEDIUM | MEDIUM | P2 |
| Multi-step form wizard | MEDIUM | HIGH | P2 |
| Form autosave draft | MEDIUM | HIGH | P2 |
| Amount input RTL correctness | MEDIUM | MEDIUM | P2 |
| Drawer badge counts | MEDIUM | LOW | P2 |
| Tablet persistent rail mode | MEDIUM | MEDIUM | P2 |
| Push global overlay anchor | MEDIUM | HIGH | P2 |
| Push notification categories / actions | LOW | HIGH | P3 |
| In-app notification history log | LOW | HIGH | P3 |
| Amount input negative number toggle | LOW | MEDIUM | P3 |
| Drawer 3+ depth recursive tree | LOW | HIGH | P3 |

---

## Sources

- Android Developers — Navigation Drawer: https://developer.android.com/jetpack/compose/components/drawer
- Android Developers — Snackbar: https://developer.android.com/develop/ui/compose/components/snackbar
- Firebase Cloud Messaging Android setup: https://firebase.google.com/docs/cloud-messaging/android/client
- Firebase Cloud Messaging iOS receive: https://firebase.google.com/docs/cloud-messaging/ios/receive
- ProAndroidDev — Currency TextFields in Compose: https://proandroiddev.com/editing-currency-textfields-in-jetpack-compose-b7074b4682ea
- Medium — Currency Amount Input Compose: https://medium.com/@banmarkovic/how-to-create-currency-amount-input-in-android-jetpack-compose-1bd11ba3b629
- AzamSharp — Ultimate Guide to SwiftUI Validation (Dec 2024): https://azamsharp.com/2024/12/18/the-ultimate-guide-to-validation-patterns-in-swiftui.html
- Fatbobman — SwiftUI TextField Events, Focus, Keyboard: https://fatbobman.com/en/posts/textfield-event-focus-keyboard/
- Swift with Majid — Deep linking for local notifications in SwiftUI (Apr 2024): https://swiftwithmajid.com/2024/04/09/deep-linking-for-local-notifications-in-swiftui/
- nilcoalescing.com — iOS Remote Push Setup: https://nilcoalescing.com/blog/RemotePushSetup/
- Bugfender — iOS Push Notifications complete guide: https://bugfender.com/blog/ios-push-notifications/
- oneuptime.com — iOS Push Notifications APNs Setup (Feb 2026): https://oneuptime.com/blog/post/2026-02-02-ios-push-notifications/view
- CVS Health — Android Compose Accessibility Techniques (Popup Messages): https://github.com/cvs-health/android-compose-accessibility-techniques/blob/main/doc/components/PopupMessages.md
- Apple WWDC 2024 — Catch up on accessibility in SwiftUI: https://developer.apple.com/videos/play/wwdc2024/10073/
- LogRocket — Custom collapsible sidebar in SwiftUI: https://blog.logrocket.com/create-custom-collapsible-sidebar-swiftui/
- ProAndroidDev — Full Guide Form Validation with Jetpack Compose: https://proandroiddev.com/full-guide-how-to-form-validation-with-jetpack-compose-01e0464ae884
- OneSignal — Mobile App Benchmarks 2024 (push opt-in rates): https://onesignal.com/mobile-app-benchmarks-2024
- Medium — Push Notifications Android Complete Guide (Apr 2026): https://medium.com/@ramadan123sayed/push-notifications-in-android-the-complete-a-z-guide-firebase-cloud-messaging-fcm-fa728572cd8a

---
*Feature research for: KMP skeleton — Forms, Amount Input, Tree-Sidebar Nav, In-App + Push Notifications*
*Researched: 2026-05-08*
