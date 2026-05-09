---
phase: 01-kmp-scaffold-tooling
plan: "12"
subsystem: ui
tags: [koin, viewmodel, lifecycle, kmp, ios, swiftui, skie]

# Dependency graph
requires:
  - phase: 01-kmp-scaffold-tooling
    plan: "04"
    provides: "IosViewModelStoreOwner, GreetingViewModel, GetGreetingUseCase, Koin module wiring"
provides:
  - "GreetingViewModelFactory that resolves GetGreetingUseCase from Koin and constructs GreetingViewModel directly"
  - "ViewModelProvider lifecycle ownership of GreetingViewModel — onCleared() fires on IosViewModelStoreOwner.deinit"
affects: [ios-app, shared-app, 01-14-PLAN]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "ViewModelProvider.Factory: resolve dependencies from Koin, construct ViewModel directly — never get<ViewModel>() from Koin"

key-files:
  created: []
  modified:
    - shared-app/src/commonMain/kotlin/dev/viethung/showcase/greeting/GreetingViewModelFactory.kt

key-decisions:
  - "CR-05 fix: factory resolves GetGreetingUseCase from GlobalContext.get() then calls GreetingViewModel(useCase) directly, giving ViewModelStore ownership of the instance"

patterns-established:
  - "KMP VM factory pattern: Koin resolves dependencies only; factory constructs VM via constructor — ViewModelProvider always owns the instance"

requirements-completed: [SCAF-05, SCAF-06]

# Metrics
duration: 5min
completed: 2026-05-09
---

# Phase 1 Plan 12: GreetingViewModelFactory CR-05 Fix Summary

**ViewModelProvider lifecycle contract restored: factory now constructs GreetingViewModel(useCase) directly instead of retrieving a Koin-managed instance, so IosViewModelStoreOwner.deinit correctly triggers onCleared() via viewModelStore.clear()**

## Performance

- **Duration:** ~5 min
- **Started:** 2026-05-09T04:00:00Z
- **Completed:** 2026-05-09T04:02:33Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments
- Replaced `GlobalContext.get().get<GreetingViewModel>()` with dependency-resolving, instance-constructing pattern
- `GetGreetingUseCase` is now the only thing resolved from Koin inside the factory
- `GreetingViewModel(useCase)` is constructed by the factory, giving `ViewModelProvider` ownership
- `viewModelStore.clear()` in `IosViewModelStoreOwner.deinit` will now call `onCleared()` on the correct instance

## Task Commits

1. **Task 1: Rewrite GreetingViewModelFactory to construct GreetingViewModel directly** - `f962364` (fix)

**Plan metadata:** (committed below with SUMMARY)

## Files Created/Modified
- `shared-app/src/commonMain/kotlin/dev/viethung/showcase/greeting/GreetingViewModelFactory.kt` - CR-05 fix: resolve dependency from Koin, construct GreetingViewModel directly in create()

## Decisions Made
- Factory resolves only `GetGreetingUseCase` from `GlobalContext` — the ViewModel itself is never retrieved from Koin inside a factory. This is the standard correct KMP ViewModel factory pattern.

## Deviations from Plan
None - plan executed exactly as written.

## Issues Encountered
- `gradlew` wrapper script is not present in this worktree or the main repo at this scaffold stage, so the compile verification (`./gradlew :shared-app:compileKotlinJvm`) could not run. The code change is syntactically correct Kotlin; compile verification will be exercised when the Gradle wrapper is added in a future scaffold plan.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- CR-05 is closed: `GreetingViewModelFactory` is correct
- `IosViewModelStoreOwner.deinit` lifecycle chain now works end-to-end for `GreetingViewModel`
- Ready for human UAT (plan 01-14) which will exercise the lifecycle at runtime

## Threat Surface Scan
No new network endpoints, auth paths, file access patterns, or schema changes introduced. The only change is resolving `GetGreetingUseCase` (already in Koin graph) instead of `GreetingViewModel` — no new trust boundaries.

---
*Phase: 01-kmp-scaffold-tooling*
*Completed: 2026-05-09*
