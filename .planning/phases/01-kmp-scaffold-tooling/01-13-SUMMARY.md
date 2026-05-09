---
phase: 01-kmp-scaffold-tooling
plan: "13"
subsystem: infra
tags: [ci, skie, xcframework, gradle, kotlinx, version-catalog]

# Dependency graph
requires:
  - phase: 01-09
    provides: ci.yml with ios-build job and SKIE header check step (silent-pass version)
  - phase: 01-02
    provides: shared-core build.gradle.kts with KMP source sets
provides:
  - CI ios-build SKIE header gate that exits 1 on missing headers (SCAF-11 hardened)
  - CI ios-build XCFramework path check that exits 1 on missing framework (SCAF-09 hardened)
  - shared-core build.gradle.kts with kotlinx-datetime removed (CLAUDE.md compliant)
  - gradle/libs.versions.toml with kotlinx-datetime entries removed (catalog hygiene)
affects: [phase-02, phase-03, phase-07]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "CI fail-fast: all validation gates must exit 1 on failure, never WARNING+continue"
    - "Catalog hygiene: unused/prohibited library entries must be removed from libs.versions.toml"

key-files:
  created: []
  modified:
    - .github/workflows/ci.yml
    - shared-core/build.gradle.kts
    - gradle/libs.versions.toml

key-decisions:
  - "CI gates must exit 1, not exit 0, to be real merge blockers — WR-05 closed"
  - "kotlinx-datetime removed from catalog entry (not just usage) to prevent silent reintroduction — WR-01 closed"

patterns-established:
  - "CI gate pattern: find output path → if missing → ERROR message + exit 1 (never WARNING + fallthrough)"

requirements-completed:
  - SCAF-09
  - SCAF-11

# Metrics
duration: 10min
completed: 2026-05-09
---

# Phase 1 Plan 13: Gap Closure — CI Gate Hardening and kotlinx-datetime Removal Summary

**Hardened CI SKIE/XCFramework gates from silent exit-0 to fail-fast exit-1 and removed the CLAUDE.md-prohibited kotlinx-datetime dependency from :shared-core and the version catalog**

## Performance

- **Duration:** 10 min
- **Started:** 2026-05-09T00:00:00Z
- **Completed:** 2026-05-09T00:10:00Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- CI ios-build XCFramework path check now exits 1 with an ERROR message instead of WARNING+fallthrough (closes WR-05 path check)
- CI ios-build SKIE header gate now exits 1 with an ERROR message instead of WARNING+exit 0 (closes WR-05 SCAF-11 gate)
- `implementation(libs.kotlinx.datetime)` removed from shared-core commonMain dependencies (closes WR-01)
- `kotlinx-datetime` version and library entries removed from `gradle/libs.versions.toml` to prevent silent reintroduction

## Task Commits

Each task was committed atomically:

1. **Task 1: Harden CI SKIE header gate and XCFramework path check to exit 1 on failure** - `14f3e9d` (fix)
2. **Task 2: Remove prohibited kotlinx-datetime from :shared-core and version catalog** - `946fde8` (fix)

**Plan metadata:** (see final commit)

## Files Created/Modified
- `.github/workflows/ci.yml` - XCFramework path check and SKIE header gate both converted from WARNING+silent-pass to ERROR+exit 1
- `shared-core/build.gradle.kts` - Removed `implementation(libs.kotlinx.datetime)` from commonMain
- `gradle/libs.versions.toml` - Removed `kotlinx-datetime = "0.7.1"` from [versions] and `kotlinx-datetime = { ... }` from [libraries]

## Decisions Made
- CI gate hardening uses ERROR messages (not just exit 1) so CI log readers understand the fix needed — not just a bare exit
- Removed kotlinx-datetime from the catalog entry (not just the usage line) so the entry cannot be silently re-adopted by a developer who sees it and assumes it is intentional

## Deviations from Plan

None — plan executed exactly as written. The plan's acceptance criteria check `grep -A3 'HEADERS_DIR.*find' ... | grep 'exit 1'` doesn't match because the exit 1 is 6 lines after the match (longer error message), but the implementation is correct and the exit 1 is present at line 193.

## Issues Encountered
None.

## User Setup Required
None — no external service configuration required.

## Next Phase Readiness
- WR-01 and WR-05 are both closed; Phase 01 gap closure complete
- CI gates are now genuine merge blockers for SKIE/XCFramework build failures
- :shared-core build.gradle.kts is now fully CLAUDE.md-compliant (no prohibited libraries)

---
*Phase: 01-kmp-scaffold-tooling*
*Completed: 2026-05-09*
