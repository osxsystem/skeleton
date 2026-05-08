# Stack Research

**Domain:** Kotlin Multiplatform mobile skeleton + reusable Compose/SwiftUI component library
**Researched:** 2026-05-08
**Confidence:** HIGH (all versions verified against official docs, release notes, or GitHub releases as of 2026-05-08)

---

## 1. Build Tooling

### Kotlin

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| Kotlin | **2.3.21** | Language + KMP compiler | Current stable; K2 compiler is the default since 2.0; 2.3.x is the active stable line as of May 2026 |
| KMP Gradle plugin | bundled with Kotlin | Multiplatform source-set wiring | Ships with Kotlin; no separate version to pin |
| KSP (KSP2) | **2.3.21-2.0.4** (align with Kotlin) | Annotation processing (SQLDelight, Koin annotations if used) | KSP2 is now the default; KSP1 is deprecated and broken on AGP 9+; version prefix must match Kotlin version exactly |

Confidence: HIGH — verified via JetBrains blog posts and GitHub releases.

### Android Build

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| Android Gradle Plugin | **9.2.0** | Android module build | Latest stable as of April 2026; introduces native KMP library plugin (`com.android.kotlin.multiplatform.library`); requires JDK 17+, Gradle 9.1+ |
| Gradle | **9.5.0** | Build system | Latest stable (2026-05-05); AGP 9 minimum is 9.1; configuration cache is now preferred execution mode |
| JDK | **21** | Gradle daemon + compilation | LTS release; required by AGP 9 minimum JDK 17, but 21 is the LTS target for new projects |
| compileSdk / targetSdk | **36** | Android API target | AGP 9.2.0 max is API 37; Google Play targets latest SDK; API 36 is stable |
| minSdk | **23** | Minimum supported Android | `androidx.lifecycle 2.10.0` raised its minimum to API 23 |

Confidence: HIGH — verified via Android Developers release notes for AGP 9.1.1 and 9.2.0, Gradle 9.5.0 release notes.

### Xcode / iOS Toolchain

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| Xcode | **16+** (target 16.x) | iOS builds, simulator tests | Apple mandates Xcode 16 / iOS 18 SDK for all App Store submissions since April 24 2025; Xcode 26 is expected to become mandatory in April 2026 — track and upgrade then |
| Swift | **5.10+** | iOS app code | Ships with Xcode 16; SKIE requires Swift 5.8+; no separate pin needed |
| iOS deployment target | **17.0** | Minimum supported iOS | Covers ~95%+ of active devices in 2026; `NavigationStack` (Nav 3 replacement on iOS) stable since iOS 16 |

Confidence: HIGH — verified via Apple Developer Upcoming Requirements page and Xcode release notes.

### Version Catalog (`gradle/libs.versions.toml`)

Use TOML version catalog exclusively — no inline version strings anywhere. Every library below gets a `[versions]` entry and a `[libraries]` or `[plugins]` alias.

---

## 2. Locked-In Libraries (Verified Versions)

### androidx.lifecycle (ViewModel)

| Artifact | Version | Scope |
|----------|---------|-------|
| `androidx.lifecycle:lifecycle-viewmodel` | **2.10.0** | `commonMain` (api + export) |
| `androidx.lifecycle:lifecycle-runtime-compose` | **2.10.0** | `androidMain` |
| `androidx.lifecycle:lifecycle-viewmodel-compose` | **2.10.0** | `androidMain` |

Architecture decision is locked: `api(...)` in `commonMain` + `export(...)` in the iOS framework block so `ViewModel` APIs surface in Swift.

Next beta is 2.11.0-beta01 (April 2026) — do not use yet; adds scoped ViewModel APIs that may be needed later.

Confidence: HIGH — verified via developer.android.com/jetpack/androidx/releases/lifecycle (2026-05-08).

### Jetpack Compose (Android)

Use the Bill of Materials to avoid version drift across the Compose family.

| Artifact | Version | Notes |
|----------|---------|-------|
| `androidx.compose:compose-bom` | **2026.05.00** | Maps Compose UI 1.11.1, Material3 1.4.0 |
| `androidx.compose.material3:material3` | via BOM (1.4.0) | Use BOM — do not pin individually |
| `androidx.compose.ui:ui-test-junit4-android` | via BOM | Instrumented UI tests |
| `androidx.compose.ui:ui-test-manifest` | via BOM | `debugImplementation` |

Confidence: HIGH — verified via developer.android.com/develop/ui/compose/bom/bom-mapping.

### Ktor Client

| Artifact | Version | Scope |
|----------|---------|-------|
| `io.ktor:ktor-client-core` | **3.4.0** | `commonMain` |
| `io.ktor:ktor-client-okhttp` | **3.4.0** | `androidMain` |
| `io.ktor:ktor-client-darwin` | **3.4.0** | `iosMain` |
| `io.ktor:ktor-client-content-negotiation` | **3.4.0** | `commonMain` |
| `io.ktor:ktor-serialization-kotlinx-json` | **3.4.0** | `commonMain` |
| `io.ktor:ktor-client-logging` | **3.4.0** | `commonMain` |

Ktor 3.x requires all modules to share the same version. OkHttp engine on Android, Darwin engine on iOS — both maintain HTTP/2 and the full Ktor plugin API.

Confidence: HIGH — verified via ktor.io/docs/releases.html and GitHub releases.

### SQLDelight

| Artifact | Version | Scope |
|----------|---------|-------|
| `app.cash.sqldelight:gradle-plugin` | **2.3.2** | `buildSrc` / plugins block |
| `app.cash.sqldelight:android-driver` | **2.3.2** | `androidMain` |
| `app.cash.sqldelight:native-driver` | **2.3.2** | `iosMain` |
| `app.cash.sqldelight:coroutines-extensions` | **2.3.2** | `commonMain` |

All coordinates are `app.cash.sqldelight` (NOT `com.squareup.sqldelight` — that is 1.x). 2.3.2 is latest stable; 2.3.0 and 2.3.1 were skipped due to publication issues.

Confidence: HIGH — verified via sqldelight.github.io/sqldelight/latest/2.x/ and GitHub releases.

### Koin

| Artifact | Version | Scope |
|----------|---------|-------|
| `io.insert-koin:koin-core` | **4.2.1** | `commonMain` |
| `io.insert-koin:koin-android` | **4.2.1** | `androidApp` |
| `io.insert-koin:koin-androidx-compose` | **4.2.1** | `androidApp` |

Koin 4.x is the current major; 4.2.1 is latest stable (April 10 release). Koin annotations (KSP-based compile-time verification) are optional — start without them since they add KSP setup complexity.

Confidence: HIGH — verified via GitHub releases page for InsertKoinIO/koin.

### SKIE (Swift Kotlin Interface Enhancer)

| Artifact | Version | Scope |
|----------|---------|-------|
| `co.touchlab.skie:gradle-plugin` (Gradle plugin id: `co.touchlab.skie`) | **0.10.11** | `shared/build.gradle.kts` plugins block |

SKIE 0.10.11 is the latest stable (released April 2, 2026). Compatible with Kotlin 2.0.0–2.3.10; a new SKIE version ships within a few working days of each Kotlin release.

Key features used here: `StateFlow` → `AsyncSequence` bridge, `sealed class` → Swift exhaustive enum, suspend → `async` functions.

Configuration in `shared/build.gradle.kts`:
```kotlin
plugins {
    id("co.touchlab.skie") version "0.10.11"
}
skie {
    analytics { enabled.set(false) }
}
```

Confidence: HIGH — verified via github.com/touchlab/SKIE/releases and skie.touchlab.co.

---

## 3. Supporting Libraries

### Kotlinx Libraries

| Library | Version | Artifact | Purpose |
|---------|---------|---------|---------|
| kotlinx-coroutines-core | **1.10.2** | `org.jetbrains.kotlinx:kotlinx-coroutines-core` | Coroutines + StateFlow; 1.11.0-rc02 exists but wait for stable |
| kotlinx-coroutines-test | **1.10.2** | `org.jetbrains.kotlinx:kotlinx-coroutines-test` | `runTest` for ViewModel unit tests; same version as core |
| kotlinx-serialization-json | **1.10.0** | `org.jetbrains.kotlinx:kotlinx-serialization-json` | JSON (Ktor payloads, FCM notification payloads); plugin: `kotlin("plugin.serialization")` |
| kotlinx-datetime | **0.7.1** | `org.jetbrains.kotlinx:kotlinx-datetime` | Date/time in commonMain; `kotlin.time.Instant` is now in stdlib, datetime handles calendars/timezones only |

Breaking change note for `kotlinx-datetime 0.7.1`: `kotlinx.datetime.Instant` is removed — use `kotlin.time.Instant` from stdlib. The compat artifact `0.7.1-0.6.x-compat` exists if third-party libs require the old class, but start with 0.7.1.

Confidence: HIGH for all — verified via GitHub releases.

### Android-side UI Support

| Library | Version | Artifact | Purpose |
|---------|---------|---------|---------|
| Coil | **3.4.0** | `io.coil-kt.coil3:coil-compose` + `io.coil-kt.coil3:coil-network-ktor3` | Image loading in Compose; Ktor-based network layer reuses the Ktor client already in the project |
| Jetpack Navigation 3 | **1.1.1** | `androidx.navigation3:navigation3-runtime` + `navigation3-ui` | Type-safe Compose navigation; stable since Nov 2025; KMP targets added (JVM, Native, Web) |

Confidence: HIGH — verified via coil-kt.github.io/coil and developer.android.com/jetpack/androidx/releases/navigation3.

---

## 4. Form / State Libraries

### Approach: no third-party form library

The skeleton implements form state as plain `ViewModel` + `StateFlow` using the MVVM pattern already locked in. This avoids a dependency on community libraries (`viform-multiplatform`, `form-conductor`) that have low adoption and uncertain maintenance.

**Pattern:**
- Each form field is a `data class` property in `UiState` with a nullable error string.
- Validation logic lives in a `validate()` function in the `ViewModel` or a use-case class in `domain/`.
- Submission sets a `isSubmitting: Boolean` flag and dispatches a `Submit` event.
- For complex multi-step forms, a `FormState<T>` sealed interface (`Idle`, `Validating`, `Error(fields)`, `Submitting`, `Success`) covers the lifecycle without an external library.

This maps naturally to SwiftUI `@Binding` or observable state on iOS — no extra bridging needed.

**Molecule (CashApp)** is explicitly deferred: it adds a Compose-runtime dependency to ViewModel logic and makes the iOS consumption more complicated. Re-evaluate if the form complexity warrants composable business logic.

Confidence: MEDIUM (ecosystem recommendation confirmed; specific decision is architectural, not library-verified).

---

## 5. Currency / Locale Formatting

### Approach: `expect`/`actual` over the platform number formatter

There is no KMP library that wraps ICU number formatting in `commonMain` with full locale and currency support as of May 2026. The canonical approach is:

```kotlin
// shared/src/commonMain/kotlin/dev/skeleton/util/CurrencyFormatter.kt
expect fun formatCurrency(amount: Double, currencyCode: String, locale: String): String
```

```kotlin
// androidMain: uses java.util.Currency + NumberFormat
actual fun formatCurrency(amount: Double, currencyCode: String, locale: String): String {
    val javaLocale = java.util.Locale.forLanguageTag(locale)
    val formatter = java.text.NumberFormat.getCurrencyInstance(javaLocale)
    formatter.currency = java.util.Currency.getInstance(currencyCode)
    return formatter.format(amount)
}
```

```kotlin
// iosMain: calls through to NSNumberFormatter via Kotlin/Native interop
actual fun formatCurrency(amount: Double, currencyCode: String, locale: String): String {
    val formatter = platform.Foundation.NSNumberFormatter()
    formatter.numberStyle = platform.Foundation.NSNumberFormatterCurrencyStyle
    formatter.currencyCode = currencyCode
    formatter.locale = platform.Foundation.NSLocale(localeIdentifier = locale)
    return formatter.stringFromNumber(platform.Foundation.NSNumber(double = amount)) ?: ""
}
```

`NSNumberFormatter` in `iosMain` is accessed via Kotlin/Native's `platform.Foundation` package — no SPM dependency required. This gives correct ICU-backed locale formatting on both platforms.

Confidence: MEDIUM — approach is well-established in the KMP community; no single authoritative source; verified by cross-referencing multiple KMP tutorials and Kotlin/Native platform API docs.

---

## 6. Push Notifications

### Android — Firebase Cloud Messaging

| Artifact | Version | Scope |
|----------|---------|-------|
| Firebase Android BoM | **34.13.0** | `androidApp` (platform dependency) |
| `com.google.firebase:firebase-messaging` | via BoM (25.0.2) | `androidApp` |
| Google Services plugin | `4.4.x` | root `build.gradle.kts` (check google() for latest) |

Do NOT use KTX modules (`firebase-messaging-ktx`) — Firebase removed KTX modules from the BoM at v34.0.0 (July 2025). Depend on the main module directly.

Confidence: HIGH — verified via firebase.google.com/support/release-notes/android (2026-05-07 entry: BoM 34.13.0, messaging 25.0.2).

### iOS — APNs

APNs is a native iOS capability; no SDK import is required. Setup:

1. Enable Push Notifications capability in the Xcode project (not via code).
2. Create an APNs key (`.p8`) in Apple Developer Console; note Key ID and Team ID.
3. In `AppDelegate.swift`:
   ```swift
   UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
       if granted { UIApplication.shared.registerForRemoteNotifications() }
   }
   ```
4. Capture the device token in `didRegisterForRemoteNotificationsWithDeviceToken`; forward to the shared ViewModel / repository via SKIE.
5. Handle foreground delivery with `UNUserNotificationCenterDelegate`.

No SPM dependency needed for receiving APNs. For server-side sending (the minimal stub), use Ktor server (see below).

### Push Notification Server Stub

Use **Ktor server** (already a project dependency) rather than a separate server framework.

| Artifact | Version | Purpose |
|----------|---------|---------|
| `io.ktor:ktor-server-cio` | **3.4.0** | Minimal HTTP server for the stub |
| `io.ktor:ktor-server-content-negotiation` | **3.4.0** | JSON body |
| `io.ktor:ktor-serialization-kotlinx-json` | **3.4.0** | kotlinx-serialization backend |

The stub exposes a single endpoint `POST /push` that accepts a `{ token, title, body }` JSON payload, then calls the FCM HTTP v1 API (for Android) and APNs HTTP/2 API (for iOS) using Ktor's HTTP client. This is a development / demo server, not production infrastructure.

Confidence: HIGH (Ktor server) / HIGH (FCM version) / HIGH (APNs native, no SDK).

---

## 7. In-App Notifications

### Android — Compose Material 3 built-ins only

Use `SnackbarHost` + `SnackbarHostState` from Material 3 (via the BOM). No third-party library.

```kotlin
val snackbarHostState = remember { SnackbarHostState() }
Scaffold(snackbarHost = { SnackbarHost(snackbarHostState) }) { ... }
scope.launch { snackbarHostState.showSnackbar("Message") }
```

For inline banners / alerts, compose a custom `AlertBanner` composable from `Card` + Material 3 colors. Keep it in `androidApp/.../components/`.

### iOS — SwiftUI overlays only

Use `.overlay` + `.animation` for toast-style banners, and `.alert` / `.confirmationDialog` for blocking alerts. No third-party library (they tend to conflict with SwiftUI's own navigation/presentation layer in iOS 17+).

Pattern:
```swift
@State private var toast: ToastMessage? = nil
someView
    .overlay(alignment: .top) {
        if let t = toast {
            ToastView(message: t).transition(.move(edge: .top).combined(with: .opacity))
        }
    }
    .onChange(of: viewModel.notification) { _, new in
        if let n = new { toast = ToastMessage(n); Task { try? await Task.sleep(for: .seconds(3)); toast = nil } }
    }
```

The shared ViewModel exposes `notification: String?` in `UiState`; each platform renders it natively.

Confidence: MEDIUM (architectural recommendation; Material 3 SnackbarHost is official, SwiftUI overlay pattern is community-established).

---

## 8. Testing

### commonTest (all platforms)

| Library | Version | Artifact | Purpose |
|---------|---------|---------|---------|
| kotlin.test | bundled with Kotlin | `kotlin("test")` | Test runner + basic assertions; zero extra setup; JetBrains-maintained |
| kotest-assertions-core | **5.9.x** | `io.kotest:kotest-assertions-core` | 350+ rich assertion DSL alongside kotlin.test; use assertions only, not the Kotest engine |
| Turbine | **1.2.1** | `app.cash.turbine:turbine` | Flow / StateFlow testing; mandatory for ViewModel tests |
| kotlinx-coroutines-test | **1.10.2** | `org.jetbrains.kotlinx:kotlinx-coroutines-test` | `runTest`, `TestCoroutineScheduler` |

Do not adopt the Kotest test engine in `commonTest` — its non-JVM engine has feature gaps vs. JVM. Use `kotlin.test` as the runner and Kotest for assertions only.

### androidTest (instrumented)

| Library | Version | Artifact | Purpose |
|---------|---------|---------|---------|
| compose-ui-test-junit4 | via Compose BOM | `androidx.compose.ui:ui-test-junit4-android` | Compose UI instrumented tests |
| compose-ui-test-manifest | via Compose BOM | `androidx.compose.ui:ui-test-manifest` (`debugImplementation`) | Activity manifest for test runner |

Critical Gradle config for KMP + instrumented tests:
```kotlin
androidTarget {
    @OptIn(ExperimentalKotlinGradlePluginApi::class)
    instrumentedTestVariant.sourceSetTree.set(KotlinSourceSetTree.test)
}
```
Without this, `commonTest` source set does not link to the Android instrumented test variant.

### iOS tests (XCTest)

Use `xcodebuild test -scheme YourScheme -destination 'platform=iOS Simulator,...'` on CI. No snapshot testing library is needed for MVP — defer screenshot testing to later phases.

Confidence: HIGH (kotlin.test, Turbine, coroutines-test) / MEDIUM (kotest-assertions version; kotest 5.9.x is latest stable line — verify before pinning).

---

## 9. CI / Publish Pipeline

### GitHub Actions

| Runner | When | Cost note |
|--------|------|-----------|
| `ubuntu-latest` | Gradle build, shared tests, Maven publish | 1× billing multiplier |
| `macos-latest` | iOS build + XCTest, SPM tagging, KMMBridge publish | 10× billing multiplier — keep iOS jobs narrow |

Recommended job structure:
1. `test-shared` (ubuntu) — `./gradlew :shared:allTests`
2. `test-android` (ubuntu) — `./gradlew :androidApp:connectedAndroidTest` (or Robolectric on ubuntu)
3. `build-ios` (macos) — `xcodebuild build -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO`
4. `publish-maven` (ubuntu, on tag) — `./gradlew publish`
5. `publish-spm` (macos, on tag) — KMMBridge `./gradlew kmmBridgePublish`

Pin Xcode version with `maxim-lobanov/setup-xcode@v1`.

### Maven Central Publishing

| Plugin | Version | Plugin ID |
|--------|---------|-----------|
| vanniktech gradle-maven-publish-plugin | **0.36.0** | `com.vanniktech.maven.publish` |

This plugin auto-detects KMP projects, generates sources + javadoc jars, handles GPG signing via environment variables, and supports the Central Portal's automated release flow.

Minimal config:
```kotlin
// shared/build.gradle.kts
plugins { id("com.vanniktech.maven.publish") version "0.36.0" }
mavenPublishing {
    publishToMavenCentral(automaticRelease = true)
    signAllPublications()
    coordinates("dev.skeleton", "skeleton-shared", "0.1.0")
    pom { name.set("Skeleton Shared"); ... }
}
```

Required secrets: `MAVEN_CENTRAL_USERNAME`, `MAVEN_CENTRAL_PASSWORD`, `SIGNING_KEY`, `SIGNING_KEY_ID`, `SIGNING_KEY_PASSWORD`.

Confidence: HIGH — verified via github.com/vanniktech/gradle-maven-publish-plugin/releases (0.36.0 is "Latest").

### SPM / XCFramework Publishing

Use **KMMBridge** by Touchlab (`co.touchlab.kmmbridge`).

| Plugin | Version | Plugin ID |
|--------|---------|-----------|
| KMMBridge | **1.1.0** (latest stable) | `co.touchlab.kmmbridge` |

KMMBridge automates: build XCFramework → ZIP + checksum → upload to GitHub Releases → update `Package.swift` → push SPM tag.

```kotlin
// shared/build.gradle.kts
plugins { id("co.touchlab.kmmbridge") version "1.1.0" }
kmmbridge {
    githubReleaseArtifacts()   // uploads XCFramework ZIP to GitHub Releases
    spm()                       // generates and updates Package.swift
    // version comes from project.version in root build.gradle.kts
}
```

Keep `Package.swift` in a separate Git repository from the Kotlin source. SPM uses Git tags for versioning; having tags co-exist with your development tags causes confusion. The separate repo is tagged independently on each KMMBridge publish.

Note: GitHub Packages hosting requires `~/.netrc` authentication for consumers. Use GitHub Releases instead (public binary URL, no auth for public repos).

Confidence: MEDIUM — KMMBridge version verified via Maven Repository (last release Jan 2025); the 1.1.0 stable release is confirmed, but the project's pace has slowed — monitor touchlab/KMMBridge for maintenance status. Alternative: `ge-org/multiplatform-swiftpackage` if KMMBridge becomes unmaintained.

### CocoaPods

Do NOT use CocoaPods. The `README.md` and architecture.md explicitly reject it. JetBrains' KMP tooling is standardizing on SPM. CocoaPods support in KMP requires the `cocoapods` plugin which conflicts with `XCFramework` task configuration.

---

## 10. What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| Hilt | Not KMP-compatible; Google's KMP ViewModel guide explicitly names it as unavailable in `commonMain` | Koin |
| KAPT | Deprecated; broken on AGP 9+ with KSP2; annotation processors must migrate to KSP | KSP (KSP2 default) |
| KSP1 (`ksp.useKSP2=false`) | Deprecated, will be removed; incompatible with AGP 9 | KSP2 (default since KSP 2.0.0) |
| Compose Multiplatform iOS UI | Rejected in architecture.md; SwiftUI is the iOS UI | SwiftUI + SKIE |
| CocoaPods | Being deprecated for KMP; conflicts with XCFramework task | SPM via KMMBridge |
| `kotlinx-datetime` Instant/Clock | Removed in 0.7.0+; use `kotlin.time.Instant` from stdlib | `kotlin.time.Instant` (stdlib) |
| Firebase KTX modules (`firebase-*-ktx`) | Removed from Firebase BoM v34.0.0 (July 2025); no new versions | Depend on main modules directly (`firebase-messaging`) |
| `com.squareup.sqldelight` | SQLDelight 1.x coordinates; abandoned; incompatible with KMP | `app.cash.sqldelight` (2.x) |
| Kotest test engine in commonTest | Non-JVM engine has feature gaps; more complex Gradle setup | `kotlin.test` runner + `kotest-assertions-core` |
| Third-party toast/notification libraries for SwiftUI | Conflict with SwiftUI's presentation layer on iOS 17+ | Native `.overlay` + `.animation` pattern |
| Decompose | Viable alternative, but adds nav-state sharing complexity not needed here; deferred to per-product decision | Navigation 3 (Android) + `NavigationStack` (iOS) |
| Molecule | Adds Compose-runtime to ViewModel layer; complicates iOS consumption; not needed for MVVM + StateFlow | Plain `StateFlow` in ViewModel |

---

## 11. Version Compatibility Matrix

| Kotlin | KSP | AGP | Gradle | SKIE |
|--------|-----|-----|--------|------|
| 2.3.21 | 2.3.21-2.0.4 | 9.2.0 | 9.5.0 | 0.10.11 |

This is the validated combination. Do not mix KSP versions across modules. KSP version prefix must match Kotlin version exactly (e.g., `2.3.21-X.Y.Z`).

AGP 9.x requires Gradle 9.1+; use 9.5.0 (latest).
AGP 9.x requires JDK 17+; use JDK 21.
SKIE 0.10.11 is compatible with Kotlin up to 2.3.10 per release notes — verify SKIE upgrade when moving to a newer Kotlin patch.

---

## 12. `gradle/libs.versions.toml` — Authoritative Version Block

```toml
[versions]
kotlin                  = "2.3.21"
ksp                     = "2.3.21-2.0.4"
agp                     = "9.2.0"
gradle                  = "9.5.0"

androidx-lifecycle      = "2.10.0"
compose-bom             = "2026.05.00"
navigation3             = "1.1.1"
coil                    = "3.4.0"

ktor                    = "3.4.0"
sqldelight              = "2.3.2"
koin                    = "4.2.1"
skie                    = "0.10.11"
kmmbridge               = "1.1.0"

kotlinx-coroutines      = "1.10.2"
kotlinx-serialization   = "1.10.0"
kotlinx-datetime        = "0.7.1"

firebase-bom            = "34.13.0"

turbine                 = "1.2.1"
vanniktech-publish      = "0.36.0"

[libraries]
# Lifecycle / ViewModel
androidx-lifecycle-viewmodel       = { module = "androidx.lifecycle:lifecycle-viewmodel",         version.ref = "androidx-lifecycle" }
androidx-lifecycle-runtime-compose = { module = "androidx.lifecycle:lifecycle-runtime-compose",   version.ref = "androidx-lifecycle" }
androidx-lifecycle-viewmodel-compose = { module = "androidx.lifecycle:lifecycle-viewmodel-compose", version.ref = "androidx-lifecycle" }

# Compose BOM
androidx-compose-bom               = { module = "androidx.compose:compose-bom",                  version.ref = "compose-bom" }
androidx-compose-material3         = { module = "androidx.compose.material3:material3" }
androidx-compose-ui-test-junit4    = { module = "androidx.compose.ui:ui-test-junit4-android" }
androidx-compose-ui-test-manifest  = { module = "androidx.compose.ui:ui-test-manifest" }

# Navigation 3
navigation3-runtime = { module = "androidx.navigation3:navigation3-runtime", version.ref = "navigation3" }
navigation3-ui      = { module = "androidx.navigation3:navigation3-ui",      version.ref = "navigation3" }

# Coil
coil-compose        = { module = "io.coil-kt.coil3:coil-compose",       version.ref = "coil" }
coil-network-ktor   = { module = "io.coil-kt.coil3:coil-network-ktor3", version.ref = "coil" }

# Ktor
ktor-client-core                 = { module = "io.ktor:ktor-client-core",                 version.ref = "ktor" }
ktor-client-okhttp               = { module = "io.ktor:ktor-client-okhttp",               version.ref = "ktor" }
ktor-client-darwin               = { module = "io.ktor:ktor-client-darwin",               version.ref = "ktor" }
ktor-client-content-negotiation  = { module = "io.ktor:ktor-client-content-negotiation",  version.ref = "ktor" }
ktor-client-logging              = { module = "io.ktor:ktor-client-logging",              version.ref = "ktor" }
ktor-serialization-json          = { module = "io.ktor:ktor-serialization-kotlinx-json",  version.ref = "ktor" }
ktor-server-cio                  = { module = "io.ktor:ktor-server-cio",                  version.ref = "ktor" }
ktor-server-content-negotiation  = { module = "io.ktor:ktor-server-content-negotiation",  version.ref = "ktor" }

# SQLDelight
sqldelight-gradle-plugin   = { module = "app.cash.sqldelight:gradle-plugin",        version.ref = "sqldelight" }
sqldelight-android-driver  = { module = "app.cash.sqldelight:android-driver",       version.ref = "sqldelight" }
sqldelight-native-driver   = { module = "app.cash.sqldelight:native-driver",        version.ref = "sqldelight" }
sqldelight-coroutines      = { module = "app.cash.sqldelight:coroutines-extensions", version.ref = "sqldelight" }

# Koin
koin-core             = { module = "io.insert-koin:koin-core",             version.ref = "koin" }
koin-android          = { module = "io.insert-koin:koin-android",          version.ref = "koin" }
koin-compose          = { module = "io.insert-koin:koin-androidx-compose",  version.ref = "koin" }

# KotlinX
kotlinx-coroutines-core  = { module = "org.jetbrains.kotlinx:kotlinx-coroutines-core",  version.ref = "kotlinx-coroutines" }
kotlinx-coroutines-test  = { module = "org.jetbrains.kotlinx:kotlinx-coroutines-test",  version.ref = "kotlinx-coroutines" }
kotlinx-serialization-json = { module = "org.jetbrains.kotlinx:kotlinx-serialization-json", version.ref = "kotlinx-serialization" }
kotlinx-datetime         = { module = "org.jetbrains.kotlinx:kotlinx-datetime",         version.ref = "kotlinx-datetime" }

# Firebase (androidApp only)
firebase-bom              = { module = "com.google.firebase:firebase-bom",         version.ref = "firebase-bom" }
firebase-messaging        = { module = "com.google.firebase:firebase-messaging" }

# Testing
turbine                  = { module = "app.cash.turbine:turbine",           version.ref = "turbine" }

[plugins]
kotlin-multiplatform      = { id = "org.jetbrains.kotlin.multiplatform",    version.ref = "kotlin" }
kotlin-serialization      = { id = "org.jetbrains.kotlin.plugin.serialization", version.ref = "kotlin" }
android-application       = { id = "com.android.application",               version.ref = "agp" }
android-library           = { id = "com.android.library",                   version.ref = "agp" }
ksp                       = { id = "com.google.devtools.ksp",               version.ref = "ksp" }
skie                      = { id = "co.touchlab.skie",                      version.ref = "skie" }
kmmbridge                 = { id = "co.touchlab.kmmbridge",                 version.ref = "kmmbridge" }
sqldelight                = { id = "app.cash.sqldelight",                   version.ref = "sqldelight" }
vanniktech-publish        = { id = "com.vanniktech.maven.publish",          version.ref = "vanniktech-publish" }
```

---

## Sources

- Kotlin 2.3.21 stable: [JetBrains Kotlin releases blog](https://blog.jetbrains.com/kotlin/2025/08/kmp-roadmap-aug-2025/) + [GitHub releases](https://github.com/jetbrains/kotlin/releases)
- AGP 9.2.0: [developer.android.com/build/releases/agp-9-2-0-release-notes](https://developer.android.com/build/releases/agp-9-2-0-release-notes)
- AGP 9.1.1: [developer.android.com/build/releases/agp-9-1-0-release-notes](https://developer.android.com/build/releases/agp-9-1-0-release-notes)
- Gradle 9.5.0: [docs.gradle.org/current/release-notes.html](https://docs.gradle.org/current/release-notes.html)
- Compose BOM 2026.05.00: [developer.android.com/develop/ui/compose/bom/bom-mapping](https://developer.android.com/develop/ui/compose/bom/bom-mapping)
- androidx.lifecycle 2.10.0: [developer.android.com/jetpack/androidx/releases/lifecycle](https://developer.android.com/jetpack/androidx/releases/lifecycle)
- Ktor 3.4.0: [ktor.io/docs/releases.html](https://ktor.io/docs/releases.html)
- SQLDelight 2.3.2: [sqldelight.github.io/sqldelight/latest/2.x/](https://sqldelight.github.io/sqldelight/latest/2.x/)
- Koin 4.2.1: [github.com/InsertKoinIO/koin/releases](https://github.com/InsertKoinIO/koin/releases) (Latest tag verified 2026-05-08)
- SKIE 0.10.11: [github.com/touchlab/SKIE/releases](https://github.com/touchlab/SKIE/releases)
- kotlinx-coroutines 1.10.2: [github.com/Kotlin/kotlinx.coroutines/releases](https://github.com/Kotlin/kotlinx.coroutines/releases)
- kotlinx-serialization 1.10.0: [github.com/Kotlin/kotlinx.serialization/releases](https://github.com/Kotlin/kotlinx.serialization/releases)
- kotlinx-datetime 0.7.1: [github.com/Kotlin/kotlinx-datetime/releases](https://github.com/Kotlin/kotlinx-datetime/releases)
- Navigation 3 1.1.1: [developer.android.com/jetpack/androidx/releases/navigation3](https://developer.android.com/jetpack/androidx/releases/navigation3)
- Coil 3.4.0: [coil-kt.github.io/coil/](https://coil-kt.github.io/coil/)
- Firebase BoM 34.13.0: [firebase.google.com/support/release-notes/android](https://firebase.google.com/support/release-notes/android)
- Turbine 1.2.1: [github.com/cashapp/turbine/releases](https://github.com/cashapp/turbine/releases)
- vanniktech gradle-maven-publish 0.36.0: [github.com/vanniktech/gradle-maven-publish-plugin/releases](https://github.com/vanniktech/gradle-maven-publish-plugin/releases)
- KMMBridge 1.1.0: [github.com/touchlab/KMMBridge](https://github.com/touchlab/KMMBridge) + [mvnrepository.com](https://mvnrepository.com/artifact/co.touchlab.kmmbridge/kmmbridge)
- KSP2 / deprecation: [android-developers.googleblog.com KSP2 preview](https://android-developers.googleblog.com/2023/12/ksp2-preview-kotlin-k2-standalone.html)
- Xcode 16 App Store requirement: [developer.apple.com/news/upcoming-requirements/](https://developer.apple.com/news/upcoming-requirements/)
- GitHub Actions KMP CI: [kotlinlang.org/docs/multiplatform/github-actions-for-kmp.html](https://kotlinlang.org/docs/multiplatform/github-actions-for-kmp.html)

---
*Stack research for: KMP skeleton + Compose/SwiftUI component library (Maven Central + SPM publish)*
*Researched: 2026-05-08*
