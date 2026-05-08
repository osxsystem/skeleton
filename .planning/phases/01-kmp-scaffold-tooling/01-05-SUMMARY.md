---
phase: 01-kmp-scaffold-tooling
plan: "05"
subsystem: ui
tags: [skie, kmp, kotlin, sealed-interface, generics, type-erasure, objc-bridge]

# Dependency graph
requires:
  - phase: 01-kmp-scaffold-tooling
    plan: "01"
    provides: "gradle/libs.versions.toml with SKIE version pinned"
  - phase: 01-kmp-scaffold-tooling
    plan: "03"
    provides: "shared-components module with dev.viethung.components package"
provides:
  - "SampleUiState.kt: canonical non-erased sealed UiState pattern for SKIE-bridged ViewModels"
  - "SkieConventions.kt: @Throws convention documentation for all public suspend functions"
  - "SkieGenericsTest.kt: 4 commonTests verifying sealed UiState type hierarchy"
affects:
  - phases 3-6 (component ViewModels must follow this sealed pattern)
  - 01-09 (CI grep gate on SkeletonKit.framework/Headers will verify no Any? via SKIE)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Sealed UiState pattern: use project-specific sealed interface (Loading/Ready/Error) with concrete data classes — never Result<T> or Flow<T?>"
    - "@Throws convention: all public suspend functions in :shared-components must declare @Throws(CancellationException::class, Exception::class)"
    - "kotlin.test.Test for all commonTest annotations — never org.junit.Test"

key-files:
  created:
    - shared-components/src/commonMain/kotlin/dev/viethung/components/SampleUiState.kt
    - shared-components/src/commonMain/kotlin/dev/viethung/components/SkieConventions.kt
    - shared-components/src/commonTest/kotlin/dev/viethung/components/SkieGenericsTest.kt
  modified: []

key-decisions:
  - "SampleUiState uses concrete String fields (not generics T) in data classes to prevent SKIE type erasure to Any? at the ObjC bridge"
  - "CI grep gate (find SkeletonKit.framework/Headers -name *.h | xargs grep Any?) deferred to Plan 09 — this plan establishes the Kotlin pattern only"
  - "@Throws enforcement is code review only in Phase 1 — Phase 7 CI can add a detekt rule per D-19"

patterns-established:
  - "Sealed UiState pattern: SampleUiState serves as the reference implementation for all component ViewModels in Phases 3+"
  - "SKIE convention documentation collocated with production code (SkieConventions.kt object)"

requirements-completed: [SCAF-02, SCAF-11]

# Metrics
duration: 2min
completed: 2026-05-08
---

# Phase 01 Plan 05: SKIE Generics Validation Pattern Summary

**Canonical non-erased sealed UiState wrapper and @Throws convention established for all SKIE-bridged ViewModels in :shared-components**

## Performance

- **Duration:** 2 min
- **Started:** 2026-05-08T11:00:18Z
- **Completed:** 2026-05-08T11:02:00Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- Created `SampleUiState.kt` as the canonical reference sealed UiState pattern (SCAF-11 / D-16 / Pitfall 4) — concrete data classes instead of generics prevent SKIE from generating `Any?` in ObjC headers
- Documented `@Throws` convention in `SkieConventions.kt` for all public suspend functions (D-19 / Pitfall 5)
- Created `SkieGenericsTest.kt` with 4 commonTests using `kotlin.test.Test` verifying the sealed hierarchy is complete and type-correct

## Task Commits

Each task was committed atomically:

1. **Task 1: Create SampleUiState.kt and SkieConventions.kt** - `9d528c7` (feat)
2. **Task 2: SkieGenericsTest — commonTest verifying UiState type hierarchy** - `a10627d` (test)

_Note: Task 2 is a TDD task — test commit establishes RED gate; GREEN was already satisfied by Task 1's implementation._

## Files Created/Modified
- `shared-components/src/commonMain/kotlin/dev/viethung/components/SampleUiState.kt` - Reference sealed UiState pattern: Loading / Ready(message) / Error(message) with SKIE generics rule documentation
- `shared-components/src/commonMain/kotlin/dev/viethung/components/SkieConventions.kt` - @Throws convention + no Result<T>/Flow<T?> rules documented for code review enforcement
- `shared-components/src/commonTest/kotlin/dev/viethung/components/SkieGenericsTest.kt` - 4 commonTests: type-distinctness, concrete message fields, exhaustive when() on sealed hierarchy

## Decisions Made
- Used `sealed interface` (not `sealed class`) for `SampleUiState` — interface is idiomatic in Kotlin 1.5+ and avoids constructor overhead
- Data fields use `String` (concrete) not generic `T` — this is the critical design decision that prevents SKIE erasure to `Any?`
- `SkieConventions` is an `object` with only documentation — no runtime behavior needed; keeps conventions co-located with production code
- CI grep gate deferred to Plan 09 as specified in D-16

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- All component ViewModels in Phases 3+ have a reference pattern to follow
- Plan 09 (CI/CD) can wire the grep gate against `SkeletonKit.framework/Headers/*.h` — the Kotlin-side pattern is now established
- The @Throws requirement is documented and ready for code review enforcement

## Threat Surface Scan
No new threat surface introduced — no network endpoints, auth paths, file access, or schema changes. Files are pure Kotlin data structures and test code.

---
*Phase: 01-kmp-scaffold-tooling*
*Completed: 2026-05-08*
