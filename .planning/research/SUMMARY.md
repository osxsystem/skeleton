# Project Research Summary

**Project:** Skeleton — KMP mobile skeleton + reusable native UI component library
**Domain:** Kotlin Multiplatform / native UI (Compose + SwiftUI) / published artifact
**Researched:** 2026-05-08
**Confidence:** HIGH (stack, pitfalls, architecture) / MEDIUM (a few open implementation choices)

---

## Executive Summary

This is a Kotlin Multiplatform skeleton and component library targeting Android (Jetpack Compose) and iOS (SwiftUI), with shared business logic in `commonMain` using MVVM + `StateFlow` + UDF. The four component families — forms, currency-aware amount input, tree-sidebar navigation drawer, and notifications (in-app + push) — are the deliverable. They ship as published artifacts to Maven Central and Swift Package Manager. The canonical pattern (shared `ViewModel` in `commonMain`, stateless platform UI, `expect`/`actual` for platform services, SKIE for the Kotlin↔Swift bridge) is endorsed jointly by JetBrains and Google, and all major version choices have been verified against official release notes as of 2026-05-08.

The build order is hard-sequenced by dependency: scaffold first (design tokens, DI, Ktor, SQLDelight scaffold, CI, test harness), then the token bridge, then forms + amount input + in-app notifications (no server dependencies), then push notifications (platform SDK setup can start in parallel with Phase 3), then the navigation drawer (consumes the push deep-link contract), then showcase wiring, and finally publish. Parallelisable seams exist within each component phase between the shared ViewModel layer and the platform UI layer — but the KMP scaffold must be completely correct before any component ViewModel can compile.

The highest-cost risks are: iOS `viewModelScope` lifecycle leak via wrong property wrapper (`@ObservedObject` instead of `@StateObject`) — silent in testing, catastrophic in production; `baseName = "shared"` left as the default XCFramework name — breaks every downstream product that adds a second KMP library; AGP 9 plugin migration (`com.android.kotlin.multiplatform.library` replaces `com.android.library`) must happen on day one or it blocks all Android builds; and SKIE + Kotlin version lock-step ignored — can block an iOS release for days after a routine Kotlin bump. All four must be addressed in Phase 1 before any feature code is written.

---

## Key Findings

### Recommended Stack

The stack is fully locked. A validated `libs.versions.toml` combination (Kotlin 2.3.21 / KSP 2.3.21-2.0.4 / AGP 9.2.0 / Gradle 9.5.0 / SKIE 0.10.11) is the only supported combination — do not bump any of these four independently. Key supporting libraries: `androidx.lifecycle 2.10.0` (KMP ViewModel, raises `minSdk` to 23), Compose BOM `2026.05.00`, Ktor `3.4.0`, SQLDelight `2.3.2` (`app.cash.sqldelight`, not `com.squareup`), Koin `4.2.1`, Navigation 3 `1.1.1`, Firebase BoM `34.13.0` (no `-ktx` modules — removed at v34). KMMBridge `1.1.0` is the SPM publish tool but its maintenance pace has slowed; monitor touchlab/KMMBridge and have `ge-org/multiplatform-swiftpackage` as fallback.

**Core technologies:**
- **Kotlin 2.3.21 + KSP2 `2.3.21-2.0.4`**: language + annotation processing — KSP2 is the default; KSP1 is broken on AGP 9
- **AGP 9.2.0 + Gradle 9.5.0 + JDK 21**: build toolchain — AGP 9 requires `com.android.kotlin.multiplatform.library`, not `com.android.library`
- **SKIE 0.10.11**: Kotlin↔Swift bridge — `StateFlow` → `AsyncSequence`, `sealed class` → Swift exhaustive enum; must be updated in lock-step with Kotlin
- **`androidx.lifecycle 2.10.0`**: shared ViewModel — declared `api` + `export` in iOS framework block; `minSdk` raised to 23
- **Ktor 3.4.0**: networking (client + server stub) — all modules same version; OkHttp on Android, Darwin on iOS
- **SQLDelight 2.3.2**: persistence — `NativeSqliteDriver` requires `-lsqlite3` linker flag on iOS (or use `BundledSQLiteDriver`)
- **Koin 4.2.1**: DI — only KMP-compatible option; Hilt explicitly excluded by Google's KMP guide
- **Compose BOM 2026.05.00**: Android UI — maps Material3 1.4.0; use BOM, do not pin individually
- **Navigation 3 `1.1.1`**: Android type-safe navigation; replaces Navigation 2 Compose
- **KMMBridge `1.1.0` + vanniktech `0.36.0`**: XCFramework → SPM repo + Maven Central automated release
- **Turbine `1.2.1` + `kotlinx-coroutines-test 1.10.2`**: mandatory for `StateFlow`/ViewModel unit tests

**Hard excludes:** Hilt, KAPT, KSP1, Compose Multiplatform iOS UI, CocoaPods, `firebase-*-ktx` modules, `com.squareup.sqldelight`, `org.junit.Test` in `commonTest`, `kotlinx.datetime.Instant` (removed — use `kotlin.time.Instant`), `Molecule`, `Decompose`, third-party toast libraries for SwiftUI, `Double` for financial arithmetic.

### Expected Features

**Must have — v1:**

*Forms:* field-state machine (Pristine→Dirty→Valid→Invalid), on-blur + submit-time validation, error display below field, keyboard avoidance, focus chain (Next/Done), programmatic initial focus, SecureField/password toggle, platform-native keyboard types, accessible labels + TalkBack/VoiceOver announcements, `UiText` abstraction for localisable errors, CTA disable/loading during async submit.

*Amount input:* digits-right-to-fill UX, locale-correct thousands/decimal separator, currency symbol placement (prefix/suffix), `Decimal` type (not `Double`) in shared ViewModel, `NumberPassword`/`.numberPad` keyboard, programmatic value/display split, max-digit guard, zero/empty placeholder.

*Navigation drawer:* `ModalNavigationDrawer` (Compose) / custom sheet (SwiftUI), edge-swipe + hamburger trigger, scrim dismiss, current-route highlight, 2-level collapsible groups with `AnimatedVisibility`, TalkBack/VoiceOver accessibility, deep-link route highlight.

*In-app notifications:* snackbar, toast, banner, inline alert, notification queue (one at a time), auto-dismiss with a11y timeout awareness, manual dismiss, action button(s), TalkBack/VoiceOver announcements, theme-token colour variants (success/warning/error/info).

*Push notifications:* FCM + APNs token registration + `onNewToken` refresh, foreground handler, background/killed-state system display, Android notification channels (in `Application.onCreate()`), runtime `POST_NOTIFICATIONS` permission (Android 13+), `UNUserNotificationCenter` permission (iOS), pre-permission opt-in screen, deep-link routing from tap, minimal Ktor server stub (`POST /token`, `POST /send`).

**Should have — v1.x:**
Async debounced form field validation, multi-step wizard + progress indicator, form autosave draft (SQLDelight), RTL amount input, paste sanitisation on both inputs, drawer badge counts, tablet persistent rail mode, global overlay anchor for notifications (above modals/sheets), notification priority lanes.

**Defer — v2+:**
Input masks (IBAN/phone), 3+-depth recursive nav tree, notification history log, iOS notification categories with inline reply, push topic subscriptions, rich media push, negative number entry toggle, currency switcher.

**Anti-features (deliberately not building):**
- Real-time as-you-type validation (validate on blur instead)
- Custom keyboard replacement (breaks password managers, autofill, accessibility)
- Raw password state in `StateFlow`
- `Double` for financial arithmetic
- Multiple simultaneous floating notifications
- `Toast.makeText` with application context (deprecated Android 12+)
- `SharedFlow(replay > 0)` for notification events (re-emits on rotation)
- Persistent rail on phones (Material 3 reserves for ≥600dp)
- Real backend (stub only: `POST /token`, `POST /send`)
- Auth/login in the showcase

### Architecture Approach

Three KMP Gradle modules publish; one showcase module never does. `:shared-core` holds design tokens (Long/Float/Int primitives only — no Compose types), DI scaffold, Ktor client, SQLDelight schema, and base repos. `:shared-components` holds the four component ViewModel families + `expect`/`actual` platform services (`NotificationService`, `CurrencyFormatter`); depends on `:shared-core` via `api` (types flow through). `:shared-app` is showcase-only wiring and is never published. iOS sees a single umbrella framework (`baseName = "SkeletonKit"`) compiled from `:shared-components` which re-exports `:shared-core` via `api + export` — the JetBrains-documented pattern that prevents type-duplication crashes when the same class appears in two frameworks. Platform components (Compose/SwiftUI) are stateless: receive `UiState` down, fire `Intent` up, never hold a ViewModel reference.

**Major components:**
1. `:shared-core` — `DesignTokens`, `CoreKoinModule`, `KtorClient`, SQLDelight schema + drivers, base repos + use cases
2. `:shared-components` — `FormViewModel`, `AmountInputViewModel`, `NavDrawerViewModel`, `NotificationViewModel`; `NotificationService` (expect/actual); `CurrencyFormatter` (expect/actual)
3. `androidApp/` — `AppTheme` (tokens → MaterialTheme), stateless `@Composable` components, showcase screens
4. `iosApp/` — `AppTheme.swift` (tokens → SwiftUI environment), stateless SwiftUI Views, `IosViewModelStoreOwner`, showcase screens
5. `:shared-app` — showcase-only `AppKoinModule`, screen VMs; never published

**Key anti-patterns to enforce:**
- No ViewModel reference inside a reusable Composable/SwiftUI View
- No `NavController` reference in `commonMain` (fires `NavIntent` instead; platform executes)
- No Compose types (`Color`, `TextStyle`) in `commonMain` design tokens
- No multiple iOS frameworks (umbrella pattern only)
- No `baseName = "shared"` — rename to product name from day one

### Critical Pitfalls

**Must address in Phase 1 (project-stopper if deferred):**

1. **iOS `viewModelScope` lifecycle leak** — `IosViewModelStoreOwner` must be `@StateObject`, never `@ObservedObject`. Its `deinit` must call `viewModelStore.clear()`. Add a `deinit` log from day one; verify it fires on navigation pop. Cost: silent coroutine/memory leak in production.

2. **`baseName = "shared"` XCFramework default** — Rename to `baseName = "SkeletonKit"` before the first iOS framework compile. Update `XCFramework("SkeletonKit")` and `import SkeletonKit` in iosApp. Cost: breaks every downstream product that embeds a second KMP library.

3. **AGP 9 plugin incompatibility** — Apply `com.android.kotlin.multiplatform.library` (not `com.android.library`) to all KMP modules from day one. Cost: all Android builds break; migration is non-trivial mid-project.

4. **SKIE + Kotlin version lock-step ignored** — Pin Kotlin, SKIE, KSP, AGP as a single unit in `libs.versions.toml` with comment: `# Update these four together`. Add iOS framework link step to every CI PR. Cost: iOS release blocked for days.

5. **SKIE generics type erasure** — Never expose `Result<T>` or `Flow<SomeEnum?>` across the KMP/Swift boundary. Use project-specific sealed `UiState` wrappers. Inspect the generated `shared.framework/Headers/` for `Any?` after the first build. Cost: runtime cast failures in Swift with no compile-time warning.

**High-cost pitfalls in feature phases:**

6. **Currency decimal separator locale mismatch (Phase 3)** — Detect separator at runtime; use `BigDecimal`/`kotlinx-bignum` not `Double`; test on `de-DE` and `fr-FR` locales.

7. **Push token refresh race — FCM + APNs (Phase 4)** — Implement `onNewToken`; on iOS set `apnsToken` before reading FCM token; use FCM HTTP v1 API (OAuth 2.0 Bearer — legacy API deprecated).

8. **Deep link tapped before ViewModel init / cold-start (Phase 4–5)** — Route the deep link after `startKoin` completes and root view `.task` has fired. Write a cold-start smoke test.

9. **In-app notification covered by modal sheet on iOS (Phase 3–4)** — Use a secondary `UIWindow` overlay or inject the notification manager at every modal boundary. `ContentView`-anchored overlays are invisible behind `.sheet`.

10. **Compose IME composing text race on form fields (Phase 3)** — Use `rememberTextFieldState()` (Compose 1.7 `TextFieldState` API), not `MutableState<String> + onValueChange`. Validate on blur, not on every keystroke.

---

## Implications for Roadmap

The phase structure below is **hard-sequenced by dependency**. Phases 1 and 2 are gate phases — nothing in Phase 3+ compiles correctly until both are green. Phases 3 and 4 can be partially parallelised (push platform SDK setup is independent of UI work). Phase 5 depends on the deep-link contract established in Phase 4.

### Phase 1: KMP Scaffold + Tooling Foundation

**Rationale:** Twelve of twenty-three researched pitfalls must be addressed here. A scaffold defect discovered in Phase 3 requires backtracking across all modules. This phase has no user-visible output but is the longest gate.

**Delivers:** Compilable multi-module Gradle project (`:shared-core`, `:shared-components`, `:shared-app`, `:androidApp`) + Xcode project with correct AGP 9 plugin, `baseName = "SkeletonKit"`, Koin DI wiring, Ktor client stub, SQLDelight schema stub + `-lsqlite3` linker flag, SKIE configured, `IosViewModelStoreOwner` + `@StateObject` lifecycle wired, CI jobs for both platforms (pinned `macos-14`, `timeout-minutes: 30` on iOS job), `kotlin.test` harness with iOS simulator job distinct from JVM job, `@Throws` convention on all public suspend functions.

**Pitfalls addressed:** iOS lifecycle leak, `baseName` rename, AGP 9 plugin, SKIE lock-step, SKIE generics validation, `@Throws` convention, `kotlin.test.Test` annotation, SQLDelight linker flag, iOS simulator CI flakiness.

**Research flag:** All choices are locked and verified. No additional research needed.

---

### Phase 2: Design Token Bridge (Light + Dark)

**Rationale:** All four component families consume `DesignTokens` for colour, typography, and spacing. The bridge must be tested before any component renders. Building components before the bridge produces hardcoded values that are expensive to refactor.

**Delivers:** `DesignTokens.kt` in `:shared-core/commonMain` with `LightColors`/`DarkColors` as `Long` constants; `AppTheme.kt` (Compose, tokens → `MaterialTheme`); `AppTheme.swift` (SwiftUI, tokens → environment values). Dark mode selection owned by Swift `@Environment(\.colorScheme)`, not the Kotlin ViewModel.

**Pitfalls addressed:** ARGB `Long` overflow (every constant declared `Long` + `L` suffix; `commonTest` asserts no negative value; Swift adapter uses `Int64`); dark mode token selection race (Kotlin exports both palettes, Swift selects).

**Research flag:** Simple, well-documented pattern. No additional research needed.

---

### Phase 3: Forms + Amount Input + In-App Notifications

**Rationale:** These three families share no server or platform-SDK dependency — pure state machines on top of the token bridge. In-app notifications are included here because the queue is consumed by forms (submit feedback) and must exist before push foreground handling in Phase 4. Firebase/APNs credential setup (Phase 4 external dependency) can start in parallel with this phase.

**Parallelisable seam:** Shared ViewModels + unit tests can be written and green before any platform UI code is touched. Compose and SwiftUI renderers can be built in parallel once ViewModel contracts are stable.

**Delivers:** `FormViewModel` + `CurrencyFormatter` (expect/actual) + `NotificationViewModel` in `commonMain`; `FormField`, `AmountInputField`, `NotificationHost` on both platforms.

**Must address:**
- `rememberTextFieldState()` (Compose 1.7) for all form inputs — prevents IME composing text race
- iOS forms: `ScrollView { }.scrollDismissesKeyboard(.interactively)` + `@FocusState`
- Runtime decimal separator detection; `BigDecimal`/`kotlinx-bignum`; test on `de-DE` + `fr-FR`
- Post-paste sanitizer on amount input with unit tests
- Notification queue: `MutableSharedFlow(replay=0, extraBufferCapacity=64)` — not `StateFlow`, not `replay > 0`
- iOS in-app notification: `UIWindow` overlay or per-modal injection

**Open decision to resolve before starting:** In-app notification queue type (StateFlow vs SharedFlow with buffer) and currency precision type (Long cents vs BigDecimal). See Open Decisions section.

**Research flag:** Well-researched. Resolve two open decisions at phase kickoff, then execution is standard.

---

### Phase 4: Push Notifications (FCM + APNs + Server Stub)

**Rationale:** Push requires external setup (Firebase project, APNs `.p8` key) independent of UI work — credential setup can run in parallel with Phase 3. Phase 4 depends on: Ktor client (Phase 1), in-app notification component (Phase 3, for foreground display), Koin DI (Phase 1).

**Delivers:** `NotificationService.android.kt` (FCM actual), `NotificationService.ios.kt` (APNs actual), `FirebaseMessagingService` subclass, `AppDelegate` push delegates, Android channels in `Application.onCreate()`, pre-permission opt-in screen, deep-link routing from tap, Ktor server stub (`POST /token`, `POST /send` calling FCM HTTP v1 + APNs HTTP/2).

**Must address:**
- Always implement `onNewToken`; on iOS set `apnsToken` before reading FCM token
- FCM HTTP v1 API with OAuth 2.0 Bearer — legacy API deprecated
- `UNUserNotificationCenterDelegate.willPresent` returning `.banner + .sound` (iOS foreground delivery)
- Deep link: process after `startKoin` completes and root view `.task` has fired
- Cold-start smoke test: kill app, send push, assert destination renders with content

**Open decision to resolve before starting:** KMPNotifier vs hand-rolled `expect`/`actual` vs separate `:shared-notifications` module.

**Research flag:** Needs pre-phase setup checklist (Firebase project, APNs key, Apple Developer Console). External credentials require 1-2 days lead time before code can be tested end-to-end.

---

### Phase 5: Navigation Drawer

**Rationale:** The navigation drawer is the most state-complex component and integrates with all others. It consumes the deep-link routing contract established in Phase 4. Building it last among the components means the push destination resolution is stable.

**Delivers:** `NavDrawerViewModel` + `NavDrawerUiState` in `commonMain`; `NavDrawer.kt` (Compose `ModalNavigationDrawer`) + `NavDrawer.swift` (SwiftUI custom sheet); 2-level collapsible tree with `AnimatedVisibility`; deep-link path auto-expansion; hamburger + scrim dismiss.

**Must address:**
- iOS drawer opens via hamburger only — no left-edge swipe (conflicts with `NavigationStack` back swipe system gesture)
- `AnimatedVisibility` for collapsed branches — not `alpha = 0` / `isHidden` (ghost items in accessibility tree)
- `expandPathTo(nodeId, tree)` pure function: when a deep link sets the active node, expand all ancestors before render
- Navigation execution per-platform; ViewModel fires `NavIntent.RouteSelected(route)`, platform converts to `NavController.navigate()` or `NavigationPath` mutation

**Open decision to resolve before starting:** NavDrawer route tree representation — recursive `NavNode(children: List<NavNode>)` vs flat `NavItem(parentId: String?)`.

**Research flag:** Non-obvious iOS gesture conflict and deep-link collapsed-tree expansion are fully documented in pitfalls. Standard execution once route tree shape decision is locked.

---

### Phase 6: Showcase App

**Rationale:** The showcase is a consumer of the published library. Must be built after all four component families are complete. The currency rates API call doubles as the Ktor networking demo.

**Delivers:** `:shared-app` showcase VMs + Koin wiring, `androidApp/showcase/` screens, `iosApp/Showcase/` screens, Ktor call against a public API, SQLDelight-backed feature demo.

**Open decision:** API selection (PROJECT.md marks TBD — likely exchange rates / open.er-api.com for keyless public access).

**Research flag:** Standard wiring. Resolve API selection at phase kickoff.

---

### Phase 7: Published Artifacts (Maven Central + SPM)

**Rationale:** Publishing requires all library modules to be stable. The `dev.skeleton` group ID is a placeholder and must be renamed to a domain-backed ID before this phase. Maven Central is immutable — a partial publish at the wrong coordinates cannot be undone without a version bump.

**Delivers:** `:shared-core` + `:shared-components` published to Maven Central (vanniktech `0.36.0`); XCFramework published via KMMBridge `1.1.0` to a separate SPM repository; CI publish jobs on `ubuntu-latest` (Maven) and `macos-14` (SPM).

**Must address:**
- Rename `dev.skeleton` group ID before any publish attempt
- `publishToMavenLocal` dry run before targeting Maven Central
- `:shared-app` (showcase) never published — `implementation` (not `api`) dep enforces this

**Open decision:** Final group ID / domain name. Must be resolved before Phase 7 begins.

**Research flag:** Maven Central publish is well-documented with the vanniktech plugin. KMMBridge maintenance pace has slowed — monitor and have `ge-org/multiplatform-swiftpackage` as fallback.

---

### Phase Ordering Rationale

Three dependency chains drive the sequence:

1. **Tooling gate (Phase 1):** AGP 9 plugin + SKIE + `IosViewModelStoreOwner` lifecycle must be correct before any KMP module compiles for iOS. Twelve pitfalls cluster here.

2. **Token bridge gate (Phase 2):** All component families consume `DesignTokens`. Hardcoded colors in components are expensive to refactor; the bridge costs ~1-2 days and unblocks everything visual.

3. **Dependency topology (Phases 3–7):** Forms/amount/in-app have no external deps (Phase 3). Push has external SDK + consumes in-app notifications (Phase 4). Drawer consumes push deep-link contract (Phase 5). Showcase consumes all four (Phase 6). Publish consumes showcase verification (Phase 7).

**Parallelisable seams:**
- Phase 3: shared ViewModel tests can start before platform UI; Compose and SwiftUI renderers parallel once contracts stable.
- Phase 4: Firebase project + APNs credential setup can start during Phase 3 implementation.
- Phases 5–6: `NavDrawerViewModel` unit tests can start before platform UI; showcase screen layout can start before all data flows are wired.

### Research Flags

**Needs pre-phase resolution:**
- **Phase 3:** Resolve notification queue type and currency precision type at kickoff (30-min decision, not research).
- **Phase 4:** External credential lead time — Firebase project + APNs key must be created before push code can be end-to-end tested. Also resolve KMPNotifier vs hand-rolled.
- **Phase 5:** Resolve route tree shape before sprint starts.
- **Phase 7:** Group ID domain decision must precede implementation; Maven Central account verification required.

**Standard patterns (no additional research):**
- **Phase 1:** All choices locked and verified.
- **Phase 2:** Simple, fully documented.
- **Phase 6:** Standard wiring after API selection.

---

## Open Decisions

Six decisions are unresolved and must be answered before or at the start of their corresponding phase.

| # | Decision | Must resolve by | Options | Current lean |
|---|----------|----------------|---------|--------------|
| 1 | **Currency formatter approach** | Phase 3 start | Custom `expect`/`actual` with `java.text.NumberFormat` / `NSNumberFormatter` vs `Kurrency` library | Custom `expect`/`actual` — no KMP library has full coverage as of May 2026 |
| 2 | **Amount input precision type** | Phase 3 start | `Long` cents vs `BigDecimal` via `ionspin/kotlin-multiplatform-bignum` | `BigDecimal` — `Long` cents constrains the API; locale bugs with `Double` are well-documented |
| 3 | **In-app notification queue type** | Phase 3 start | `StateFlow` (latest-wins) vs `MutableSharedFlow(replay=0, extraBufferCapacity=64)` | `MutableSharedFlow` — avoids replay-on-rotation and handles burst |
| 4 | **Push: KMPNotifier vs hand-rolled** | Phase 4 start | `KMPNotifier` (transitive Firebase) vs thin `expect`/`actual` in `:shared-components` vs separate `:shared-notifications` module | Separate `:shared-notifications` module — keeps push optional for skeleton consumers |
| 5 | **NavDrawer route tree shape** | Phase 5 start | Recursive `NavNode(children: List<NavNode>)` vs flat `NavItem(parentId: String?)` | Recursive — ergonomic for rendering; flat serialization is a later concern |
| 6 | **`dev.skeleton` group ID rename** | Phase 7 start | Must be a domain-verified group ID before Maven Central publish | TBD — requires domain ownership decision |

**Two additional questions that need user input:**
- **Server stub deployment shape:** Runs locally only (for showcase testing) vs deployed to a public URL (for end-to-end push testing on physical devices)?
- **RTL scope for v1:** If any target market uses Arabic or Hebrew, promote RTL amount input from v1.x to v1.

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All versions verified against official release notes, GitHub releases, and docs as of 2026-05-08. Single validated compatibility matrix. |
| Features | HIGH | All four component families researched with official Android/iOS HIG sources; table stakes and anti-features grounded in platform conventions. |
| Architecture | HIGH | Module layout, umbrella framework pattern, component shape, and build order verified against JetBrains official docs and Android Architecture guide. |
| Pitfalls | HIGH | 23 pitfalls cross-verified against official docs, community post-mortems, and issue trackers. |
| Currency formatter implementation | MEDIUM | `expect`/`actual` approach is well-established but no single authoritative source; cross-referenced KMP tutorials and platform API docs. |
| In-app notification queue type | MEDIUM | `MutableSharedFlow` recommendation is community consensus; specific `extraBufferCapacity` value is empirical. |
| KMMBridge longevity | MEDIUM | Version verified (1.1.0, Jan 2025); project maintenance pace has slowed. Fallback documented. |

**Overall confidence:** HIGH

### Gaps to Address

- **Currency precision type** (`Long` cents vs `BigDecimal`): Both viable. If `Long` is chosen, document the API constraint explicitly.
- **Notification queue implementation**: The `MutableSharedFlow` approach requires `@OptIn(ExperimentalCoroutinesApi::class)`; evaluate whether a `Channel`-backed approach is cleaner for the public API.
- **KMMBridge maintenance**: Monitor touchlab/KMMBridge; if abandoned before Phase 7, `ge-org/multiplatform-swiftpackage` handles the same XCFramework → SPM flow.
- **Server stub deployment shape**: Unspecified in PROJECT.md — resolve before Phase 4 so the stub can be tested on physical devices.
- **SwiftUI phone-drawer approach**: The exact SwiftUI pattern (`.sheet`, custom `ZStack` overlay with `DragGesture`, `NavigationSplitView` on iPad) should be prototyped early in Phase 5 before committing the component shape.

---

## Sources

### Primary (HIGH confidence)
- [JetBrains KMP ViewModel docs](https://kotlinlang.org/docs/multiplatform/compose-viewmodel.html)
- [Android Developers: Set up ViewModel for KMP](https://developer.android.com/kotlin/multiplatform/viewmodel)
- [AGP 9.2.0 release notes](https://developer.android.com/build/releases/agp-9-2-0-release-notes)
- [Compose BOM 2026.05.00 mapping](https://developer.android.com/develop/ui/compose/bom/bom-mapping)
- [androidx.lifecycle 2.10.0 releases](https://developer.android.com/jetpack/androidx/releases/lifecycle)
- [SKIE 0.10.11 releases + compatibility](https://github.com/touchlab/SKIE/releases)
- [Firebase Android BoM 34.13.0 release notes](https://firebase.google.com/support/release-notes/android)
- [Navigation 3 1.1.1 releases](https://developer.android.com/jetpack/androidx/releases/navigation3)
- [SQLDelight 2.3.2 docs](https://sqldelight.github.io/sqldelight/latest/2.x/)
- [Koin 4.2.1 releases](https://github.com/InsertKoinIO/koin/releases)
- [vanniktech maven-publish 0.36.0](https://github.com/vanniktech/gradle-maven-publish-plugin/releases)
- [Apple Xcode 16 App Store requirement](https://developer.apple.com/news/upcoming-requirements/)
- [Android Developers: Navigation Drawer](https://developer.android.com/jetpack/compose/components/drawer)
- [Android Developers: Snackbar](https://developer.android.com/develop/ui/compose/components/snackbar)

### Secondary (MEDIUM confidence)
- [KMM Umbrella Architecture — Marcin Piekielny](https://medium.com/@maruchin/kmm-architecture-4-umbrella-a26a370071d5) — umbrella pattern Gradle config
- [KMPNotifier — mirzemehdi](https://github.com/mirzemehdi/KMPNotifier) — push notification interface reference
- [Cash App blog: KMP money formatter](https://code.cash.app/kotlin-multiplatform-money-formatter) — `expect`/`actual` currency formatting
- [KMMBridge — Touchlab](https://kmmbridge.touchlab.co/docs/) — SPM publish automation
- [JetBrains: AGP 9 migration guide](https://kotlinlang.org/docs/multiplatform/multiplatform-project-agp-9-migration.html)
- Community sources: iOS SwiftUI keyboard avoidance, IME composing text race, SwiftUI in-app banner patterns, navigation drawer gesture conflicts

---
*Research completed: 2026-05-08*
*Ready for roadmap: yes*
