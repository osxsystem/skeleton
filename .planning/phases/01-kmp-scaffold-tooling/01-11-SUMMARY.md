---
phase: 01-kmp-scaffold-tooling
plan: "11"
subsystem: di
tags: [koin, sqldelight, kmp, di, dependency-injection, ios, android]

requires:
  - phase: 01-02
    provides: shared-core with AppDatabase, DatabaseDriverFactory expect/actual, and coreModule
  - phase: 01-04
    provides: shared-app scaffolding with GreetingRepository interface, GetGreetingUseCase, GreetingViewModel

provides:
  - GreetingRepositoryImpl — SQLDelight-backed implementation of GreetingRepository
  - factory<GreetingRepository> binding in appModule (CR-01 closed)
  - initKoin(vararg platformModules) in commonMain — iOS-safe Koin entry point (CR-02 closed)
  - IosPlatformModule.kt — iOS Koin module binding DatabaseDriverFactory()
  - AppKoinBridge.swift updated to pass iosPlatformModule to doInitKoin (CR-02 iOS closed)
  - SkeletonApp.kt confirmed with startKoin { modules(appModule, platformModule) } (CR-02 Android closed)

affects:
  - 01-12 (GreetingViewModel integration tests)
  - 01-14 (human UAT — confirms doInitKoin symbol on real XCFramework)
  - phase-02 (forms, amount input — will use the same DI pattern)

tech-stack:
  added: []
  patterns:
    - "iOS Koin init via initKoin(vararg platformModules) in commonMain; Android calls startKoin directly with androidLogger/androidContext"
    - "Platform-specific DatabaseDriverFactory binding in platform modules (not coreModule)"
    - "factory<Interface> { ConcreteImpl(get()) } pattern for repository bindings in appModule"

key-files:
  created:
    - shared-app/src/commonMain/kotlin/dev/viethung/showcase/greeting/GreetingRepositoryImpl.kt
    - shared-app/src/iosMain/kotlin/dev/viethung/showcase/di/IosPlatformModule.kt
  modified:
    - shared-app/src/commonMain/kotlin/dev/viethung/showcase/di/AppModule.kt
    - androidApp/src/main/kotlin/dev/viethung/skeleton/android/SkeletonApp.kt
    - iosApp/iosApp/App/AppKoinBridge.swift

key-decisions:
  - "Android does NOT call initKoin() — androidLogger and androidContext are Android-only Koin extensions; startKoin is called directly in SkeletonApp.kt"
  - "initKoin(vararg platformModules) is the iOS-only shared entry point; vararg allows iOS to pass iosPlatformModule without a separate overload"
  - "GreetingRepositoryImpl is bound as factory (not single) because GreetingViewModel is also factory — each injection site gets its own VM+repository pair"
  - "doInitKoin defaulted (no XCFramework headers available at authoring time); IN-03 resolution path: HUMAN-UAT plan 01-14 confirms the exact SKIE-mangled symbol"

patterns-established:
  - "Platform DI split: Android owns startKoin in Application.onCreate; iOS owns doInitKoin in Swift AppKoinBridge"
  - "iosMain Koin module (IosPlatformModule.kt) is the canonical location for iOS-specific bindings"

requirements-completed:
  - SCAF-01
  - SCAF-06
  - SCAF-08

duration: 15min
completed: 2026-05-09
---

# Phase 1 Plan 11: Koin DI Graph Fix — CR-01 and CR-02 Summary

**SQLDelight-backed GreetingRepositoryImpl bound in appModule; initKoin accepts platform modules; iOS iosPlatformModule created; both platform entry points wired to a fully resolvable Koin DI graph**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-05-09T00:00:00Z
- **Completed:** 2026-05-09
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments

- Created GreetingRepositoryImpl that reads from AppDatabase.greetingQueries.selectById — closes CR-01 (no GreetingRepository binding)
- Added factory<GreetingRepository> to appModule and changed initKoin to accept vararg platformModules — closes CR-02 (iOS missing platform module)
- Created IosPlatformModule.kt with single { DatabaseDriverFactory() } for iOS
- Updated AppKoinBridge.swift to call doInitKoin(platformModules: [IosPlatformModuleKt.iosPlatformModule])
- Confirmed SkeletonApp.kt uses startKoin { modules(appModule, platformModule) } directly (Android CR-02 already correct on develop)

## Task Commits

Each task was committed atomically:

1. **Task 1: Add GreetingRepositoryImpl and update AppModule with vararg initKoin** - `e53ab96` (feat)
2. **Task 2: Create iOS platform module and update both platform entry points** - `f116e58` (feat)

**Plan metadata:** (docs commit follows)

## Files Created/Modified

- `shared-app/src/commonMain/kotlin/dev/viethung/showcase/greeting/GreetingRepositoryImpl.kt` - New: SQLDelight-backed GreetingRepository implementation
- `shared-app/src/commonMain/kotlin/dev/viethung/showcase/di/AppModule.kt` - Updated: added factory<GreetingRepository> binding and vararg initKoin()
- `shared-app/src/iosMain/kotlin/dev/viethung/showcase/di/IosPlatformModule.kt` - New: iOS Koin module binding DatabaseDriverFactory()
- `androidApp/src/main/kotlin/dev/viethung/skeleton/android/SkeletonApp.kt` - Confirmed: startKoin with appModule + platformModule
- `iosApp/iosApp/App/AppKoinBridge.swift` - Updated: passes iosPlatformModule to doInitKoin

## Decisions Made

- Android does NOT call initKoin() — androidLogger and androidContext are Android-only Koin extensions that cannot live in commonMain
- iOS calls the shared initKoin(vararg platformModules) via SKIE-mangled doInitKoin symbol
- SKIE symbol defaulted to doInitKoin (no XCFramework headers available); plan 01-14 HUMAN-UAT validates the actual symbol

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

No XCFramework headers were available to confirm the SKIE-mangled symbol for initKoin. The plan anticipates this via the IN-03 note and defaults to doInitKoin, with plan 01-14 (HUMAN-UAT) as the confirmation path.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Koin DI graph is fully resolvable on both platforms: GreetingRepository is bound, both platform entry points supply DatabaseDriverFactory
- GreetingViewModel injection will no longer crash with NoBeanDefFoundException
- SCAF-06 and SCAF-08 runtime paths are unblocked
- Plan 01-14 (HUMAN-UAT) should validate doInitKoin vs initKoin SKIE symbol against a real XCFramework build

---
*Phase: 01-kmp-scaffold-tooling*
*Completed: 2026-05-09*
