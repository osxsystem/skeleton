---
phase: 01-kmp-scaffold-tooling
reviewed: 2026-05-09T00:00:00Z
depth: standard
files_reviewed: 41
files_reviewed_list:
  - .github/workflows/ci.yml
  - androidApp/build.gradle.kts
  - androidApp/src/main/AndroidManifest.xml
  - androidApp/src/main/kotlin/dev/viethung/skeleton/android/MainActivity.kt
  - androidApp/src/main/kotlin/dev/viethung/skeleton/android/SkeletonApp.kt
  - androidApp/src/main/kotlin/dev/viethung/skeleton/android/di/PlatformModule.kt
  - androidApp/src/main/kotlin/dev/viethung/skeleton/android/greeting/GreetingScreen.kt
  - build.gradle.kts
  - gradle.properties
  - gradle/libs.versions.toml
  - gradle/wrapper/gradle-wrapper.properties
  - iosApp/iosApp/App/AppKoinBridge.swift
  - iosApp/iosApp/Common/IosViewModelStoreOwner.swift
  - iosApp/iosApp/ContentView.swift
  - iosApp/iosApp/Greeting/GreetingScreen.swift
  - iosApp/iosApp/iosApp.swift
  - server/build.gradle.kts
  - server/src/main/kotlin/dev/viethung/server/Application.kt
  - server/src/main/kotlin/dev/viethung/server/routing/HealthRouting.kt
  - settings.gradle.kts
  - shared-app/build.gradle.kts
  - shared-app/src/commonMain/kotlin/dev/viethung/showcase/di/AppModule.kt
  - shared-app/src/commonMain/kotlin/dev/viethung/showcase/greeting/GetGreetingUseCase.kt
  - shared-app/src/commonMain/kotlin/dev/viethung/showcase/greeting/GreetingRepository.kt
  - shared-app/src/commonMain/kotlin/dev/viethung/showcase/greeting/GreetingViewModel.kt
  - shared-app/src/commonMain/kotlin/dev/viethung/showcase/greeting/GreetingViewModelFactory.kt
  - shared-app/src/commonTest/kotlin/dev/viethung/showcase/greeting/GreetingViewModelTest.kt
  - shared-components/build.gradle.kts
  - shared-components/src/commonMain/kotlin/dev/viethung/components/ComponentsModule.kt
  - shared-components/src/commonMain/kotlin/dev/viethung/components/SampleUiState.kt
  - shared-components/src/commonMain/kotlin/dev/viethung/components/SkieConventions.kt
  - shared-components/src/commonTest/kotlin/dev/viethung/components/SkieGenericsTest.kt
  - shared-core/build.gradle.kts
  - shared-core/src/androidMain/kotlin/dev/viethung/core/db/DatabaseDriverFactory.android.kt
  - shared-core/src/commonMain/kotlin/dev/viethung/core/db/DatabaseDriverFactory.kt
  - shared-core/src/commonMain/kotlin/dev/viethung/core/di/CoreModule.kt
  - shared-core/src/commonMain/kotlin/dev/viethung/core/network/KtorClient.kt
  - shared-core/src/commonMain/sqldelight/dev/viethung/core/db/Greeting.sq
  - shared-core/src/iosMain/kotlin/dev/viethung/core/db/DatabaseDriverFactory.ios.kt
findings:
  critical: 6
  warning: 8
  info: 5
  total: 19
status: issues_found
---

# Phase 01: Code Review Report

**Reviewed:** 2026-05-09
**Depth:** standard
**Files Reviewed:** 41
**Status:** issues_found

## Summary

Phase 1 ships the KMP scaffold across four modules (`:shared-core`, `:shared-components`, `:shared-app`, `:androidApp`) plus a JVM `:server` stub and an iOS SwiftUI harness. The structural choices are sound: correct `com.android.kotlin.multiplatform.library` plugin, correct `SkeletonKit` baseName, `@StateObject` / `deinit viewModelStore.clear()` in `IosViewModelStoreOwner`, `kotlin.test.Test` throughout, and `@Throws` on the use-case. However, six blockers were found that can cause silent data loss, runtime crashes, or incorrect production behavior at ship time.

---

## Critical Issues

### CR-01: `GreetingRepository` is never registered in Koin — runtime crash on both platforms

**File:** `shared-app/src/commonMain/kotlin/dev/viethung/showcase/di/AppModule.kt:16`

**Issue:** `appModule` registers `GetGreetingUseCase(get())` and `GreetingViewModel(get())`, but `GetGreetingUseCase` depends on `GreetingRepository` (an interface). No binding for `GreetingRepository` exists in `appModule`, in `coreModule`, or in the Android `platformModule`. At runtime, `get<GreetingRepository>()` will throw `org.koin.core.error.NoBeanDefFoundException`, crashing the app the first time `GreetingViewModel` is injected.

The comment says "GreetingRepository actual implementation is provided by the platform Koin module", but `androidApp/di/PlatformModule.kt` only registers `DatabaseDriverFactory` — it does not register any `GreetingRepository` implementation. There is also no `GreetingRepository` implementation anywhere in the reviewed source tree.

**Fix:** Either (a) provide a concrete `GreetingRepository` implementation backed by SQLDelight and register it in `coreModule` or `platformModule`, or (b) add an in-memory implementation to the showcase module and register it:
```kotlin
// In AppModule.kt
factory<GreetingRepository> { GreetingRepositoryImpl(get()) }
```

---

### CR-02: Koin initialized twice on Android — `IllegalStateException` on second launch

**File:** `shared-app/src/commonMain/kotlin/dev/viethung/showcase/di/AppModule.kt:28-32` and `androidApp/src/main/kotlin/dev/viethung/skeleton/android/SkeletonApp.kt:14-18`

**Issue:** `SkeletonApp.onCreate()` calls `startKoin { ... modules(appModule, platformModule) }`. `appModule` includes `coreModule` via `includes(coreModule)` but does NOT call `startKoin` itself. However, `AppModule.kt` also exposes a standalone `fun initKoin()` which calls `startKoin { modules(appModule) }`. On Android this function is not called directly — the duplicate is not triggered today. The risk is indirect: any future code path (e.g., a test helper or misconfigured instrumented test) that calls `initKoin()` after `SkeletonApp.onCreate()` will throw `KoinAlreadyStartedException` and crash. The iOS path calls `AppModuleKt.doInitKoin()` which maps to `initKoin()`, which calls `startKoin` — this is fine for iOS as Koin is not otherwise started. The dual-entrypoint design is fragile.

Additionally, `initKoin()` in `AppModule.kt` starts Koin with only `appModule` and does NOT include `platformModule`. On iOS this means `DatabaseDriverFactory` is never bound when Koin tries to satisfy `get<DatabaseDriverFactory>()` inside `coreModule`, causing the same `NoBeanDefFoundException` at DB access time (related to CR-01 above).

**Fix:** Replace `initKoin()` with a parameter-accepting version that receives platform-specific modules, matching the standard KMP Koin pattern:
```kotlin
fun initKoin(vararg platformModules: Module) {
    startKoin {
        modules(appModule, *platformModules)
    }
}
```
On iOS, call `AppModuleKt.doInitKoin()` after passing the iOS platform module, or provide the iOS `DatabaseDriverFactory` binding inside the `appModule` / `coreModule` using an `expect`/`actual` Koin definition.

---

### CR-03: ViewModel retrieved inside `body` without stable reference — ViewModel recreated on every recomposition

**File:** `iosApp/iosApp/Greeting/GreetingScreen.swift:10-12`

**Issue:** The ViewModel is retrieved via `owner.viewModel(factory: ...)` inside `var body: some View { ... }`. In SwiftUI, `body` is a computed property that is evaluated on every recomposition. `ViewModelProvider(...).get(modelClass:)` will be called on every layout pass. Although `ViewModelStore` deduplicates by type key, each `get()` call still traverses the store, and — more critically — the `vm` local constant is re-created on each recomposition, which means the `.task { vm.loadGreeting(); for await s in vm.state { ... } }` closure captures a different `vm` reference if the view is recomposed before the task finishes. The `for await` loop consuming `vm.state` may be iterating over a different ViewModel instance than the one that received `loadGreeting()`.

**Fix:** Hoist the ViewModel resolution out of `body` into a `@State` or use a dedicated `@StateObject` wrapper that holds the resolved ViewModel:
```swift
struct GreetingScreen: View {
    @StateObject private var owner = IosViewModelStoreOwner()

    private var vm: GreetingViewModel {
        owner.viewModel(factory: GreetingViewModelFactoryKt.greetingViewModelFactory)
    }
    // ...
}
```
This is still computed each access but now tied to a stable `@StateObject` identity. Alternatively, store `vm` in a `@State` variable initialized in `.onAppear` or via `.task(id:)` with a stable ID.

---

### CR-04: Ktor client has no timeout configured — network calls hang indefinitely

**File:** `shared-core/src/commonMain/kotlin/dev/viethung/core/network/KtorClient.kt:10-20`

**Issue:** `createHttpClient()` installs `ContentNegotiation` and `Logging` but sets no `HttpTimeout`. On both Android (OkHttp) and iOS (Darwin), the absence of a timeout means any network call that does not receive a response hangs indefinitely, blocking the `viewModelScope` coroutine. On mobile networks this is a realistic failure mode. The ViewModel will remain in `UiState.Loading` forever with no user-recoverable path.

**Fix:**
```kotlin
import io.ktor.client.plugins.HttpTimeout

fun createHttpClient(): HttpClient = HttpClient {
    install(HttpTimeout) {
        requestTimeoutMillis = 30_000
        connectTimeoutMillis = 10_000
        socketTimeoutMillis  = 30_000
    }
    install(ContentNegotiation) { ... }
    install(Logging) { ... }
}
```

---

### CR-05: `greetingViewModelFactory` uses `UNCHECKED_CAST` from `GlobalContext.get()` — bypasses ViewModel scoping and is type-unsafe

**File:** `shared-app/src/commonMain/kotlin/dev/viethung/showcase/greeting/GreetingViewModelFactory.kt:19-23`

**Issue:** The factory calls `GlobalContext.get().get<GreetingViewModel>()` and casts the result to `T`. Two problems:

1. `koin.get<GreetingViewModel>()` retrieves from the global Koin scope, not from the `ViewModelStore`. This means the ViewModel returned is a Koin-managed singleton/factory instance that is not tied to the `ViewModelStore` lifecycle. When `viewModelStore.clear()` is called in `IosViewModelStoreOwner.deinit`, the Koin-provided ViewModel will not have its `onCleared()` called through the normal `ViewModel` lifecycle, defeating the purpose of `viewModelStore.clear()`.

2. The `@Suppress("UNCHECKED_CAST")` cast from `GreetingViewModel` to `T` will silently succeed for any `T` at the call site — if `owner.viewModel(factory:)` is ever called with a wrong type, the ClassCastException surfaces later, not at the factory.

**Fix:** Resolve from Koin inside the factory but let `ViewModelProvider` own the instance by constructing it directly rather than retrieving a Koin-managed instance:
```kotlin
val greetingViewModelFactory: ViewModelProvider.Factory = object : ViewModelProvider.Factory {
    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: KClass<T>, extras: CreationExtras): T {
        val useCase = GlobalContext.get().get<GetGreetingUseCase>()
        return GreetingViewModel(useCase) as T
    }
}
```
This creates a fresh `GreetingViewModel` owned by the `ViewModelStore`, so `onCleared()` is properly triggered.

---

### CR-06: `LogLevel.HEADERS` in production Ktor client leaks authorization headers in logs

**File:** `shared-core/src/commonMain/kotlin/dev/viethung/core/network/KtorClient.kt:17-19`

**Issue:** The `Logging` plugin is configured with `LogLevel.HEADERS`. This logs all request and response headers, including `Authorization`, `Cookie`, `Set-Cookie`, and any custom bearer tokens, to the platform logger (Logcat on Android, NSLog on iOS). In a shipped app this is a data exposure vulnerability: access tokens, session cookies, and API keys will appear in device logs accessible to other apps with `READ_LOGS` permission (Android) or device console (iOS) and third-party crash reporters.

The inline comment says "downgrade to NONE before production" — but this is not enforced by a build-variant check, and the scaffold as shipped will pass `LogLevel.HEADERS` into any app cloned from this skeleton.

**Fix:** Gate the log level behind a build flag:
```kotlin
install(Logging) {
    level = if (BuildKonfig.DEBUG) LogLevel.HEADERS else LogLevel.NONE
}
```
Or as a minimum, default to `LogLevel.NONE` and document explicitly that callers must opt in during development:
```kotlin
fun createHttpClient(logLevel: LogLevel = LogLevel.NONE): HttpClient = HttpClient {
    install(Logging) { level = logLevel }
    ...
}
```
Passing `LogLevel.HEADERS` must not be the default in a skeleton others will clone.

---

## Warnings

### WR-01: `kotlinx-datetime` is imported in `:shared-core` — violates CLAUDE.md prohibition

**File:** `shared-core/build.gradle.kts:44`

**Issue:** `implementation(libs.kotlinx.datetime)` is declared in `commonMain` dependencies. CLAUDE.md explicitly lists `kotlinx-datetime` Instant/Clock as "NOT to use" (replaced by `kotlin.time.Instant` from stdlib in 0.7.0+). Even if only the timezone/calendar APIs are used, declaring the dependency allows callers to accidentally use the prohibited `Instant` type. No source file in the reviewed tree currently imports `kotlinx-datetime`, making this an unused dependency that also violates project policy.

**Fix:** Remove `implementation(libs.kotlinx.datetime)` from `shared-core/build.gradle.kts` until a calendar/timezone feature is actively needed.

---

### WR-02: Android `SkeletonApp` uses `androidLogger(Level.DEBUG)` in production builds

**File:** `androidApp/src/main/kotlin/dev/viethung/skeleton/android/SkeletonApp.kt:15`

**Issue:** `androidLogger(Level.DEBUG)` emits every Koin resolution, injection, and module load to Logcat at DEBUG level with no build-variant guard. This is appropriate for development but leaks DI graph details in production builds. Koin recommends `Level.ERROR` or `Level.NONE` in release builds.

**Fix:**
```kotlin
androidLogger(if (BuildConfig.DEBUG) Level.DEBUG else Level.ERROR)
```

---

### WR-03: `IosViewModelStoreOwner.deinit` contains a `print` statement — debug artifact in production

**File:** `iosApp/iosApp/Common/IosViewModelStoreOwner.swift:19`

**Issue:** `print("[IosViewModelStoreOwner] deinit cleared store")` will write to the device console in App Store builds. Unlike Android's `Log.d`, Swift `print()` is not stripped by release builds. Any shipped app cloned from this skeleton will log ViewModel lifecycle events to the device console.

**Fix:** Remove the `print` call, or guard it:
```swift
deinit {
    viewModelStore.clear()
    #if DEBUG
    print("[IosViewModelStoreOwner] deinit cleared store")
    #endif
}
```

---

### WR-04: CI `android-build` job does not run `:server` tests

**File:** `.github/workflows/ci.yml:84-90`

**Issue:** The "Run JVM tests" step runs `jvmTest` on the three KMP modules but skips `:server`. The server module has its own test source set (`testImplementation(kotlin("test"))`). A broken server module can be merged without any CI gate catching it.

**Fix:** Add `:server:test` to the JVM test step:
```yaml
./gradlew \
  :shared-core:jvmTest \
  :shared-components:jvmTest \
  :shared-app:jvmTest \
  :server:test \
  --no-daemon
```

---

### WR-05: CI `ios-build` job XCFramework path check uses `WARNING` and `exit 0` — gate is silently bypassed

**File:** `.github/workflows/ci.yml:167-169`

**Issue:** If `build/spm/SkeletonKit.xcframework` and `shared-components/build/XCFrameworks/debug/SkeletonKit.xcframework` are both absent, the step prints a warning and exits 0. This means the XCFramework task could be completely broken (wrong task name, Gradle task failure swallowed) and the CI job still passes green. The same step runs the Gradle build task immediately before, but if `assembleSKIEDebugXCFramework` is not the correct task name it will fail on Gradle (that would be caught), however if the task succeeds but emits to a third path, the path check silently skips, giving a false sense of security.

**Fix:** Change the conditional to a hard failure:
```bash
if [ ! -d "build/spm/SkeletonKit.xcframework" ] && \
   [ ! -d "shared-components/build/XCFrameworks/debug/SkeletonKit.xcframework" ]; then
  echo "ERROR: SkeletonKit.xcframework not found. Fix the build task name or output path."
  exit 1
fi
```

---

### WR-06: `GreetingViewModelTest` uses `expectMostRecentItem()` which can yield a false-green if `loadGreeting()` has not yet emitted

**File:** `shared-app/src/commonTest/kotlin/dev/viethung/showcase/greeting/GreetingViewModelTest.kt:42-44`

**Issue:** After calling `vm.loadGreeting()`, the test calls `expectMostRecentItem()`. In `runTest` with `TestCoroutineScheduler`, coroutines launched with `viewModelScope.launch` (which uses `Dispatchers.Main.immediate` by default) may not have run yet when `expectMostRecentItem()` is called. `expectMostRecentItem()` returns whatever was last emitted without awaiting new emissions — if no new item has been emitted since `awaitItem()` consumed `Loading`, this returns `Loading` again, not `Ready`, and the `assertIs<Ready>` would then fail. The test relies on implicit scheduling that may differ across platforms (JVM vs iOS native coroutine scheduler). Using `awaitItem()` in a loop or `skipItems(1); awaitItem()` is more deterministic.

**Fix:**
```kotlin
vm.loadGreeting()
// Consume the second Loading emitted at the top of loadGreeting()
val s1 = awaitItem()
if (s1 is GreetingViewModel.UiState.Loading) {
    val finalState = awaitItem()
    assertIs<GreetingViewModel.UiState.Ready>(finalState)
    assertEquals("Hello, KMP", finalState.message)
} else {
    assertIs<GreetingViewModel.UiState.Ready>(s1)
}
```
Or use Turbine's `awaitItem()` consistently rather than `expectMostRecentItem()`.

---

### WR-07: `androidApp/build.gradle.kts` hard-codes Compose dependencies by string coordinate — bypasses BOM

**File:** `androidApp/build.gradle.kts:45-47`

**Issue:** Three Compose dependencies are declared as raw string literals:
```
implementation("androidx.compose.ui:ui")
implementation("androidx.compose.ui:ui-tooling-preview")
debugImplementation("androidx.compose.ui:ui-tooling")
```
While BOM version resolution does apply to these (because the BOM is declared as a `platform` dependency), the entries in `libs.versions.toml` have no entries for these three artifacts. If the project later wants to pin or inspect Compose versions, these three artifacts are invisible to the version catalog. Additionally, mixing catalog entries with raw string coordinates is inconsistent and makes version auditing harder.

**Fix:** Add these three to `libs.versions.toml` and replace the string literals with catalog aliases, consistent with every other Compose dependency in the file.

---

### WR-08: `server/build.gradle.kts` pins `logback-classic` as a raw string coordinate outside the version catalog

**File:** `server/build.gradle.kts:21`

**Issue:** `implementation("ch.qos.logback:logback-classic:1.4.14")` is a hard-coded version string not declared in `libs.versions.toml`. This version (1.4.14) is from 2023; Logback 1.5.x has been the stable branch since early 2024. More importantly, bypassing the catalog makes this dependency invisible to any future automated version-bump tooling (Renovate, Dependabot).

**Fix:** Add logback to the version catalog:
```toml
logback = "1.5.18"   # latest stable
logback-classic = { module = "ch.qos.logback:logback-classic", version.ref = "logback" }
```
Then reference it from `server/build.gradle.kts`:
```kotlin
implementation(libs.logback.classic)
```

---

## Info

### IN-01: Redundant `import dev.viethung.core.db.AppDatabase` in `DatabaseDriverFactory.android.kt`

**File:** `shared-core/src/androidMain/kotlin/dev/viethung/core/db/DatabaseDriverFactory.android.kt:6`

**Issue:** `import dev.viethung.core.db.AppDatabase` is in the same package (`dev.viethung.core.db`) and is therefore unnecessary. The same redundant import exists in `DatabaseDriverFactory.ios.kt:5`.

**Fix:** Remove both redundant same-package imports.

---

### IN-02: `GreetingViewModel` sealed interface `UiState` is nested inside `GreetingViewModel` but `SampleUiState` is top-level in `:shared-components` — inconsistent pattern

**File:** `shared-app/src/commonMain/kotlin/dev/viethung/showcase/greeting/GreetingViewModel.kt:14` and `shared-components/src/commonMain/kotlin/dev/viethung/components/SampleUiState.kt:20`

**Issue:** The two modules use different placement conventions for sealed state types: one nests it (`GreetingViewModel.UiState`), the other uses a standalone file (`SampleUiState`). CLAUDE.md states conventions will be established during development — Phase 1 is the opportunity to pick one and follow it consistently before more ViewModels are added in Phase 3.

**Fix:** Decide on one pattern and document it in `CLAUDE.md` under Conventions. The nested pattern (`ViewModel.UiState`) is generally preferred in KMP because it avoids naming collisions when multiple ViewModels are in scope in Swift (`GreetingViewModelUiState` vs a generic `UiState`).

---

### IN-03: `AppKoinBridge.swift` comment references `AppModuleKt.doInitKoin()` but the Kotlin function is named `initKoin` — SKIE name mangling may differ

**File:** `iosApp/iosApp/App/AppKoinBridge.swift:9`

**Issue:** The comment states "SKIE/KMP name mangling maps initKoin → doInitKoin". SKIE does prefix Kotlin top-level functions with `do` to avoid Swift keyword conflicts, but `initKoin` is not a Swift keyword. The actual generated name depends on SKIE version. If the generated name is simply `initKoin()` (no `do` prefix) the call `AppModuleKt.doInitKoin()` will fail to compile. This is a documentation/assumption risk that will surface only when the Xcode project is built in UAT.

**Fix:** Confirm the actual generated Swift symbol after the XCFramework is built (check the generated header or Swift overlay), then update the call and comment to match.

---

### IN-04: `Greeting.sq` seed `INSERT OR IGNORE` runs on every app launch — not idempotent for data changes

**File:** `shared-core/src/commonMain/sqldelight/dev/viethung/core/db/Greeting.sq:7`

**Issue:** The seed row is in the schema file, which means `AppDatabase.Schema.create(driver)` calls it on every fresh install. `INSERT OR IGNORE` prevents a duplicate-key crash on re-open. This is acceptable for Phase 1. However, if the greeting message is later updated (e.g., changed in the `.sq` file), existing installs will not see the update because `INSERT OR IGNORE` silently skips existing rows. This could cause a confusing divergence between fresh installs and upgraded devices.

**Fix:** For Phase 1 this is acceptable. For Phase 2+, replace with a migration script using `INSERT OR REPLACE` or SQLDelight schema migrations, and document that the seed is Phase 1 only.

---

### IN-05: CI `android-build` job has no Gradle configuration-cache flag — `--no-daemon` conflicts with `org.gradle.caching=true`

**File:** `.github/workflows/ci.yml:76-83` and `gradle.properties:4`

**Issue:** `gradle.properties` enables `org.gradle.configuration-cache=true` and `org.gradle.caching=true`. The CI steps pass `--no-daemon`, which is correct for CI, but do not pass `--configuration-cache` explicitly. With `org.gradle.configuration-cache=true` set in `gradle.properties`, the configuration cache is enabled globally and will attempt to read/write a cache. On GitHub Actions runners that do not cache the `.gradle/configuration-cache` directory (it is absent from the `Cache Gradle` step's `path` list), this results in a cache miss on every run — the configuration-cache overhead is incurred with no benefit. This is not a correctness issue but degrades build reliability because a corrupted configuration cache in the writable temp directory can cause `TaskExecutionException`.

**Fix:** Either add `~/.gradle/configuration-cache` to the cache step paths, or pass `--no-configuration-cache` to all Gradle calls in CI until the configuration cache is explicitly validated for this build.

---

_Reviewed: 2026-05-09_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
