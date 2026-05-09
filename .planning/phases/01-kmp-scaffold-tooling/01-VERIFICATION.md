---
phase: 01-kmp-scaffold-tooling
verified: 2026-05-09T00:00:00Z
status: gaps_found
score: 3/5 roadmap success criteria verified
overrides_applied: 0
gaps:
  - truth: "Gradle build exits 0 on a clean machine with no warnings"
    status: failed
    reason: "CR-01 (GreetingRepository never bound in Koin) causes NoBeanDefFoundException at runtime on both platforms. CR-02 (iOS initKoin() does not pass a platform module, so DatabaseDriverFactory is also unbound on iOS). These two defects prevent the Koin DI graph from resolving, meaning any run of the app — including an instrumented build verification — will crash. The Gradle compile step itself may exit 0, but the 'no warnings' clause is also violated by kotlinx-datetime being declared as a dependency in :shared-core despite being prohibited by CLAUDE.md. A compile-green gate with a known runtime crash on first ViewModel injection does not satisfy Success Criterion 1 for a foundation phase."
    artifacts:
      - path: "shared-app/src/commonMain/kotlin/dev/viethung/showcase/di/AppModule.kt"
        issue: "factory { GetGreetingUseCase(get()) } resolves get<GreetingRepository>() at runtime but no Koin binding for GreetingRepository exists anywhere (not in appModule, coreModule, or platformModule). App crashes on first GreetingViewModel injection."
      - path: "shared-app/src/commonMain/kotlin/dev/viethung/showcase/greeting/GreetingViewModelFactory.kt"
        issue: "GlobalContext.get().get<GreetingViewModel>() bypasses the ViewModelStore lifecycle. When viewModelStore.clear() fires in IosViewModelStoreOwner.deinit, the Koin-managed GreetingViewModel does NOT have onCleared() called through the ViewModelStore contract, defeating the SCAF-05 lifecycle guarantee."
      - path: "shared-app/src/commonMain/kotlin/dev/viethung/showcase/di/AppModule.kt"
        issue: "fun initKoin() starts Koin with only modules(appModule). On iOS this means DatabaseDriverFactory (required by coreModule to create AppDatabase) is never bound, causing a second NoBeanDefFoundException at DB access time."
    missing:
      - "Register a concrete GreetingRepository implementation in appModule (or platformModule on each platform)"
      - "Provide a platform-accepting initKoin() variant for iOS: fun initKoin(vararg platformModules: Module)"
      - "Fix GreetingViewModelFactory to construct GreetingViewModel(useCase) directly instead of retrieving a Koin-managed instance"

  - truth: "Xcode builds SkeletonKit.framework and iOS showcase links and runs on simulator; IosViewModelStoreOwner.deinit log fires on navigation pop"
    status: failed
    reason: "The .xcodeproj file was never created — only Swift source files were committed. The iosApp/ directory contains only Swift source files (IosViewModelStoreOwner.swift, GreetingScreen.swift, AppKoinBridge.swift, iosApp.swift, ContentView.swift) with no Xcode project file (.xcodeproj or .xcworkspace). Without the project file, SkeletonKit.xcframework cannot be embedded, ⌘B cannot be run, and the deinit smoke test cannot be performed. This is explicitly recorded as pending in 01-HUMAN-UAT.md with all 7 tests in 'pending' state."
    artifacts:
      - path: "iosApp/"
        issue: "No .xcodeproj file present. Confirmed by find: no *.xcodeproj or *.xcworkspace found anywhere under iosApp/."
    missing:
      - "Create iosApp/iosApp.xcodeproj via Xcode → File → New → Project (iOS App / SwiftUI)"
      - "Set deployment target to iOS 17.0"
      - "Add SkeletonKit.xcframework (Embed & Sign)"
      - "Add -lsqlite3 to Other Linker Flags"
      - "Run and confirm Hello KMP renders on iOS 17 simulator"
      - "Navigate away and confirm '[IosViewModelStoreOwner] deinit cleared store' in console"

  - truth: "A sample ViewModel is resolvable from both Android and iOS Koin entry points"
    status: failed
    reason: "CR-01 (no GreetingRepository binding) means GreetingViewModel is NOT resolvable from either entry point at runtime. The test in GreetingViewModelTest passes only because it bypasses Koin entirely — constructing the ViewModel directly with an inline anonymous GreetingRepository. The SCAF-06 requirement 'sample ViewModel resolvable from both … Koin entry points' specifically refers to Koin resolution, not direct construction."
    artifacts:
      - path: "shared-app/src/commonMain/kotlin/dev/viethung/showcase/di/AppModule.kt"
        issue: "factory { GetGreetingUseCase(get()) } will throw NoBeanDefFoundException(GreetingRepository) at runtime"
    missing:
      - "A concrete GreetingRepository implementation bound in the Koin graph"

  - truth: "The generated SkeletonKit.framework/Headers/ contains no Any? in Flow or sealed-class signatures"
    status: failed
    reason: "The CI SKIE header gate in ci.yml exits 0 (WARNING path, not exit 1) when SkeletonKit.framework/Headers is not found. Because the XCFramework has never been built on CI (no passing run recorded, and Xcode project is absent), this gate silently passes without running. SCAF-11 static verification depends on the XCFramework being built and headers being inspectable. The Kotlin-level commonTest (SkieGenericsTest) verifies the sealed hierarchy compiles correctly, but cannot prove SKIE header output."
    artifacts:
      - path: ".github/workflows/ci.yml"
        issue: "Lines 176-179: if SkeletonKit.framework/Headers is absent, the step prints WARNING and exits 0. This means the SKIE header check is silently bypassed whenever the XCFramework build fails or produces output at an unexpected path."
    missing:
      - "Change the SKIE header gate from exit 0 to exit 1 when headers directory is not found"
      - "Run XCFramework build on CI (requires Xcode project to link against)"

human_verification:
  - test: "Build SkeletonKit XCFramework and inspect ObjC headers for Any?"
    expected: "find SkeletonKit.framework/Headers -name '*.h' | xargs grep -l 'Any?' returns empty"
    why_human: "Requires running ./gradlew :shared-components:assembleSkeletonKitReleaseXCFramework on macOS with Xcode 16 toolchain installed"

  - test: "Xcode project compiles green (⌘B) with SkeletonKit.xcframework embedded"
    expected: "Build succeeds with zero errors in Xcode 16 on iOS 17+ simulator target"
    why_human: "Requires creating the Xcode project, embedding the framework, and running a compile — IDE interaction required"

  - test: "App renders Hello KMP on iOS 17 simulator"
    expected: "GreetingScreen shows 'Hello, KMP' text after successful Koin initialization and SQLDelight DB read"
    why_human: "Requires running simulator; also blocked by CR-01 and CR-02 until Koin DI is fixed"

  - test: "IosViewModelStoreOwner deinit log fires on navigation pop"
    expected: "'[IosViewModelStoreOwner] deinit cleared store' appears in Xcode console when GreetingScreen is popped from NavigationStack"
    why_human: "Runtime behavior that requires the simulator to be running and a second screen to navigate to"

  - test: "Android app assembleDebug and runtime smoke test"
    expected: "App installs, Koin resolves GreetingViewModel, SQLDelight seed row renders 'Hello, KMP'"
    why_human: "Koin crash (CR-01) currently blocks runtime; once fixed, requires emulator/device for final confirmation"

  - test: "CI Android + iOS jobs both pass green on GitHub Actions"
    expected: "Both android-build and ios-build jobs pass on a hello-world commit"
    why_human: "Cannot verify CI pass without a macOS runner and Xcode installation; CI workflow is defined but no successful run is recorded"
---

# Phase 01: KMP Scaffold + Tooling — Verification Report

**Phase Goal:** The multi-module Gradle project and Xcode project compile green on both platforms with the fully locked toolchain; every infrastructure concern (CI, DI, networking stub, persistence stub, SKIE, test harness, iOS lifecycle) is correct before any feature code is written.
**Verified:** 2026-05-09
**Status:** gaps_found
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths (from ROADMAP.md Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|---------|
| SC-1 | `./gradlew :shared-core:build :shared-components:build :shared-app:build :androidApp:assembleDebug` exits 0 with no warnings | ? UNCERTAIN — compile likely passes but runtime DI is broken; kotlinx-datetime warning present | CR-01 (no GreetingRepository binding), CR-02 (iOS DatabaseDriverFactory unbound), kotlinx-datetime prohibited by CLAUDE.md |
| SC-2 | Xcode builds SkeletonKit.framework; iOS app links and runs; IosViewModelStoreOwner.deinit log fires on pop | ✗ FAILED | No .xcodeproj exists; 01-HUMAN-UAT.md shows all 7 tests PENDING |
| SC-3 | CI passes both jobs (Android ubuntu-latest, iOS macos-14 30-min) on hello-world commit | ? UNCERTAIN | CI workflow defined correctly; no passing run recorded; SKIE header gate has silent bypass (exit 0 when headers not found) |
| SC-4 | Sample ViewModel resolvable from both Koin entry points; one commonTest passes on both platforms | ✗ FAILED | GreetingRepository never bound in Koin (CR-01); GreetingViewModelTest passes only because it bypasses Koin entirely |
| SC-5 | SkeletonKit.framework/Headers/ contains no Any?; SQLDelight hello-world query runs on both platforms | ? UNCERTAIN | SKIE header gate silently bypassed in CI when headers not found; commonTest for sealed hierarchy passes; iOS SQLDelight blocked by CR-02 at runtime |

**Score: 0/5 fully verified** (3 uncertain, 2 failed — no SC passes with full confidence)

---

## SCAF Requirements Coverage Scorecard

| Requirement | Description | Status | Evidence |
|-------------|-------------|--------|---------|
| **SCAF-01** | Multi-module Gradle project compiles green: :shared-core, :shared-components, :shared-app, :androidApp build with no warnings | ⚠ PARTIAL | All 4 modules registered in settings.gradle.kts; all apply correct AGP-9 KMP plugin; compile likely passes. Runtime crash due to CR-01 prevents full green. |
| **SCAF-02** | Xcode project compiles SkeletonKit framework; iOS app links and runs | ✗ FAILED | No .xcodeproj file. Swift sources (IosViewModelStoreOwner.swift, GreetingScreen.swift, AppKoinBridge.swift) exist and are architecturally correct. Runtime verification deferred (HUMAN-UAT). |
| **SCAF-03** | All KMP modules apply com.android.kotlin.multiplatform.library | ✓ VERIFIED | shared-core, shared-components, shared-app all use `alias(libs.plugins.android.kmp.library)` which maps to `com.android.kotlin.multiplatform.library` in libs.versions.toml. androidApp correctly uses `android.application`. |
| **SCAF-04** | libs.versions.toml pins Kotlin/KSP/SKIE/AGP with `# Update these four together` comment | ✓ VERIFIED | Comment present as first line of [versions] block; kotlin=2.3.21, ksp=2.3.21-2.0.4, agp=9.2.0, skie=0.10.11 all correct; android-library alias absent; android-kmp-library present. |
| **SCAF-05** | IosViewModelStoreOwner declared @StateObject; deinit clears ViewModelStore and logs deinit message | ⚠ PARTIAL — static correct, runtime unverified | IosViewModelStoreOwner.swift: `@StateObject private var owner = IosViewModelStoreOwner()` in GreetingScreen; deinit calls viewModelStore.clear() and print("[IosViewModelStoreOwner] deinit cleared store"). CR-05: GreetingViewModelFactory uses GlobalContext.get() which bypasses ViewModelStore — the deinit's clear() will NOT call onCleared() on the Koin-managed ViewModel. Runtime smoke test pending (01-HUMAN-UAT.md). |
| **SCAF-06** | Koin DI wires :shared-core modules; sample ViewModel resolvable from both entry points | ✗ FAILED | CR-01: GreetingRepository never bound in Koin. appModule registers factory { GetGreetingUseCase(get()) } which resolves get<GreetingRepository>() at runtime — will throw NoBeanDefFoundException. CR-02: iOS initKoin() starts Koin without platformModule, so DatabaseDriverFactory is also unbound. GreetingViewModelTest bypasses Koin — it does not validate Koin resolvability. |
| **SCAF-07** | Ktor client scaffolded with OkHttp (Android), Darwin (iOS), JSON serialization | ✓ VERIFIED | KtorClient.kt exists with ContentNegotiation + Logging; OkHttp in androidMain; Darwin in iosMain; CoreModule registers single { createHttpClient() }. CR-04 (no HttpTimeout) is a quality defect, not a disqualifier for SCAF-07. Server :health route at port 8080 is present. |
| **SCAF-08** | SQLDelight schema scaffolded with -lsqlite3 linker flag; hello-world query green on both platforms | ⚠ PARTIAL | Static: Greeting.sq exists (CREATE TABLE, INSERT OR IGNORE, selectById, selectAll); NativeSqliteDriver actual in iosMain; linkerOpts.add("-lsqlite3") in shared-core iOS framework block; AndroidSqliteDriver in androidMain. Runtime: Android path requires CR-01 fix first; iOS path requires CR-02 fix first. |
| **SCAF-09** | CI: Android on ubuntu-latest; iOS on macos-14 with timeout-minutes 30; both pass on hello-world | ⚠ PARTIAL | ci.yml correctly defines android-build (ubuntu-latest) and ios-build (macos-14, timeout-minutes:30). iosSimulatorArm64Test is a separate step. No passing CI run is recorded. WR-05: SKIE header gate exits 0 (not 1) when headers directory not found — gate can be silently bypassed. |
| **SCAF-10** | kotlin.test harness; one commonTest passes on both Android and iOS targets | ✓ VERIFIED | GreetingViewModelTest uses `import kotlin.test.Test` (not org.junit.Test); 3 @Test methods; Turbine used for StateFlow testing. SkieGenericsTest has 4 @Test methods with kotlin.test.Test. Both tests verify behavior without requiring Koin. CI step explicitly checks for org.junit.Test in commonTest dirs. |
| **SCAF-11** | Generated SkeletonKit.framework/Headers/ contains no Any? from SKIE generics | ⚠ PARTIAL | SampleUiState.kt sealed interface with concrete types exists; SkieGenericsTest passes at Kotlin level. CI grep gate present but silently bypassed when headers not found (exit 0 instead of exit 1). Runtime header inspection requires XCFramework build on macOS. |

**Scorecard: 3 VERIFIED, 2 FAILED, 5 PARTIAL/UNCERTAIN**

---

### Required Artifacts

| Artifact | Status | Details |
|----------|--------|---------|
| `gradle/libs.versions.toml` | ✓ VERIFIED | Lockstep comment present; all 4 versions correct; android-kmp-library alias; no android-library alias |
| `gradle/wrapper/gradle-wrapper.properties` | ✓ VERIFIED | Gradle 9.5.0 distribution URL |
| `gradle.properties` | ✓ VERIFIED | org.gradle.configuration-cache=true; org.gradle.jvmargs=-Xmx4g |
| `.tool-versions` | ✓ VERIFIED | java temurin-21.0.5+11 |
| `settings.gradle.kts` | ✓ VERIFIED | All 5 modules registered; compose-multiplatform-core excluded |
| `shared-core/build.gradle.kts` | ✓ VERIFIED | android.kmp.library plugin; iosArm64+iosSimulatorArm64 only; linkerOpts -lsqlite3; vanniktech |
| `shared-core/src/commonMain/sqldelight/dev/viethung/core/db/Greeting.sq` | ✓ VERIFIED | CREATE TABLE, INSERT OR IGNORE, selectById query |
| `shared-core/src/iosMain/.../DatabaseDriverFactory.ios.kt` | ✓ VERIFIED | NativeSqliteDriver |
| `shared-core/src/commonMain/.../KtorClient.kt` | ⚠ STUB-QUALITY | Exists and functional; CR-04: no HttpTimeout (hangs indefinitely); CR-06: LogLevel.HEADERS leaks auth headers in prod |
| `shared-core/src/commonMain/.../CoreModule.kt` | ⚠ PARTIAL | Wires KtorClient and AppDatabase; does NOT bind DatabaseDriverFactory (expects platform to provide it) |
| `shared-components/build.gradle.kts` | ✓ VERIFIED | baseName="SkeletonKit"; SKIE; KMMBridge; export(:shared-core); api(:shared-core) |
| `shared-components/src/commonMain/.../SampleUiState.kt` | ✓ VERIFIED | sealed interface with concrete types; no Result<T> |
| `shared-components/src/commonTest/.../SkieGenericsTest.kt` | ✓ VERIFIED | 4 @Test methods; kotlin.test.Test |
| `shared-app/build.gradle.kts` | ✓ VERIFIED | android.kmp.library; no vanniktech; no kmmbridge |
| `shared-app/src/commonMain/.../AppModule.kt` | ✗ BROKEN | Missing GreetingRepository binding (CR-01); initKoin() missing platformModule parameter (CR-02) |
| `shared-app/src/commonMain/.../GreetingViewModel.kt` | ✓ VERIFIED | StateFlow<UiState>; Loading/Ready/Error; viewModelScope.launch |
| `shared-app/src/commonMain/.../GreetingViewModelFactory.kt` | ✗ BROKEN | Uses GlobalContext.get().get<GreetingViewModel>() — bypasses ViewModelStore, defeats SCAF-05 deinit contract (CR-05) |
| `shared-app/src/commonTest/.../GreetingViewModelTest.kt` | ✓ VERIFIED | kotlin.test.Test; Turbine; 3 @Test methods; bypasses Koin correctly for unit test |
| `androidApp/build.gradle.kts` | ✓ VERIFIED | com.android.application; compileSdk=36; Compose BOM; koin-android |
| `androidApp/src/main/.../SkeletonApp.kt` | ✓ VERIFIED | startKoin with appModule + platformModule |
| `androidApp/src/main/.../PlatformModule.kt` | ✓ VERIFIED | Binds DatabaseDriverFactory(androidContext()) |
| `androidApp/src/main/.../GreetingScreen.kt` | ✓ VERIFIED | collectAsStateWithLifecycle(); koinViewModel(); renders Loading/Ready/Error |
| `server/build.gradle.kts` | ✓ VERIFIED | JVM-only; ktor-server-cio; no vanniktech |
| `server/src/main/.../HealthRouting.kt` | ✓ VERIFIED | GET /health returns 200 OK |
| `iosApp/iosApp/Common/IosViewModelStoreOwner.swift` | ⚠ PARTIAL | @StateObject used correctly in GreetingScreen; deinit clears store and prints log. CR-05 (factory uses GlobalContext not ViewModelStore) partially breaks the deinit contract. No Xcode project to compile against. |
| `iosApp/iosApp/Greeting/GreetingScreen.swift` | ⚠ PARTIAL | import SkeletonKit; @StateObject owner; for await state consumption. vm resolved inside body (CR-03). Cannot compile without .xcodeproj. |
| `iosApp/iosApp/App/AppKoinBridge.swift` | ⚠ PARTIAL | Calls AppModuleKt.doInitKoin(). No platformModule passed (CR-02). IN-03: SKIE name mapping for initKoin unverified. |
| `.github/workflows/ci.yml` | ⚠ PARTIAL | Correct job structure; correct gates. WR-05: SKIE header gate exits 0 when headers not found. WR-04: :server:test not included. No passing CI run recorded. |
| `architecture.md` | ✓ VERIFIED | SCAF-01 reconciliation note present |
| `docs/ARCHITECTURE.md` | ✓ VERIFIED | SCAF-01 reconciliation note present |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| appModule factory | GreetingRepository | get<GreetingRepository>() | ✗ NOT_WIRED | No Koin binding for GreetingRepository anywhere in the codebase |
| appModule factory | DatabaseDriverFactory (iOS) | initKoin() | ✗ NOT_WIRED | iOS initKoin() only passes appModule; platformModule with DatabaseDriverFactory never added for iOS |
| GreetingViewModelFactory | ViewModelStore | ViewModelProvider.create() | ✗ BROKEN | Factory retrieves from GlobalContext (Koin scope) not creates new instance for ViewModelStore |
| GreetingScreen.kt | GreetingViewModel | koinViewModel() + collectAsStateWithLifecycle() | ✓ WIRED | Android path wired correctly; blocked at runtime by CR-01 |
| SkeletonApp.kt | appModule + platformModule | startKoin | ✓ WIRED | Android Koin init correct |
| AppKoinBridge.swift | appModule only | AppModuleKt.doInitKoin() | ✗ PARTIAL | Does not pass iOS platformModule; DatabaseDriverFactory unbound |
| IosViewModelStoreOwner.deinit | viewModelStore.clear() | deinit block | ✓ WIRED (static) | Code is correct; runtime verification pending; CR-05 partially defeats the contract |
| CoreModule | AppDatabase via DatabaseDriverFactory | get<DatabaseDriverFactory>().createDriver() | ✓ WIRED for Android | Android: PlatformModule provides DatabaseDriverFactory; iOS: no binding |
| shared-components iOS framework | :shared-core types | api() + export() | ✓ WIRED | umbrella pattern correct |
| ci.yml SKIE header gate | SkeletonKit.framework/Headers | find + grep | ⚠ PARTIAL | Gate is present but exits 0 (not 1) when headers directory not found — silent bypass |

---

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| `GreetingScreen.kt` (Android) | `state` (UiState) | GreetingViewModel.state StateFlow | Blocked by CR-01 — Koin crash before ViewModel is created | ✗ DISCONNECTED at runtime |
| `GreetingScreen.swift` (iOS) | `uiState` | vm.state AsyncSequence (SKIE) | Blocked by CR-01 + CR-02; no .xcodeproj to compile | ✗ DISCONNECTED at runtime |
| `GreetingViewModelTest.kt` | `state` | inline anonymous GreetingRepository | Returns "Hello, KMP" in test scope | ✓ FLOWING (test only) |

---

### Behavioral Spot-Checks

Step 7b: SKIPPED (Gradle build requires JDK 21 and Android SDK on this machine; no emulator available; iOS requires Xcode on macOS).

---

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|---------|
| SCAF-01 | 01-02, 01-04, 01-06, 01-10 | Multi-module Gradle build compiles green | ⚠ PARTIAL | Static structure correct; runtime DI broken by CR-01/CR-02 |
| SCAF-02 | 01-03, 01-08 | Xcode project + SkeletonKit framework | ✗ FAILED | No .xcodeproj; Swift sources committed but unbuilt |
| SCAF-03 | 01-02, 01-03, 01-04 | All KMP modules use AGP-9 KMP plugin | ✓ SATISFIED | All three KMP modules use android.kmp.library alias |
| SCAF-04 | 01-01 | libs.versions.toml lockstep block | ✓ SATISFIED | Comment present; all 4 versions correct |
| SCAF-05 | 01-08 | IosViewModelStoreOwner @StateObject + deinit | ⚠ PARTIAL | Static pattern correct; runtime unverified; CR-05 partially invalidates deinit contract |
| SCAF-06 | 01-04, 01-06, 01-08 | Koin wires :shared-core; ViewModel resolvable | ✗ FAILED | GreetingRepository never bound (CR-01); iOS DatabaseDriverFactory unbound (CR-02) |
| SCAF-07 | 01-02, 01-07 | Ktor client + server /health route | ✓ SATISFIED | KtorClient, OkHttp/Darwin engines, /health route all present. CR-04 (no timeout) and CR-06 (HEADERS log level) are quality issues, not structural gaps. |
| SCAF-08 | 01-02 | SQLDelight schema + hello-world query | ⚠ PARTIAL | Schema, drivers, linker flag all present statically; runtime blocked by CR-01/CR-02 |
| SCAF-09 | 01-09 | CI: Android ubuntu-latest + iOS macos-14 timeout 30 | ⚠ PARTIAL | CI defined correctly; no passing run; SKIE gate has silent bypass path |
| SCAF-10 | 01-04, 01-05, 01-09 | kotlin.test harness; commonTest passes both platforms | ✓ SATISFIED | kotlin.test.Test used; tests bypass Koin; CI checks for org.junit.Test |
| SCAF-11 | 01-05, 01-09 | SkeletonKit headers no Any? | ⚠ PARTIAL | Kotlin-level test passes; CI gate silently bypassed; XCFramework never built |

---

## Code Review Findings — Impact on Phase Goal

### Critical Findings (01-REVIEW.md) — Gap vs Quality Classification

| Finding | Description | Phase Goal Impact | Classification |
|---------|-------------|-------------------|----------------|
| **CR-01** | GreetingRepository never bound in Koin | **BLOCKER for SCAF-06** — runtime NoBeanDefFoundException on GreetingViewModel injection on both platforms | GAP — invalidates must-have |
| **CR-02** | iOS initKoin() does not include platformModule; DatabaseDriverFactory unbound on iOS | **BLOCKER for SCAF-06 + SCAF-08** — iOS Koin graph crashes at DB access time; iOS has a structurally fragile dual-entrypoint | GAP — invalidates must-have |
| **CR-03** | ViewModel resolved inside SwiftUI body (not hoisted to stable @State or @StateObject) | **AFFECTS SCAF-05/06** — vm captured by .task { for await } may iterate a different ViewModel instance than loadGreeting() was called on during recomposition | QUALITY — does not directly invalidate static must-haves but introduces a correctness risk that must be fixed before Phase 2 |
| **CR-04** | No HttpTimeout on Ktor client — network calls hang indefinitely | Does not invalidate SCAF-07 (scaffolding requirement); affects Phase 6 network calls | QUALITY — fix before Phase 6 |
| **CR-05** | GreetingViewModelFactory uses GlobalContext.get() — ViewModel not owned by ViewModelStore | **AFFECTS SCAF-05** — IosViewModelStoreOwner.deinit calls viewModelStore.clear() but the Koin-managed ViewModel does not receive onCleared() through the ViewModelStore contract. The lifecycle safety that SCAF-05 requires is technically violated. | GAP — degrades SCAF-05 correctness |
| **CR-06** | LogLevel.HEADERS leaks auth headers in production builds | Does not invalidate any Phase 1 must-have; SCAF-07 is a scaffolding requirement | QUALITY — fix before Phase 3 introduces real auth |

**Summary:** CR-01, CR-02, and CR-05 directly invalidate Phase 1 must-haves (SCAF-06 and partially SCAF-05). CR-03, CR-04, CR-06 are quality defects that must be fixed before their respective dependent phases but do not block Phase 1 goal achievement alone.

### Warning Findings — No Phase Goal Impact

| Finding | Impact | Action |
|---------|--------|--------|
| WR-01 | `kotlinx-datetime` declared in :shared-core despite CLAUDE.md prohibition — unused dependency | Remove before Phase 2 |
| WR-02 | androidLogger(Level.DEBUG) in production builds | Fix before Phase 6 release build |
| WR-03 | print("[IosViewModelStoreOwner]...") not guarded by #if DEBUG | Fix before Phase 6 |
| WR-04 | CI does not run :server:test | Fix before Phase 4 server routes are added |
| WR-05 | CI SKIE header gate exits 0 when headers not found — silently bypassed | Change to exit 1; fix before any XCFramework CI validation is relied upon |
| WR-06 | GreetingViewModelTest uses expectMostRecentItem() — may produce false-green on iOS native scheduler | Switch to awaitItem() for determinism |
| WR-07 | 3 Compose dependencies declared as raw strings bypassing version catalog | Fix in next housekeeping pass |
| WR-08 | logback-classic pinned as raw string outside version catalog (outdated version) | Migrate to version catalog |

---

### Anti-Patterns Found

| File | Pattern | Severity | Impact |
|------|---------|----------|--------|
| `shared-app/src/commonMain/.../AppModule.kt` | factory { GetGreetingUseCase(get()) } with no GreetingRepository binding | BLOCKER | Runtime crash on GreetingViewModel injection |
| `shared-app/src/commonMain/.../AppModule.kt` | initKoin() does not pass platformModule parameter | BLOCKER | iOS DatabaseDriverFactory unbound |
| `shared-app/src/commonMain/.../GreetingViewModelFactory.kt` | GlobalContext.get().get<GreetingViewModel>() bypasses ViewModelStore | BLOCKER | SCAF-05 deinit contract not fulfilled |
| `shared-core/src/commonMain/.../KtorClient.kt` | LogLevel.HEADERS in production path | WARNING | Auth token leakage in shipped apps cloned from skeleton |
| `shared-core/build.gradle.kts` | implementation(libs.kotlinx.datetime) | WARNING | Violates CLAUDE.md prohibition |
| `.github/workflows/ci.yml` | exit 0 when SkeletonKit.framework/Headers not found | WARNING | SKIE header gate silently bypassed |
| `iosApp/iosApp/Greeting/GreetingScreen.swift` | vm resolved inside body (let vm = owner.viewModel(...)) | WARNING | Recomposition instability risk (CR-03) |

---

### Human Verification Required

#### 1. iOS XCFramework Build and Header Inspection

**Test:** Run `./gradlew :shared-components:assembleSkeletonKitReleaseXCFramework` on macOS with Xcode 16 installed.
**Expected:** Build succeeds; `find shared-components/build/XCFrameworks/release/SkeletonKit.xcframework -name '*.h' | xargs grep -l 'Any?'` returns empty.
**Why human:** Requires Xcode 16 toolchain on macOS.

#### 2. iOS Xcode Project Creation and Compile

**Test:** Create Xcode project (iOS App / SwiftUI), bundle ID dev.viethung.skeleton.ios, iOS 17.0 minimum. Wire committed Swift files. Embed SkeletonKit.xcframework (Embed & Sign). Add `-lsqlite3` to Other Linker Flags. Run ⌘B.
**Expected:** Zero Xcode compile errors.
**Why human:** IDE interaction required; no .xcodeproj to automate against.

#### 3. iOS Runtime Smoke — Hello KMP Renders

**Test:** After fixing CR-01 and CR-02, run app on iPhone 15 simulator (iOS 17+).
**Expected:** GreetingScreen shows "Hello, KMP" text.
**Why human:** Requires running simulator; dependent on Koin DI fix.

#### 4. iOS deinit Lifecycle Smoke — SCAF-05 Runtime Verification

**Test:** Navigate away from GreetingScreen (push a second view via NavigationStack), then pop back.
**Expected:** `[IosViewModelStoreOwner] deinit cleared store` appears in Xcode console.
**Why human:** Runtime behavior in running app; also blocked by CR-01/CR-05 fixes.

#### 5. Android Emulator Smoke

**Test:** After fixing CR-01, run `./gradlew :androidApp:assembleDebug` and install on emulator.
**Expected:** App launches; "Hello, KMP" renders; no Koin crash in logcat.
**Why human:** Requires Android emulator; runtime verification needed to confirm Koin wiring end-to-end.

#### 6. CI Green Run on GitHub Actions

**Test:** Push a commit after fixing all BLOCKER gaps.
**Expected:** Both android-build and ios-build jobs pass green.
**Why human:** Requires macOS runner with Xcode for iOS job; cannot be replicated locally without the same environment.

---

## Gaps Summary

**Three gaps block Phase 1 goal achievement:**

**Gap 1 (CR-01, root cause of SCAF-06 failure):** `GreetingRepository` has no Koin binding. `appModule` registers `GetGreetingUseCase(get())` which resolves `get<GreetingRepository>()` at runtime — throwing `NoBeanDefFoundException`. The comment in AppModule.kt says the platform module provides it, but `PlatformModule.kt` (Android) only binds `DatabaseDriverFactory`. There is no concrete `GreetingRepository` implementation anywhere in the source tree. Fix: provide a SQLDelight-backed `GreetingRepositoryImpl` and bind it.

**Gap 2 (CR-02, compounds SCAF-06 on iOS):** `initKoin()` starts Koin with only `appModule` — no platform module. On iOS, `coreModule` references `get<DatabaseDriverFactory>()` but there is no iOS Koin binding for `DatabaseDriverFactory`. This is independent of the Android `PlatformModule`. Fix: make `initKoin()` accept platform modules as parameters.

**Gap 3 (CR-05 + no Xcode project, SCAF-02/05):** The Xcode `.xcodeproj` was never created. Additionally, `GreetingViewModelFactory` retrieves from Koin's global scope instead of constructing a new `GreetingViewModel` for the `ViewModelStore` — meaning `IosViewModelStoreOwner.deinit`'s `viewModelStore.clear()` does not call `onCleared()` on the actual ViewModel in use. Fix: (a) create the Xcode project (HUMAN-UAT) and (b) rewrite the factory to construct a new instance.

**Secondary gaps (do not individually block but compound overall status):**
- SKIE header gate in CI exits 0 when headers not found — must exit 1 to be a real gate (affects SCAF-11 confidence)
- WR-01: kotlinx-datetime declared in :shared-core violates CLAUDE.md prohibition

---

_Verified: 2026-05-09_
_Verifier: Claude (gsd-verifier)_
