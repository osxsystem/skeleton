# Roadmap: Skeleton

## Overview

Seven phases, hard-sequenced by dependency. Phases 1 and 2 are build gates — nothing in Phase 3+ compiles correctly until both are green. Phase 3 builds the three pure-state component families (forms, amount input, in-app notifications). Phase 4 adds push notifications, which consume the in-app notification infrastructure from Phase 3. Phase 5 builds the navigation drawer, which depends on the deep-link contract established in Phase 4. Phase 6 wires the showcase app and exercises every component end-to-end. Phase 7 publishes the artifacts to Maven Central and SPM.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: KMP Scaffold + Tooling** - Multi-module Gradle project + Xcode project compile green on both platforms with the locked toolchain; CI, DI, Ktor stub, SQLDelight stub, SKIE, test harness all in place
- [ ] **Phase 2: Design Token Bridge** - DesignTokens in commonMain, Compose AppTheme adapter, SwiftUI AppTheme adapter; light and dark mode follow the system on both platforms
- [ ] **Phase 3: Forms + Amount Input + In-App Notifications** - Three pure-state component families with shared ViewModels, platform UIs, accessibility, and cross-locale correctness
- [ ] **Phase 4: Push Notifications** - FCM + APNs token registration, foreground and background delivery, deep-link tap routing, and a runnable Ktor server stub
- [ ] **Phase 5: Navigation Drawer** - Two-level collapsible tree drawer on both platforms, deep-link auto-expansion, hamburger trigger, accessibility
- [ ] **Phase 6: Showcase App** - Single showcase on Android and iOS that exercises every component, with a real Ktor network call and SQLDelight persistence demo
- [ ] **Phase 7: Published Artifacts** - shared-core and shared-components to Maven Central; SkeletonKit to SPM via KMMBridge; CI publish jobs on tag push

## Phase Details

### Phase 1: KMP Scaffold + Tooling
**Goal**: The multi-module Gradle project and Xcode project compile green on both platforms with the fully locked toolchain; every infrastructure concern (CI, DI, networking stub, persistence stub, SKIE, test harness, iOS lifecycle) is correct before any feature code is written.
**Depends on**: Nothing (first phase)
**Requirements**: SCAF-01, SCAF-02, SCAF-03, SCAF-04, SCAF-05, SCAF-06, SCAF-07, SCAF-08, SCAF-09, SCAF-10, SCAF-11
**Success Criteria** (what must be TRUE):
  1. `./gradlew :shared-core:build :shared-components:build :shared-app:build :androidApp:assembleDebug` exits 0 on a clean machine with no warnings
  2. Xcode builds `SkeletonKit.framework` (not `shared.framework`) and the iOS showcase app links and runs on the simulator; `IosViewModelStoreOwner.deinit` log fires when a screen is popped
  3. CI passes both jobs (Android on ubuntu-latest, iOS on macos-14 with timeout-minutes 30) on a hello-world commit; the iOS job runs `iosSimulatorArm64Test` as a separate step
  4. A sample ViewModel is resolvable from both Android and iOS Koin entry points; one `commonTest` passes on both platforms using `kotlin.test.Test` (not org.junit.Test)
  5. The generated `SkeletonKit.framework/Headers/` contains no `Any?` in Flow or sealed-class signatures; SQLDelight hello-world query runs on both platforms without a crash
**Plans**: 10 plans
Plans:
- [x] 01-01-PLAN.md — Version catalog + root Gradle config (SCAF-04)
- [x] 01-02-PLAN.md — :shared-core module: AGP-9 KMP plugin, SQLDelight, Ktor, vanniktech (SCAF-01, SCAF-03, SCAF-07, SCAF-08)
- [x] 01-03-PLAN.md — :shared-components umbrella framework, SKIE, KMMBridge (SCAF-02, SCAF-03, SCAF-07)
- [x] 01-04-PLAN.md — :shared-app module + GreetingViewModel + commonTest (SCAF-01, SCAF-06, SCAF-10)
- [x] 01-05-PLAN.md — SKIE generics validation pattern + SkieGenericsTest (SCAF-02, SCAF-11)
- [x] 01-06-PLAN.md — :androidApp Koin boot + GreetingScreen (SCAF-01, SCAF-06)
- [x] 01-07-PLAN.md — :server Ktor module shell with /health route (SCAF-07)
- [ ] 01-08-PLAN.md — iOS Xcode project + IosViewModelStoreOwner + GreetingScreen (SCAF-02, SCAF-05, SCAF-06)
- [ ] 01-09-PLAN.md — GitHub Actions CI: Android + iOS jobs with all validation gates (SCAF-09, SCAF-10, SCAF-11)
- [ ] 01-10-PLAN.md — architecture.md + docs/ARCHITECTURE.md multi-module reconciliation (SCAF-01, SCAF-02, SCAF-03)

**Pitfall refs**: Pitfall 1 (viewModelScope iOS lifecycle leak), Pitfall 2 (@StateObject vs @ObservedObject), Pitfall 3 (SKIE + Kotlin lock-step), Pitfall 4 (SKIE generic type erasure), Pitfall 5 (@Throws on suspend fns), Pitfall 18 (kotlin.test.Test annotation), Pitfall 19 (SQLDelight -lsqlite3 flag), Pitfall 20 (AGP 9 plugin incompatibility), Pitfall 21 (baseName "shared" conflict), Pitfall 23 (iOS simulator CI flakiness)

**Open decisions to resolve at kickoff**: None — all choices are locked and verified per SUMMARY.md research flags.

### Phase 2: Design Token Bridge
**Goal**: DesignTokens in commonMain defines all visual primitives using only Long/Float/Int; Compose and SwiftUI adapters map those primitives to MaterialTheme and SwiftUI environment values; dark mode selection is owned by the Swift side and updates both apps without restart.
**Depends on**: Phase 1
**Requirements**: THEME-01, THEME-02, THEME-03, THEME-04, THEME-05
**Success Criteria** (what must be TRUE):
  1. `DesignTokens.kt` in `:shared-core/commonMain` compiles for both Android and iOS targets with no Compose or SwiftUI import; a `commonTest` asserts every color constant is positive (no Long-to-Int overflow)
  2. The Android showcase app renders with MaterialTheme colors, typography, and shapes sourced entirely from DesignTokens — no hex literals in androidApp theme code
  3. The iOS showcase app renders with SwiftUI Color and Font values sourced entirely from DesignTokens — no hex literals in iosApp theme code
  4. Switching macOS/iOS system appearance from Light to Dark updates both apps without restart; the correct palette (LightColors vs DarkColors) is selected by the SwiftUI @Environment(\.colorScheme), not a Kotlin ViewModel flag
**Plans**: TBD
**UI hint**: yes

**Pitfall refs**: Pitfall 6 (ARGB Long overflow), Pitfall 7 (dark mode token selection on wrong side of bridge)

**Open decisions to resolve at kickoff**: None — simple, well-documented pattern per SUMMARY.md research flags.

### Phase 3: Forms + Amount Input + In-App Notifications
**Goal**: The three pure-state component families — form field state machine, locale-aware currency amount input, and in-app notification queue — are complete in commonMain and render correctly on both platforms with full accessibility and cross-locale correctness.
**Depends on**: Phase 2
**Requirements**: FORM-01, FORM-02, FORM-03, FORM-04, FORM-05, FORM-06, FORM-07, FORM-08, FORM-09, FORM-10, FORM-11, AMT-01, AMT-02, AMT-03, AMT-04, AMT-05, AMT-06, AMT-07, AMT-08, AMT-09, AMT-10, INAPP-01, INAPP-02, INAPP-03, INAPP-04, INAPP-05, INAPP-06, INAPP-07, INAPP-08, INAPP-09, INAPP-10
**Success Criteria** (what must be TRUE):
  1. A form with multiple fields cycles through Pristine → Dirty → Valid → Invalid state on both platforms; errors appear below the relevant field on blur and on submit; the submit CTA shows a loading state and cannot be double-tapped; validation messages use UiText resource keys, not raw strings
  2. The amount input field accepts digits right-to-fill in en-US, de-DE, and fr-FR locales; the thousands and decimal separators are detected at runtime; no malformed value (e.g. 1.2.3) can appear; an overflow-paste is silently capped; raw cents never appear in UiState
  3. Snackbar, toast, banner, and inline alert each appear in the showcase; auto-dismiss honors the configurable timeout and pauses when TalkBack or VoiceOver focus is on the notification; manual dismiss button is present on every floating notification; all four theme variants (success / warning / error / info) derive colors only from DesignTokens
  4. Form fields announce validation errors to TalkBack and VoiceOver; amount input and form navigation satisfy the keyboard-avoidance and focus-chain requirements on both platforms; collapsed tree branches (if exercised from a drawer) are removed from the accessibility tree, not just hidden
  5. All FORM, AMT, and INAPP commonTest suites pass on both JVM and iosSimulatorArm64 CI targets; cross-locale AMT tests pass for en-US, de-DE, and fr-FR
**Plans**: TBD
**UI hint**: yes

**Pitfall refs**: Pitfall 8 (Compose IME composing text race — use rememberTextFieldState()), Pitfall 9 (iOS keyboard avoidance and ScrollView), Pitfall 10 (currency decimal separator locale mismatch), Pitfall 11 (paste sanitization in currency input), Pitfall 17 (in-app notification covered by modal sheet on iOS)

**Open decisions to resolve at kickoff**:
  - Currency formatter approach: custom expect/actual (java.text.NumberFormat / NSNumberFormatter) vs Kurrency library. Current lean: custom expect/actual.
  - Amount input precision type: Long cents vs BigDecimal via ionspin/kotlin-multiplatform-bignum. Current lean: BigDecimal.
  - In-app notification queue type: StateFlow vs MutableSharedFlow(replay=0, extraBufferCapacity=64). Current lean: MutableSharedFlow — avoids replay-on-rotation, required by INAPP-01.

### Phase 4: Push Notifications
**Goal**: FCM and APNs token registration with refresh handling, foreground and background delivery, runtime permission opt-in flows, deep-link routing from notification tap (including cold-start), and a locally runnable Ktor server stub — all verified end-to-end.
**Depends on**: Phase 3 (in-app notification infrastructure consumed by foreground push display)
**Requirements**: PUSH-01, PUSH-02, PUSH-03, PUSH-04, PUSH-05, PUSH-06, PUSH-07, PUSH-08, PUSH-09, PUSH-10, PUSH-11, PUSH-12
**Success Criteria** (what must be TRUE):
  1. Reinstalling the app on a test device and sending a push from the server stub within 30 seconds delivers the notification on Android (emulator + device) and iOS (physical device only); new token from onNewToken / didRegisterForRemoteNotificationsWithDeviceToken is uploaded to the stub on every refresh
  2. A push received while the app is foregrounded renders via the in-app notification component (Phase 3 infrastructure) and appears above any open modal sheet; a push received while backgrounded or killed renders as a system notification
  3. The pre-permission opt-in screen appears before the OS prompt on both platforms; Android `POST_NOTIFICATIONS` permission is requested on API 33+ and the runtime result is handled; iOS `UNUserNotificationCenter` authorization is requested and handled
  4. Tapping a push notification deep-links to the correct route; tapping on cold-start (app fully killed) navigates to the correct screen with content rendered — verified by a cold-start smoke test
  5. `./gradlew :server:run` starts the stub locally; `POST /token` stores a device token; `POST /send` calls FCM HTTP v1 (OAuth 2.0 Bearer) and APNs HTTP/2; a Dockerfile is present; a GitHub Actions deploy recipe targeting Fly.io or Render is documented
**Plans**: TBD

**Pitfall refs**: Pitfall 12 (push token refresh race — FCM + APNs ordering), Pitfall 13 (deep link before ViewModel init / cold-start), Pitfall 14 (iOS foreground push not delivered to UI — UNUserNotificationCenterDelegate willPresent)

**Open decisions to resolve at kickoff**:
  - KMPNotifier vs hand-rolled expect/actual vs separate :shared-notifications module. Current lean: separate :shared-notifications module — keeps push optional for skeleton consumers.
  - Server stub deployment shape: local only vs deployed to a public URL for end-to-end physical device testing. Needs user input before Phase 4 starts.

### Phase 5: Navigation Drawer
**Goal**: The NavDrawerViewModel owns the route tree, current route, and expanded-group state in commonMain; both platforms render a collapsible two-level tree drawer with hamburger trigger, scrim dismiss, accessibility announcements, and correct deep-link path auto-expansion.
**Depends on**: Phase 4 (deep-link routing contract established)
**Requirements**: NAV-01, NAV-02, NAV-03, NAV-04, NAV-05, NAV-06, NAV-07, NAV-08, NAV-09, NAV-10
**Success Criteria** (what must be TRUE):
  1. The hamburger button in the top app bar opens the drawer on both platforms; edge-swipe opens the drawer on Android; on iOS the system back-swipe gesture is fully preserved (edge gesture does not interfere with the drawer)
  2. Two-level groups expand and collapse; on Compose, AnimatedVisibility removes collapsed children from the accessibility tree; on SwiftUI, collapsed children are absent from the view hierarchy (not just alpha-hidden)
  3. Tapping the scrim dismisses the drawer; the currently selected route is visually highlighted; drawer items expose accessible labels and selection state to TalkBack and VoiceOver
  4. A deep link to a nested route opens the drawer with the correct branch pre-expanded and the target item highlighted — verified for a fully-collapsed initial state
  5. NavDrawerViewModel fires NavIntent.RouteSelected(route) events; platform UI (NavController on Android, NavigationPath on iOS) executes navigation — no NavController reference exists in commonMain
**Plans**: TBD
**UI hint**: yes

**Pitfall refs**: Pitfall 15 (navigation drawer edge gesture vs iOS back swipe conflict), Pitfall 16 (deep linking into a collapsed tree node — expandPathTo pure function)

**Open decisions to resolve at kickoff**:
  - NavDrawer route tree shape: recursive NavNode(children: List<NavNode>) vs flat NavItem(parentId: String?). Current lean: recursive — ergonomic for rendering.

### Phase 6: Showcase App
**Goal**: A single showcase app on Android and iOS demonstrates every component family end-to-end, with a real Ktor network call against a public API and a SQLDelight-backed persistence demo.
**Depends on**: Phase 5 (all four component families complete)
**Requirements**: SHOW-01, SHOW-02, SHOW-03, SHOW-04, NET-01, NET-02, NET-03, DB-01, DB-02
**Success Criteria** (what must be TRUE):
  1. The Android showcase builds and runs on both emulator and physical device; the iOS showcase builds and runs on both simulator and physical device; the home screen lists each component family with a link to its demo screen
  2. A real Ktor call against a public API (final API selected at Phase 6 kickoff) renders results via StateFlow<UiState> with explicit loading / success / error states; network errors surface via the in-app notification component
  3. At least one showcase screen reads from and writes to SQLDelight on both Android and iOS; the persisted entity survives an app restart
  4. A runtime light/dark toggle in the showcase reflects through DesignTokens end-to-end on both platforms
**Plans**: TBD
**UI hint**: yes

**Pitfall refs**: Pitfall 22 (Maven Central duplicate publication — do publishToMavenLocal dry run before targeting Central, relevant as showcase verification precedes publish)

**Open decisions to resolve at kickoff**:
  - Public API selection: likely open.er-api.com (keyless currency rates) so the response doubles as data for the amount-input component.

### Phase 7: Published Artifacts
**Goal**: :shared-core and :shared-components are published to Maven Central under a domain-verified group ID; SkeletonKit publishes to SPM via KMMBridge; a fresh project can consume any component family from either package manager without copying source.
**Depends on**: Phase 6 (showcase verification complete; modules stable)
**Requirements**: PUB-01, PUB-02, PUB-03, PUB-04, PUB-05, PUB-06
**Success Criteria** (what must be TRUE):
  1. :shared-core and :shared-components are available on Maven Central under the finalized domain-verified group ID; a clean `testConsumer` Gradle project that depends only on the published coordinates resolves and compiles without errors
  2. SkeletonKit is available as a Swift Package; a clean Xcode project that adds the SPM dependency can import and use any of the four component families without copying source
  3. :shared-app (showcase) is never published; a `publishToMavenLocal` dry run of :shared-app emits nothing to the local repo — verified by checking that the showcase coordinate is absent
  4. GitHub Actions publish workflows run on tag push: Maven Central job on ubuntu-latest, SPM/KMMBridge job on macos-14; both pass for a test tag before targeting the real release
**Plans**: TBD

**Pitfall refs**: Pitfall 22 (Maven Central duplicate publication — use publishToMavenLocal dry run before targeting Central; single Gradle invocation; never re-publish at the same version)

**Open decisions to resolve at kickoff**:
  - Final group ID / domain name: dev.skeleton is a placeholder; must be a domain-verified group ID before any publish attempt. Requires domain ownership decision.
  - Maven Central account verification: Central Portal account and GPG key must be set up before Phase 7 starts.
  - KMMBridge maintenance status: monitor touchlab/KMMBridge; if unmaintained, fall back to ge-org/multiplatform-swiftpackage.

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5 → 6 → 7

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. KMP Scaffold + Tooling | 0/10 | In Progress | - |
| 2. Design Token Bridge | 0/TBD | Not started | - |
| 3. Forms + Amount Input + In-App Notifications | 0/TBD | Not started | - |
| 4. Push Notifications | 0/TBD | Not started | - |
| 5. Navigation Drawer | 0/TBD | Not started | - |
| 6. Showcase App | 0/TBD | Not started | - |
| 7. Published Artifacts | 0/TBD | Not started | - |
