# Pitfalls Research

**Domain:** KMP skeleton — Compose + SwiftUI + SKIE + Ktor + SQLDelight + Koin + StateFlow + shared ViewModel
**Researched:** 2026-05-08
**Confidence:** HIGH (all pitfalls cross-verified against official docs, community post-mortems, and issue trackers)

---

## Critical Pitfalls

### Pitfall 1: `viewModelScope` Does Not Cancel Itself on iOS

**Symptom:**
Coroutines keep running after the user navigates away from a screen on iOS. Memory climbs. Background network calls fire for screens that no longer exist. The bug is invisible in debug because the app is rarely memory-pressured during manual testing.

**Why it happens:**
On Android, `viewModelScope` is tied to `ViewModelStore.clear()`, which the framework calls automatically when the activity/fragment/NavBackStackEntry is destroyed. On iOS there is no equivalent lifecycle owner. `IosViewModelStoreOwner` bridges the gap, but only if it is declared as `@StateObject` (not `@ObservedObject`) in the SwiftUI view, and only if its `deinit` actually executes. If the owner is declared `@ObservedObject`, SwiftUI may re-create or re-share the instance, and `deinit` is never called on the original object.

**Cost:** L — hard to detect, causes silent resource exhaustion, often appears only in production load tests.

**Detection:**
- Add a `println`/`NSLog` in `IosViewModelStoreOwner.deinit` in the scaffold phase; verify it fires when the view is popped.
- In CI, write a `commonTest` that creates a ViewModel, calls all `viewModelScope.launch { }` paths, then calls `viewModelStore.clear()` and asserts no coroutines are active (using `TestCoroutineScheduler`).

**Prevention:**
- Always declare `IosViewModelStoreOwner` as `@StateObject`, never `@ObservedObject`. Enforce this in code review.
- `IosViewModelStoreOwner.deinit` must call `viewModelStore.clear()` — this is the canonical Google sample pattern; do not deviate.
- Add a `ViewModel.onCleared()` log in every shared ViewModel during development; if the log never appears on iOS during navigation, the lifecycle is broken.

**Phase to address:** Phase 1 (KMP scaffold) — wire `IosViewModelStoreOwner` correctly from the first screen.

---

### Pitfall 2: `@ObservedObject` vs `@StateObject` for the ViewModel Wrapper

**Symptom:**
On iOS, the UI silently loses all in-flight state when the parent view re-renders. A network load that was 50% done disappears. Form pre-fill data vanishes mid-typing.

**Why it happens:**
`@ObservedObject` does not own the object — SwiftUI may discard and re-create the wrapper on re-render. The ViewModel inside is destroyed mid-flight. `@StateObject` is the only property wrapper that guarantees ownership for the lifetime of the view.

**Cost:** M — reproducible but intermittent; often not caught until a beta tester reports it.

**Detection:**
Add a `let id = UUID()` to `IosViewModelStoreOwner` and log it in `body`. If the ID changes between renders, the ownership is wrong.

**Prevention:**
Use `@StateObject private var owner = IosViewModelStoreOwner()` — the exact pattern from Google's KMP ViewModel guide. Lint rule: reject any `@ObservedObject IosViewModelStoreOwner` in code review.

**Phase to address:** Phase 1 (KMP scaffold).

---

### Pitfall 3: SKIE + Kotlin Version Lock-Step Ignored

**Symptom:**
After a routine Kotlin version bump, the iOS framework fails to compile. Error messages reference SKIE internals (`co.touchlab.skie`). Clean build and Xcode DerivedData clear do not resolve it.

**Why it happens:**
SKIE generates Swift-compatible wrappers by hooking into the Kotlin/Native compiler pipeline. Each SKIE version declares a narrow compatible Kotlin range (e.g., `0.x` supports Kotlin up to a specific minor). Upgrading Kotlin without simultaneously upgrading SKIE produces compiler plugin API mismatches. The same applies to AGP 9.0+: `com.android.library` can no longer be combined with `org.jetbrains.kotlin.multiplatform` — the plugin must migrate to `com.android.kotlin.multiplatform.library`.

**Cost:** XL if caught late — can block an iOS release for days.

**Detection:**
- Check SKIE's compatibility page before any Kotlin upgrade.
- Add a `./gradlew :shared:linkDebugFrameworkIosSimulatorArm64` step to every CI PR; if it fails, catch it before merge.

**Prevention:**
- Group `kotlin`, `skie`, `ksp`, and `agp` in a single `[versions]` block in `libs.versions.toml` with a comment: `# Update these four together — see SKIE compatibility matrix`.
- Pin all four to a known-good combination at project init. Do not bump any of them independently.
- After AGP 9.0 adoption: replace `com.android.library` plugin in the `shared` module with `com.android.kotlin.multiplatform.library`.

**Phase to address:** Phase 1 (KMP scaffold, tooling setup).

---

### Pitfall 4: SKIE Generics — `Result<T>` and `Flow<T?>` Type Erasure

**Symptom:**
A `StateFlow<Result<Profile>>` appears in Swift as `SkieSwiftStateFlow<Any?>`. The compiler accepts the code but the cast fails at runtime, or the Swift type is `Any?` with no way to recover the original `T`.

**Why it happens:**
Objective-C generics require the type argument to be a class. When SKIE generates the Swift enum wrapper for a sealed class used as a generic type argument (e.g., `Result<T>`), it cannot preserve the type parameter in the ObjC bridge layer. `Flow<Int?>` maps to `SkieSwiftOptionalFlow<Int>`, which has no inheritance relationship to `SkieSwiftFlow<Int>`.

**Cost:** M — requires API redesign for every affected ViewModel.

**Detection:**
Open the generated `.swift` header in `shared.framework/Headers/` after first build and search for `Any?` — any occurrence in a Flow/StateFlow signature is an erased generic.

**Prevention:**
- Never expose `Result<T>` across the KMP/Swift boundary. Use a project-specific sealed class (`UiState.Ready(data: T)` / `UiState.Error`) instead.
- Avoid `Flow<SomeEnum?>` where `SomeEnum` is itself a sealed class. Wrap nullable sealed states in a non-nullable sealed class.
- Validate all public ViewModel APIs in Swift immediately after scaffold by writing Swift-side type assertions.

**Phase to address:** Phase 1 (KMP scaffold), Phase 2 (design token bridge and first real ViewModel).

---

### Pitfall 5: Suspend Functions Without `@Throws` Silently Swallow Non-Cancellation Exceptions in Swift

**Symptom:**
A Kotlin suspend function that throws a domain exception (`NetworkException`, `ValidationError`) appears to succeed from Swift — no error is thrown, the `async` call returns `nil`. Errors are invisible to the caller.

**Why it happens:**
Without `@Throws(ExceptionClass::class)`, the Kotlin compiler only bridges `CancellationException`. All other thrown exceptions are swallowed at the ObjC boundary. SKIE generates `async` Swift wrappers, but if the Kotlin function is not annotated, the generated Swift does not declare `throws`.

**Cost:** M — silent error swallowing causes corruption of UI state with no crash trace.

**Detection:**
Write a unit test that calls the suspend function from a Swift `Task` with a known-bad input, and assert the thrown error is visible in the `catch` block.

**Prevention:**
- All public suspend functions in `commonMain` that can throw must be annotated: `@Throws(AppException::class)`.
- Define one sealed `AppException : Exception` hierarchy; throw only subtypes of it.
- Add a Kotlin lint rule (detekt rule or custom) that flags public `suspend fun` without `@Throws`.

**Phase to address:** Phase 1 (KMP scaffold) — establish the error convention before any feature ViewModel is written.

---

### Pitfall 6: Design Token ARGB Overflow — `Long` vs `Int`

**Symptom:**
Colors appear wrong or transparent on iOS in dark mode. Android looks fine. Specifically: fully-opaque dark-palette colors (e.g., `0xFF121212`) render as transparent or with a wrong alpha channel in Swift.

**Why it happens:**
`0xFFFFFFFF` exceeds `Int.MAX_VALUE` (signed 32-bit). If any color constant is declared or cast as `Int`, the value wraps to a negative number. In Swift, the bridged value arrives as `Int32`, which interprets the high bit as the sign bit. The alpha extraction `(value >> 24) & 0xFF` then yields 0 or a wrong value. Dark palette constants (all starting with `0xFF...`) are uniformly affected; light palette constants may appear to work by accident if the alpha byte happens to be in range.

**Cost:** L — affects every color on iOS; the bug is not caught by Android tests.

**Detection:**
Write a `commonTest` that asserts `LightColors.primary > 0L` and `DarkColors.primary > 0L` — a negative value means `Int` was used. Run this test on the `iosSimulatorArm64` target.

**Prevention:**
- Every color constant in `DesignTokens.kt` must be declared as `Long` and suffixed with `L`: `const val primary: Long = 0xFF3B82F6L`. This is already the pattern in `README.md` — enforce it in code review.
- The Swift adapter must use `Int64` (not `Int32`) when receiving color values: `let argb: Int64 = token` then `(argb >> 24) & 0xFF` for alpha.
- Add a `@Test fun noColorConstantIsNegative()` in `commonTest/theme/`.

**Phase to address:** Phase 2 (design token bridge).

---

### Pitfall 7: Dark Mode Token Selected on the Wrong Side of the Bridge

**Symptom:**
On iOS, the app renders in light mode even after the user switches the system to dark. Or vice versa. The bug is intermittent — a hot reload fixes it because the `colorScheme` environment re-propagates.

**Why it happens:**
If the Kotlin `ViewModel` or `DesignTokens` object resolves the light/dark palette based on a boolean flag passed from Swift, there is a propagation race: the iOS `@Environment(\.colorScheme)` fires asynchronously, and the Kotlin-side flag lags by one recompose cycle. The correct ownership is: Kotlin stores both `LightColors` and `DarkColors`; Swift reads `@Environment(\.colorScheme)` and selects which object to pass to `AppTheme.color(...)`.

**Cost:** M — incorrect theming is a high-visibility UX bug.

**Detection:**
Switch system appearance rapidly 10 times in the iOS simulator; observe whether the color updates synchronously on each switch. Any lag indicates Kotlin owns the selection.

**Prevention:**
- Kotlin's `DesignTokens` object exports two color sets: `LightColors` and `DarkColors`. It never selects between them.
- SwiftUI root view reads `@Environment(\.colorScheme)` and calls `AppTheme.color(dark ? DarkColors.shared.primary : LightColors.shared.primary)`.
- This is exactly the pattern documented in `README.md`; do not shortcut by passing a `isDark: Boolean` state through the ViewModel.

**Phase to address:** Phase 2 (design token bridge).

---

### Pitfall 8: Compose `TextFieldState` / IME Composing Text Race

**Symptom:**
On Android, CJK input (or any IME with a composing phase) causes the cursor to jump, text to duplicate, or in-progress composition to be reset mid-character. Validation error messages flash then vanish while the user is still typing.

**Why it happens:**
The legacy `MutableState<String>` + `onValueChange` model triggers a full recomposition on every keystroke. When recomposition races the IME's composing-text update, the text field receives a state snapshot from before the latest composing text — the IME's pending characters are overwritten. Running validation inside `onValueChange` compounds this: the validation state change triggers another recompose, which again interrupts composition.

**Cost:** M — affects any user with a soft keyboard that uses composing (virtually all Android users typing in a language other than English).

**Prevention:**
- Use `rememberTextFieldState()` (the `TextFieldState` API introduced in Compose 1.7) for all form inputs. External state pushes do not override in-flight IME composing text.
- Validate on focus loss (`InteractionSource.collectIsFocusedAsState()` transitioning from `true` to `false`) or on explicit Submit, never inside `onValueChange`.
- Debounce any validation that must run on change (minimum 300 ms).

**Detection:**
Enable Japanese/Korean IME in the Android emulator; type a multi-character composition and assert no cursor jump in a `Compose UI test`.

**Phase to address:** Phase 3 (form component).

---

### Pitfall 9: iOS Keyboard Avoidance and Form Scroll Position

**Symptom:**
On iOS, when a `TextField` near the bottom of a form is tapped, the keyboard covers it. The user cannot see what they are typing. Or the view jumps in a way that hides a different field.

**Why it happens:**
SwiftUI does provide `ScrollView` + `.scrollDismissesKeyboard(.interactively)` in iOS 16+, but this only works when the `TextField` is inside a `ScrollView`. If the form uses `VStack` without a scroll container, the keyboard does not push the content up. Additionally, `focusedField` management must explicitly be wired with `@FocusState` — without it, switching fields with the keyboard's Next/Done button silently does nothing.

**Cost:** M — immediately visible to any iOS user trying to fill a long form.

**Prevention:**
- Wrap every multi-field form in `ScrollView { ... }.scrollDismissesKeyboard(.interactively)`.
- Declare `@FocusState var focusedField: FormField?` and bind each `TextField` to its case. Wire `onSubmit` to advance or close focus.
- On iOS 15 (if supported), use a `GeometryReader` + `.ignoresSafeArea(.keyboard)` workaround.

**Detection:**
Open the showcase form on a physical iPhone (or a simulator with software keyboard enabled), tap the last field in the form, and verify it scrolls into view.

**Phase to address:** Phase 3 (form component).

---

### Pitfall 10: Currency Decimal Separator Locale Mismatch

**Symptom:**
Users in Germany, France, or Brazil cannot enter a decimal amount. The input field either rejects the comma entirely, or formats `1,50` as `150`. Users in English locales break the field by pasting `€1.234,50`.

**Why it happens:**
`NumberFormat` and `DecimalFormatSymbols` return locale-specific symbols at runtime: `.` for `en-US`, `,` for `de-DE`, ` ` (non-breaking space) for `fr-FR`. If the input filter hardcodes `.` as the decimal separator, users in comma-decimal locales can never enter a decimal. On the flip side, if the filter blindly accepts `,`, it collides with thousands separators in some locales.

**Cost:** M — renders the amount input unusable for non-English locales.

**Prevention:**
- Detect the decimal separator at runtime: `DecimalFormatSymbols.getInstance(locale).decimalSeparator` (Android/JVM), `NSLocale.current.decimalSeparator` (iOS).
- Pass the runtime separator to the `VisualTransformation` / `InputFilter` so the field accepts the locale-correct character.
- Use `BigDecimal` (or `kotlinx-bignum`) for the internal value — never `Double`. `Double` representation errors manifest as rounding artifacts when re-formatting.
- Test on `de-DE` and `fr-FR` locales in addition to `en-US`.

**Detection:**
Switch the emulator/simulator locale to `de-DE`, open the currency input field, attempt to type `1,50`. Assert the stored value is `BigDecimal("1.50")`.

**Phase to address:** Phase 3 (currency input component).

---

### Pitfall 11: Paste and IME Composing Text in Currency Input

**Symptom:**
Pasting `$1,234.56` into the currency field stores `1234.56` on some locales but `1234` or `1234,56` on others. On Android with Gboard, autocorrect inserts a composed character string that bypasses the digit filter entirely, allowing letters into the field.

**Why it happens:**
Paste bypasses the IME composing state; the full string is inserted in one transaction. The digit filter sees characters it has not individually validated. In addition, clipboard content often includes currency symbols and thousand separators that are locale-mismatched relative to the current device locale.

**Cost:** S-M — creates silent data corruption in financial amounts.

**Prevention:**
- Apply a post-paste sanitizer: strip all characters except digits and the current locale's decimal separator. Enforce max decimal-places constraint after sanitization.
- For Android: override `onTextChanged` with `InputFilter` + a paste-specific branch using `TextWatcher.afterTextChanged`.
- For iOS: use `TextField(value:, formatter:)` with a custom `NumberFormatter` that strips disallowed characters.
- Enforce max significant digits (e.g., 15) to prevent overflow during formatting.

**Detection:**
Write a unit test that feeds `"$1,234.56"`, `"1.234,56"`, and `"€ 1 234,56"` into the sanitizer and asserts the output is `BigDecimal("1234.56")` each time.

**Phase to address:** Phase 3 (currency input component).

---

### Pitfall 12: Push Notification Token Refresh Race — FCM + APNs

**Symptom:**
Push notifications are delivered to some devices but silently dropped for others. On Android, a fresh install never receives pushes. After a token refresh (app update, token rotation), pushes stop arriving until the next app foreground.

**Why it happens:**
FCM generates a new registration token on first run, and may rotate it later. If the token-upload to the server is not retried on next foreground, the server holds a stale token. On iOS, the APNs token and the FCM registration token are two separate values; FCM must register the APNs token with its SDK before it can issue an FCM token. If the FCM token is read before APNs registration completes, the token is `nil` or stale.

**Cost:** L — critical for any notification-dependent feature; silent failure.

**Prevention:**
- Android: implement `FirebaseMessagingService.onNewToken()` — always upload the new token to the backend; never rely only on the initial token from `getToken()`.
- iOS: call `UNUserNotificationCenter.requestAuthorization()` → `UIApplication.registerForRemoteNotifications()` → wait for `didRegisterForRemoteNotificationsWithDeviceToken` → then call `Messaging.messaging().apnsToken = deviceToken` before reading the FCM token.
- Server stub: implement a token table with `(userId, platform, token, updatedAt)`; overwrite on each upload; treat HTTP 404/410 from FCM as signal to delete the token.
- Use FCM v1 API (HTTP v1 with OAuth 2.0 Bearer token) — the legacy API was deprecated.

**Detection:**
Uninstall and reinstall the app on a test device; send a push from the server stub within 30 seconds; assert delivery.

**Phase to address:** Phase 4 (push notifications).

---

### Pitfall 13: Deep Link Tapped Before ViewModel Is Created

**Symptom:**
User taps a push notification while the app is completely closed (not backgrounded). The app launches, navigates to the deep-link destination, but the destination screen shows a blank/error state because the ViewModel has not finished initializing when the navigation event fires.

**Why it happens:**
On cold start, Koin modules are initialized, then the navigation host renders the start destination, and only then does the notification-triggered navigation event fire. But if the deep link target's ViewModel was not pre-warm and Koin resolution has not completed, the ViewModel's `onAppear()` is called on a partially-initialized graph.

**Cost:** L — visible to any user who taps a notification on cold start.

**Prevention:**
- Process the deep link intent/URL in the ViewModel or a `NavigationManager` after `startKoin` completes, not in `Activity.onCreate` directly.
- On Android: use `Intent` extras passed to the `NavController.handleDeepLink()` only after `setContent {}` has established the composition.
- On iOS: deliver the push payload via `scene(_:continue:)` / `application(_:didReceiveRemoteNotification:)` and route it through the navigation state after the root view's `.task` has fired.
- Write a cold-start smoke test: kill the app, trigger a deep-link notification, assert the correct screen renders with content (not blank).

**Detection:**
Kill the app process entirely in Instruments; send a push; measure time-to-first-frame and assert no blank navigation destination appears.

**Phase to address:** Phase 4 (push notifications) and Phase 5 (navigation drawer integration).

---

### Pitfall 14: iOS Foreground Push Not Delivered to UI

**Symptom:**
Push notifications are received (APNs delivers them) but nothing appears on screen when the app is foregrounded. The notification center shows the notification, but the in-app banner does not fire.

**Why it happens:**
On iOS, push notifications sent while the app is in the foreground are not shown by the system unless `UNUserNotificationCenterDelegate.userNotificationCenter(_:willPresent:withCompletionHandler:)` is implemented and calls the completion handler with `.banner` and `.sound`. Without this delegate method, iOS silently discards the presentation.

**Cost:** M — the notification feature "works in testing" (app backgrounded) but fails in normal use.

**Prevention:**
Implement `UNUserNotificationCenterDelegate` and always call `completionHandler([.banner, .sound, .badge])` in `willPresent`. Set the delegate on `UNUserNotificationCenter.current()` before calling `requestAuthorization`.

**Detection:**
With the app foregrounded, trigger a test push from the server stub; assert the in-app banner appears within 2 seconds.

**Phase to address:** Phase 4 (push notifications).

---

### Pitfall 15: Navigation Drawer Edge Gesture vs. iOS Back Swipe Conflict

**Symptom:**
On iOS, attempting to open the sidebar drawer by swiping from the left edge instead triggers the `NavigationStack` back gesture and navigates the user away from the current screen.

**Why it happens:**
iOS `NavigationStack` claims the left-edge swipe gesture system-wide. A custom drawer that also responds to a left-edge pan gesture will conflict. The `NavigationStack` gesture recognizer has higher priority and wins, so the drawer never opens.

**Cost:** M — the primary gesture for a sidebar drawer is completely broken on iOS.

**Prevention:**
- On iOS, trigger the drawer via a hamburger button tap, not an edge gesture. Do not rely on edge-swipe to open the drawer.
- If edge swipe is desired, intercept at the `UIViewController` level with `interactivePopGestureRecognizer.isEnabled = false` for screens that own the drawer — but this disables back swipe entirely on those screens, which is a poor UX tradeoff.
- On Android (Compose), use `DrawerState.open()` via a gesture; on iOS, use a button. Accept the platform difference.

**Detection:**
On the iOS simulator, tap and slowly drag from x=0 with the drawer screen visible; assert `NavigationStack.popBackStack()` does not fire.

**Phase to address:** Phase 5 (navigation drawer component).

---

### Pitfall 16: Deep Linking Into a Collapsed Tree Node

**Symptom:**
A push notification deep link navigates to `Profile > Billing > Invoices`. The tree sidebar shows the correct active item, but the parent nodes (`Profile`, `Billing`) are collapsed and the selected item is not visible in the tree, leaving the user with a blank-looking sidebar.

**Why it happens:**
The tree sidebar state is initialized collapsed. The deep link fires the navigation event before the sidebar has expanded the path to the destination node. The `selectedNode` is set but its ancestors are not in `expandedNodes`.

**Cost:** M — confusing UX on every notification-triggered navigation.

**Prevention:**
- When a deep link target is set, compute the path from the root to the target node and add every ancestor to `expandedNodes` before rendering.
- Make this a pure function: `fun expandPathTo(nodeId: String, tree: TreeNode): Set<String>`.
- Write a unit test: given a collapsed tree and a leaf node ID, assert `expandPathTo` returns all ancestor IDs.

**Detection:**
Set the drawer state to fully collapsed; trigger a deep link to a leaf node; assert the node is visible (all parents expanded).

**Phase to address:** Phase 5 (navigation drawer component).

---

### Pitfall 17: In-App Notification Covered by Modal Sheet on iOS

**Symptom:**
A success/error banner appears after a form is submitted, but is invisible because a modal sheet is covering the root view hierarchy. The notification fires into the `ZStack` of `ContentView`, which is behind the sheet.

**Why it happens:**
SwiftUI modal sheets and `fullScreenCover` create a new view hierarchy layer. An overlay or `ZStack`-based notification system that is anchored to `ContentView` is rendered below the sheet, not above it.

**Cost:** M — notification feedback disappears precisely when the user needs it most (after an action).

**Prevention:**
- Use a `UIWindow` overlay approach: create a secondary `UIWindow` above the app's key window and present notifications there. This guarantees banners float above any modal hierarchy.
- Alternatively, present the notification manager as a modifier inside the sheet content as well (inject it at every modal boundary).
- Design the notification manager as a `@MainActor` singleton with an `@Published var queue: [Notification]`, injected via SwiftUI environment.

**Detection:**
Present a form inside a `.sheet`; submit it; assert the success banner appears on top of the sheet.

**Phase to address:** Phase 3-4 (in-app notification component, integrated with push).

---

### Pitfall 18: `kotlin.test.Test` vs `org.junit.Test` in `commonTest`

**Symptom:**
Tests written in `commonTest` pass on Android but are silently skipped on the iOS simulator target in CI. Coverage reports show 100% on Android, 0% on iOS for the same code path.

**Why it happens:**
`org.junit.Test` is only recognized by the JUnit runner (JVM/Android). Kotlin/Native (the iOS runner) does not load JUnit annotations. Tests with the wrong annotation exist in the source but are never discovered by `xctest` or the Kotlin/Native test runner.

**Cost:** S — but causes false confidence in test coverage.

**Prevention:**
- Always import `kotlin.test.Test` in `commonTest`, not `org.junit.Test`. Add a lint rule or a Detekt check.
- In CI, run `./gradlew :shared:iosSimulatorArm64Test` as a separate job and assert its test count matches `./gradlew :shared:jvmTest`.

**Detection:**
Compare test counts between the JVM and iosSimulatorArm64 test runs in CI. A count mismatch > 0 means some tests have wrong annotations.

**Phase to address:** Phase 1 (KMP scaffold, test setup).

---

### Pitfall 19: SQLDelight `NativeSqliteDriver` Missing `-lsqlite3` Linker Flag

**Symptom:**
iOS build succeeds, but the app crashes at runtime on the first database access with an `undefined symbol: _sqlite3_open` linker error or a `dyld: Symbol not found` crash.

**Why it happens:**
`NativeSqliteDriver` dynamically links against the system `libsqlite3`. Xcode does not add this automatically for frameworks embedded via SPM. Without the `-lsqlite3` flag in "Other Linker Flags", the symbol is unresolved at app launch.

**Cost:** M — app crashes on first database operation; 100% reproducible on device.

**Prevention:**
- Add `-lsqlite3` to "Other Linker Flags" in the `iosApp` Xcode target during the persistence scaffold phase.
- Alternatively, use `BundledSQLiteDriver` and set `linkSqlite = false` in the Gradle framework config — this bundles SQLite in the framework and avoids the linker dependency.

**Detection:**
Run the app on a clean iOS simulator after first adding SQLDelight; trigger any database read/write path and assert no crash.

**Phase to address:** Phase 1 (KMP scaffold — persistence layer).

---

### Pitfall 20: AGP 9.0 + `com.android.library` + KMP Plugin Incompatibility

**Symptom:**
After upgrading to AGP 9.0, the build fails with: `'com.android.library' cannot be applied alongside 'org.jetbrains.kotlin.multiplatform'`. Or, with AGP 9.0 + Kotlin 2.3.0+, a configuration error fires because `kotlin-android` plugin is now redundant.

**Why it happens:**
AGP 9.0 (released Q4 2025) introduced built-in Kotlin support and deprecated the old Android plugin + KMP plugin combination. The two plugins can no longer coexist in the same module. A new plugin, `com.android.kotlin.multiplatform.library`, is required for KMP modules that include an Android target.

**Cost:** XL — blocks all Android builds until resolved; not backward compatible.

**Prevention:**
- At project init, pin `agp = "9.x.y"` and apply `com.android.kotlin.multiplatform.library` (not `com.android.library`) to the `shared` module from day one.
- Keep `android.builtInKotlin=true` (the new default); do not use the `kotlin-android` plugin in `androidApp`.
- Add `./gradlew :androidApp:assembleDebug` to CI on every PR to catch plugin conflicts before they merge.

**Detection:**
Run `./gradlew :shared:tasks --all | grep android` after any dependency update and verify no deprecated task names appear.

**Phase to address:** Phase 1 (KMP scaffold, build configuration).

---

### Pitfall 21: `baseName = "shared"` XCFramework Conflicts When Consumer Embeds Multiple KMP Modules

**Symptom:**
When a consumer product adds a second KMP dependency (e.g., a utility library that also uses the `"shared"` baseName), the iOS build fails with `duplicate symbol` linker errors or module import ambiguity: `import shared` resolves to the wrong framework.

**Why it happens:**
The KMP wizard defaults `baseName = "shared"` for every new project. When two frameworks with the same name are linked into the same iOS app, the linker cannot disambiguate them. Types from each framework may appear identical at the ObjC level, causing silent type confusion or hard linker failures.

**Cost:** L — affects every downstream product that consumes this skeleton alongside another KMP library.

**Prevention:**
- Set `baseName = "SkeletonKit"` (or the product name) in `shared/build.gradle.kts` from day one. Do not use `"shared"`.
- Also name the `XCFramework("SkeletonKit")` call consistently.
- Update the `import shared` in `iosApp` to `import SkeletonKit` immediately.

**Detection:**
Add a second stub KMP module with `baseName = "shared"` and attempt a combined iOS build; a name collision immediately fails.

**Phase to address:** Phase 1 (KMP scaffold setup).

---

### Pitfall 22: Maven Central Duplicate Publication on Re-Publish

**Symptom:**
A `publishAllPublicationsToSonatype` run after a failed first attempt is rejected with HTTP 409 Conflict by the Central Portal. The artifact version is considered published even though the previous attempt was incomplete.

**Why it happens:**
Maven Central is immutable — once any artifact at a given `groupId:artifactId:version` coordinate touches the staging repository, it cannot be overwritten or deleted. A partial first publish (where some platform artifacts were uploaded but validation failed) leaves the version in a broken state that blocks all subsequent attempts.

**Cost:** M — forces a version bump just to re-publish.

**Prevention:**
- Use a separate `stagingProfileId` for each publish attempt; do not reuse a failed staging repository.
- Always publish to a local directory first (`publishToMavenLocal`) and verify all artifacts are present before targeting Central.
- In CI: use `publishAllPublicationsTo<Repo>` in a single Gradle invocation (not multiple separate `publish` calls) to avoid partial uploads.
- Keep a `0.0.1-SNAPSHOT` cycle for internal testing; only target Central for release versions.

**Detection:**
After a publish attempt, verify all expected Maven coordinates are resolvable: run `./gradlew dependencies` from a clean `testConsumer` project that depends only on the published coordinates.

**Phase to address:** Phase 6 (publish artifacts).

---

### Pitfall 23: iOS Simulator Tests Flaky on GitHub Actions `macos-latest`

**Symptom:**
`./gradlew :shared:iosSimulatorArm64Test` passes locally but randomly fails on GitHub Actions with timeout errors, simulator boot failures, or test-not-found results. The failure is non-deterministic — re-running the same commit sometimes passes.

**Why it happens:**
GitHub Actions `macos-latest` runners change their underlying macOS/Xcode version as Apple releases updates. The iOS Simulator is a shared resource on the runner; concurrent jobs can contend for it. Xcode 15+ simulators are significantly slower to boot than Xcode 14 simulators. SKIE's linker step also adds meaningful time to the framework build, stretching close to default timeout limits.

**Cost:** M — blocks CI reliability; developers lose trust in CI and start ignoring failures.

**Prevention:**
- Pin the runner explicitly: `runs-on: macos-14` (not `macos-latest`). Document the Xcode version in a `.github/CI.md`.
- Add `timeout-minutes: 30` to the iOS test job.
- Separate platform jobs: run `iosSimulatorArm64Test` in a dedicated job; do not combine it with Android or desktop test steps in the same job.
- For ViewModel and business logic tests, use `jvmTest` (fast, no simulator) and reserve the iOS job for integration/interop tests.

**Detection:**
Check GitHub Actions run history for the iOS job; a flakiness rate > 10% on the same code means the runner or timeout is misconfigured.

**Phase to address:** Phase 1 (CI setup).

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Hardcoding `Dispatchers.Main` in shared ViewModel | Simpler code | Fails on non-Android KMP targets if `Dispatchers.Main` is not available | Never — use `viewModelScope` which already wraps `Dispatchers.Main.immediate` |
| Using `@ObservedObject` for `IosViewModelStoreOwner` | Works in demos | Silent state loss on real app re-renders | Never |
| Raw `Double` for currency amounts | Familiar to Android devs | Rounding errors in formatting (e.g., `1.1 + 2.2 = 3.3000...004`) | Never for user-facing amounts |
| `baseName = "shared"` for the XCFramework | Works for single-module | Breaks the moment a second KMP library is added downstream | Never in a skeleton meant for reuse |
| Skipping `@Throws` annotation on suspend fns | Shorter API | Exceptions silently swallowed in Swift | Never for public API surface |
| `org.junit.Test` in `commonTest` | IntelliJ autocomplete suggests it | Tests silently skipped on iOS CI target | Never |
| `android.builtInKotlin=false` opt-out in AGP 9 | Buys time during migration | Stops working in AGP 10 (2026) | Only as a 2-sprint stopgap during AGP 9 migration |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|-----------------|
| FCM v1 | Still using legacy HTTP API with server key | Switch to OAuth 2.0 Bearer token; endpoint: `/v1/projects/{id}/messages:send` |
| APNs on iOS | Reading FCM token before `didRegisterForRemoteNotificationsWithDeviceToken` fires | Register with APNs first, set `Messaging.messaging().apnsToken`, then request FCM token |
| SQLDelight iOS | Missing `-lsqlite3` in Xcode "Other Linker Flags" | Add the flag, or switch to `BundledSQLiteDriver` with `linkSqlite = false` |
| Koin + iOS ViewModel | Resolving ViewModel directly via `KoinComponent.get()` without a `ViewModelStore` | Use `IosViewModelStoreOwner` + `viewModel(factory:)` to respect the ViewModel lifecycle |
| SKIE + `Result<T>` | Exposing Kotlin `kotlin.Result<T>` as a Flow generic | Use project-specific sealed `UiState` to avoid ObjC generic erasure |
| Maven Central | Triggering `publish` twice for the same version | Always bump the version before re-publishing; use staging repositories |
| SPM + XCFramework | Using default `baseName = "shared"` | Set a unique `baseName` matching the product name from day one |

---

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| `onValueChange` validation in currency/form fields | UI jank on every keystroke; excessive recomposition | Validate on focus loss or debounce at ≥ 300 ms | At any usage level; worse with slow devices |
| `StateFlow.collect` in iOS `.task` without back-pressure | Memory grows on rapid state changes (e.g., currency input on every character) | Use `conflate()` or `distinctUntilChanged()` on the flow | Noticeable at 60fps input rate |
| SKIE increasing binary size | iOS IPA grows > 50 MB for a simple app | Limit exported classes/functions with SKIE's `@SkieAnnotation` to only the public API surface | From the first release; grows with every new exported type |
| Coroutines launched on `Dispatchers.Default` emitting UI state | ANR/crash on iOS where `Dispatchers.Default` may not dispatch on Main | Always emit `_state.value = ...` from `Dispatchers.Main`; use `withContext(Dispatchers.Main)` at the emit site | Immediately on iOS |

---

## "Looks Done But Isn't" Checklist

- [ ] **IosViewModelStoreOwner lifecycle:** `deinit` has been verified to fire on navigation pop — add a log and test it.
- [ ] **Push notifications foreground delivery:** Tested with app in foreground, not just backgrounded/killed.
- [ ] **Currency input comma-locale:** Tested with device locale set to `de-DE`; `BigDecimal` parses correctly.
- [ ] **Dark mode colors:** All `DesignTokens` color constants are `Long` typed; tested on iOS with System Dark Mode enabled.
- [ ] **SKIE suspend exceptions:** All public suspend functions have `@Throws`; verified via a Swift-side catch test.
- [ ] **Deep link cold start:** Tested by fully killing the app and tapping a push notification; destination renders with content.
- [ ] **Sidebar with deep-linked node:** Tree auto-expands to show the active node when navigated via deep link.
- [ ] **In-app notification above modal:** Banner visible when triggered from inside a `.sheet` on iOS.
- [ ] **`kotlin.test.Test` only:** Grep `commonTest/` for `import org.junit.Test`; result must be empty.
- [ ] **Maven Central publish dry run:** `publishToMavenLocal` verified; all expected coordinates present before targeting Central.
- [ ] **`baseName` renamed:** `grep -r '"shared"' shared/build.gradle.kts` returns no framework baseName match.

---

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| `viewModelScope` iOS lifecycle leak | Phase 1 — KMP scaffold | `deinit` log fires on navigation pop |
| `@StateObject` vs `@ObservedObject` | Phase 1 — KMP scaffold | UUID log in owner body stays constant |
| SKIE + Kotlin version lock-step | Phase 1 — tooling setup | CI `linkDebugFrameworkIos*` green after each dep bump |
| SKIE generic type erasure | Phase 1 + Phase 2 | Swift header has no `Any?` in Flow signatures |
| `@Throws` missing on suspend fns | Phase 1 — scaffold API conventions | Swift-side catch test passes |
| ARGB `Long` overflow | Phase 2 — design tokens | `commonTest` no-negative-color assertion green on iOS target |
| Dark mode token selection ownership | Phase 2 — design tokens | Rapid appearance toggle test on iOS |
| IME composing text race | Phase 3 — form component | Japanese IME typing test in Compose |
| iOS keyboard avoidance | Phase 3 — form component | Last-field tap scroll test on physical device |
| Currency decimal separator locale | Phase 3 — currency input | `de-DE` locale input test |
| Currency paste sanitization | Phase 3 — currency input | Unit test for known dirty paste strings |
| Push token refresh race | Phase 4 — push notifications | Reinstall + send push within 30s |
| Deep link before ViewModel init | Phase 4 + Phase 5 | Cold-start push notification test |
| iOS foreground push silent drop | Phase 4 — push notifications | Foreground push delivery test |
| Drawer gesture vs back swipe | Phase 5 — navigation drawer | Edge swipe test on iOS simulator |
| Deep link into collapsed tree | Phase 5 — navigation drawer | Collapsed tree + deep link assertion |
| In-app notification under modal | Phase 3-4 — in-app notification component | Banner visible above `.sheet` test |
| `kotlin.test.Test` annotation | Phase 1 — test setup | CI iosSimulatorArm64Test count matches jvmTest count |
| SQLDelight `-lsqlite3` flag | Phase 1 — persistence scaffold | First DB operation on clean iOS sim succeeds |
| AGP 9.0 + KMP plugin incompatibility | Phase 1 — build configuration | `assembleDebug` green after AGP 9 pin |
| `baseName = "shared"` conflict | Phase 1 — scaffold naming | Two-framework iOS link test passes |
| Maven Central duplicate publish | Phase 6 — publish | `publishToMavenLocal` dry run before Central |
| iOS simulator flaky CI | Phase 1 — CI setup | Flakiness rate < 5% over 20 runs |

---

## Sources

- [Set up ViewModel for KMP — Android Developers](https://developer.android.com/kotlin/multiplatform/viewmodel) (official)
- [SKIE Features — touchlab.co](https://skie.touchlab.co/features/)
- [Sealed Classes — SKIE](https://skie.touchlab.co/features/sealed)
- [Enums — SKIE](https://skie.touchlab.co/features/enums)
- [Sealed Generics and SKIE — Touchlab](https://touchlab.co/sealed-generics-and-skie)
- [Crossing the Finish Line: StateFlow & SharedFlow in KMP — KMP Bits](https://www.kmpbits.com/posts/stateflow-kmp)
- [How I Solved the Biggest Architectural Trap in KMP — Medium](https://medium.com/@ofek.amirav/how-i-solved-the-biggest-architectural-trap-in-kotlin-multiplatform-kmp-93e19b078337)
- [Seamless KMP on iOS: Enhancing with SKIE — carrion.dev](https://carrion.dev/en/posts/kmp-ios-skie-integration/)
- [Update your Kotlin projects for AGP 9.0 — JetBrains Blog](https://blog.jetbrains.com/kotlin/2026/01/update-your-projects-for-agp9/)
- [Updating KMP projects to use AGP 9 — kotlinlang.org](https://kotlinlang.org/docs/multiplatform/multiplatform-project-agp-9-migration.html)
- [Input validation in Jetpack Compose — ProAndroidDev](https://proandroiddev.com/input-validation-in-jetpack-compose-e99c18b44fe3)
- [Configure text fields — Android Developers](https://developer.android.com/develop/ui/compose/text/user-input)
- [Android Currency Localisation Hell — Adam Speakman](http://speakman.net.nz/blog/2013/10/21/android-currency-localisation-hell/)
- [Manage regional formats — Kotlin Multiplatform Documentation](https://kotlinlang.org/docs/multiplatform/compose-regional-format.html)
- [Getting started with SQLDelight on Kotlin/Native](https://sqldelight.github.io/sqldelight/2.0.2/native_sqlite/)
- [Publishing a KMP library to Maven Central — DEV Community](https://dev.to/kotlin/how-to-build-and-publish-a-kotlin-multiplatform-library-going-public-4a8k)
- [Setting up multiplatform library publication — kotlinlang.org](https://kotlinlang.org/docs/multiplatform/multiplatform-publish-lib-setup.html)
- [KMMBridge — Touchlab](https://kmmbridge.touchlab.co/docs/)
- [Kotlin Multiplatform Testing in 2025 — kmpship.app](https://www.kmpship.app/blog/kotlin-multiplatform-testing-guide-2025)
- [iOS Simulator e2e tests flaky on GH Actions — Patrol issue](https://github.com/leancodepl/patrol/issues/2291)
- [Compose Multiplatform UI Testing — KMP Bits](https://www.kmpbits.com/posts/compose-ui-test-cmp)
- [Push Notifications: APNs vs FCM — Medium](https://medium.com/@sohail_saifi/push-notifications-apns-vs-fcm-implementation-4da88987a297)
- [SwiftUI in-app banner tutorial — Medium](https://dallinjared.medium.com/swiftui-tutorial-creating-an-in-app-banner-notification-system-97597d64f514)
- [Compose iOS gesture conflict — JetBrains issue #5026](https://github.com/JetBrains/compose-multiplatform/issues/5026)
- [Jetpack Compose Navigation 3 state loss — Medium](https://medium.com/@boobalaninfo/jetpack-compose-navigation-3-the-hidden-trap-of-state-loss-and-how-to-fix-it-d3f3637fc535)
- [KMP Advanced Patterns — Koin docs](https://insert-koin.io/docs/reference/koin-mp/kmp/)

---
*Pitfalls research for: KMP skeleton — Compose + SwiftUI + SKIE + Ktor + SQLDelight + Koin + StateFlow*
*Researched: 2026-05-08*
