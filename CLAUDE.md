<!-- GSD:project-start source:PROJECT.md -->
## Project

**Skeleton**

A personal Kotlin Multiplatform mobile-app **skeleton template** — shared Kotlin
business logic, native UI on each platform (Jetpack Compose on Android, SwiftUI
on iOS). The deliverable is a clonable foundation **plus** a library of reusable
native UI components (forms, currency-aware amount input, tree sidebar
navigation, notifications) that any new product cloned from this repo can
consume from day one. A showcase app on both platforms exercises every
component end-to-end.

**Core Value:** Cloning this skeleton must give a new product, on day one, a correct
KMP scaffold and the four UI primitives that every mobile product re-implements
badly: forms, amount input, navigation, and notifications.

### Constraints

- **Tech stack**: Kotlin Multiplatform, Jetpack Compose (Android), SwiftUI (iOS), Ktor, SQLDelight, Koin, SKIE — locked by `architecture.md`. No alternatives entertained for v1.
- **Lifecycle version**: `androidx.lifecycle 2.10.0` — KMP-capable `ViewModel` artifact.
- **Design tokens in commonMain** must use only primitives (`Long` for ARGB, `Float`, `Int`) — no Compose or SwiftUI types, since they don't compile on the other side.
- **State ownership**: shared `ViewModel`s own state; both UIs are pure projections. Views never mutate state.
- **Form factor**: phones first; tablets get the same drawer larger. Foldables / desktop are not designed for.
- **Solo + AI-assisted**: planning and execution will run through GSD; phase decomposition should respect that one person (with an agent) is doing the work.
<!-- GSD:project-end -->

<!-- GSD:stack-start source:research/STACK.md -->
## Technology Stack

## 1. Build Tooling
### Kotlin
| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| Kotlin | **2.3.21** | Language + KMP compiler | Current stable; K2 compiler is the default since 2.0; 2.3.x is the active stable line as of May 2026 |
| KMP Gradle plugin | bundled with Kotlin | Multiplatform source-set wiring | Ships with Kotlin; no separate version to pin |
| KSP (KSP2) | **2.3.21-2.0.4** (align with Kotlin) | Annotation processing (SQLDelight, Koin annotations if used) | KSP2 is now the default; KSP1 is deprecated and broken on AGP 9+; version prefix must match Kotlin version exactly |
### Android Build
| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| Android Gradle Plugin | **9.2.0** | Android module build | Latest stable as of April 2026; introduces native KMP library plugin (`com.android.kotlin.multiplatform.library`); requires JDK 17+, Gradle 9.1+ |
| Gradle | **9.5.0** | Build system | Latest stable (2026-05-05); AGP 9 minimum is 9.1; configuration cache is now preferred execution mode |
| JDK | **21** | Gradle daemon + compilation | LTS release; required by AGP 9 minimum JDK 17, but 21 is the LTS target for new projects |
| compileSdk / targetSdk | **36** | Android API target | AGP 9.2.0 max is API 37; Google Play targets latest SDK; API 36 is stable |
| minSdk | **23** | Minimum supported Android | `androidx.lifecycle 2.10.0` raised its minimum to API 23 |
### Xcode / iOS Toolchain
| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| Xcode | **16+** (target 16.x) | iOS builds, simulator tests | Apple mandates Xcode 16 / iOS 18 SDK for all App Store submissions since April 24 2025; Xcode 26 is expected to become mandatory in April 2026 — track and upgrade then |
| Swift | **5.10+** | iOS app code | Ships with Xcode 16; SKIE requires Swift 5.8+; no separate pin needed |
| iOS deployment target | **17.0** | Minimum supported iOS | Covers ~95%+ of active devices in 2026; `NavigationStack` (Nav 3 replacement on iOS) stable since iOS 16 |
### Version Catalog (`gradle/libs.versions.toml`)
## 2. Locked-In Libraries (Verified Versions)
### androidx.lifecycle (ViewModel)
| Artifact | Version | Scope |
|----------|---------|-------|
| `androidx.lifecycle:lifecycle-viewmodel` | **2.10.0** | `commonMain` (api + export) |
| `androidx.lifecycle:lifecycle-runtime-compose` | **2.10.0** | `androidMain` |
| `androidx.lifecycle:lifecycle-viewmodel-compose` | **2.10.0** | `androidMain` |
### Jetpack Compose (Android)
| Artifact | Version | Notes |
|----------|---------|-------|
| `androidx.compose:compose-bom` | **2026.05.00** | Maps Compose UI 1.11.1, Material3 1.4.0 |
| `androidx.compose.material3:material3` | via BOM (1.4.0) | Use BOM — do not pin individually |
| `androidx.compose.ui:ui-test-junit4-android` | via BOM | Instrumented UI tests |
| `androidx.compose.ui:ui-test-manifest` | via BOM | `debugImplementation` |
### Ktor Client
| Artifact | Version | Scope |
|----------|---------|-------|
| `io.ktor:ktor-client-core` | **3.4.0** | `commonMain` |
| `io.ktor:ktor-client-okhttp` | **3.4.0** | `androidMain` |
| `io.ktor:ktor-client-darwin` | **3.4.0** | `iosMain` |
| `io.ktor:ktor-client-content-negotiation` | **3.4.0** | `commonMain` |
| `io.ktor:ktor-serialization-kotlinx-json` | **3.4.0** | `commonMain` |
| `io.ktor:ktor-client-logging` | **3.4.0** | `commonMain` |
### SQLDelight
| Artifact | Version | Scope |
|----------|---------|-------|
| `app.cash.sqldelight:gradle-plugin` | **2.3.2** | `buildSrc` / plugins block |
| `app.cash.sqldelight:android-driver` | **2.3.2** | `androidMain` |
| `app.cash.sqldelight:native-driver` | **2.3.2** | `iosMain` |
| `app.cash.sqldelight:coroutines-extensions` | **2.3.2** | `commonMain` |
### Koin
| Artifact | Version | Scope |
|----------|---------|-------|
| `io.insert-koin:koin-core` | **4.2.1** | `commonMain` |
| `io.insert-koin:koin-android` | **4.2.1** | `androidApp` |
| `io.insert-koin:koin-androidx-compose` | **4.2.1** | `androidApp` |
### SKIE (Swift Kotlin Interface Enhancer)
| Artifact | Version | Scope |
|----------|---------|-------|
| `co.touchlab.skie:gradle-plugin` (Gradle plugin id: `co.touchlab.skie`) | **0.10.11** | `shared/build.gradle.kts` plugins block |
## 3. Supporting Libraries
### Kotlinx Libraries
| Library | Version | Artifact | Purpose |
|---------|---------|---------|---------|
| kotlinx-coroutines-core | **1.10.2** | `org.jetbrains.kotlinx:kotlinx-coroutines-core` | Coroutines + StateFlow; 1.11.0-rc02 exists but wait for stable |
| kotlinx-coroutines-test | **1.10.2** | `org.jetbrains.kotlinx:kotlinx-coroutines-test` | `runTest` for ViewModel unit tests; same version as core |
| kotlinx-serialization-json | **1.10.0** | `org.jetbrains.kotlinx:kotlinx-serialization-json` | JSON (Ktor payloads, FCM notification payloads); plugin: `kotlin("plugin.serialization")` |
| kotlinx-datetime | **0.7.1** | `org.jetbrains.kotlinx:kotlinx-datetime` | Date/time in commonMain; `kotlin.time.Instant` is now in stdlib, datetime handles calendars/timezones only |
### Android-side UI Support
| Library | Version | Artifact | Purpose |
|---------|---------|---------|---------|
| Coil | **3.4.0** | `io.coil-kt.coil3:coil-compose` + `io.coil-kt.coil3:coil-network-ktor3` | Image loading in Compose; Ktor-based network layer reuses the Ktor client already in the project |
| Jetpack Navigation 3 | **1.1.1** | `androidx.navigation3:navigation3-runtime` + `navigation3-ui` | Type-safe Compose navigation; stable since Nov 2025; KMP targets added (JVM, Native, Web) |
## 4. Form / State Libraries
### Approach: no third-party form library
- Each form field is a `data class` property in `UiState` with a nullable error string.
- Validation logic lives in a `validate()` function in the `ViewModel` or a use-case class in `domain/`.
- Submission sets a `isSubmitting: Boolean` flag and dispatches a `Submit` event.
- For complex multi-step forms, a `FormState<T>` sealed interface (`Idle`, `Validating`, `Error(fields)`, `Submitting`, `Success`) covers the lifecycle without an external library.
## 5. Currency / Locale Formatting
### Approach: `expect`/`actual` over the platform number formatter
## 6. Push Notifications
### Android — Firebase Cloud Messaging
| Artifact | Version | Scope |
|----------|---------|-------|
| Firebase Android BoM | **34.13.0** | `androidApp` (platform dependency) |
| `com.google.firebase:firebase-messaging` | via BoM (25.0.2) | `androidApp` |
| Google Services plugin | `4.4.x` | root `build.gradle.kts` (check google() for latest) |
### iOS — APNs
### Push Notification Server Stub
| Artifact | Version | Purpose |
|----------|---------|---------|
| `io.ktor:ktor-server-cio` | **3.4.0** | Minimal HTTP server for the stub |
| `io.ktor:ktor-server-content-negotiation` | **3.4.0** | JSON body |
| `io.ktor:ktor-serialization-kotlinx-json` | **3.4.0** | kotlinx-serialization backend |
## 7. In-App Notifications
### Android — Compose Material 3 built-ins only
### iOS — SwiftUI overlays only
## 8. Testing
### commonTest (all platforms)
| Library | Version | Artifact | Purpose |
|---------|---------|---------|---------|
| kotlin.test | bundled with Kotlin | `kotlin("test")` | Test runner + basic assertions; zero extra setup; JetBrains-maintained |
| kotest-assertions-core | **5.9.x** | `io.kotest:kotest-assertions-core` | 350+ rich assertion DSL alongside kotlin.test; use assertions only, not the Kotest engine |
| Turbine | **1.2.1** | `app.cash.turbine:turbine` | Flow / StateFlow testing; mandatory for ViewModel tests |
| kotlinx-coroutines-test | **1.10.2** | `org.jetbrains.kotlinx:kotlinx-coroutines-test` | `runTest`, `TestCoroutineScheduler` |
### androidTest (instrumented)
| Library | Version | Artifact | Purpose |
|---------|---------|---------|---------|
| compose-ui-test-junit4 | via Compose BOM | `androidx.compose.ui:ui-test-junit4-android` | Compose UI instrumented tests |
| compose-ui-test-manifest | via Compose BOM | `androidx.compose.ui:ui-test-manifest` (`debugImplementation`) | Activity manifest for test runner |
### iOS tests (XCTest)
## 9. CI / Publish Pipeline
### GitHub Actions
| Runner | When | Cost note |
|--------|------|-----------|
| `ubuntu-latest` | Gradle build, shared tests, Maven publish | 1× billing multiplier |
| `macos-latest` | iOS build + XCTest, SPM tagging, KMMBridge publish | 10× billing multiplier — keep iOS jobs narrow |
### Maven Central Publishing
| Plugin | Version | Plugin ID |
|--------|---------|-----------|
| vanniktech gradle-maven-publish-plugin | **0.36.0** | `com.vanniktech.maven.publish` |
### SPM / XCFramework Publishing
| Plugin | Version | Plugin ID |
|--------|---------|-----------|
| KMMBridge | **1.1.0** (latest stable) | `co.touchlab.kmmbridge` |
### CocoaPods
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
## 11. Version Compatibility Matrix
| Kotlin | KSP | AGP | Gradle | SKIE |
|--------|-----|-----|--------|------|
| 2.3.21 | 2.3.21-2.0.4 | 9.2.0 | 9.5.0 | 0.10.11 |
## 12. `gradle/libs.versions.toml` — Authoritative Version Block
# Lifecycle / ViewModel
# Compose BOM
# Navigation 3
# Coil
# Ktor
# SQLDelight
# Koin
# KotlinX
# Firebase (androidApp only)
# Testing
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
<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->
## Conventions

Conventions not yet established. Will populate as patterns emerge during development.
<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->
## Architecture

Architecture not yet mapped. Follow existing patterns found in the codebase.
<!-- GSD:architecture-end -->

<!-- GSD:skills-start source:skills/ -->
## Project Skills

No project skills found. Add skills to any of: `.claude/skills/`, `.agents/skills/`, `.cursor/skills/`, `.github/skills/`, or `.codex/skills/` with a `SKILL.md` index file.
<!-- GSD:skills-end -->

<!-- GSD:workflow-start source:GSD defaults -->
## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:
- `/gsd-quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd-debug` for investigation and bug fixing
- `/gsd-execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->



<!-- GSD:profile-start -->
## Developer Profile

> Profile not yet configured. Run `/gsd-profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->
