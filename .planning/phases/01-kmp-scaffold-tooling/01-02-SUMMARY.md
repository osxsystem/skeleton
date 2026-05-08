---
phase: 01-kmp-scaffold-tooling
plan: "02"
subsystem: database, infra, api
tags: [kotlin-multiplatform, sqldelight, ktor, koin, agp9, vanniktech, shared-core]

requires: []
provides:
  - ":shared-core module with AGP-9 KMP plugin, Ktor client scaffold, SQLDelight Greeting schema, Koin coreModule, vanniktech maven-publish wiring"
  - "DatabaseDriverFactory expect/actual for Android (AndroidSqliteDriver) and iOS (NativeSqliteDriver)"
  - "createHttpClient() Ktor factory in commonMain"
  - "Greeting.sq SQLDelight schema with hello-world seed row"
affects:
  - "shared-components"
  - "shared-app"
  - "androidApp"
  - "iosApp"

tech-stack:
  added:
    - "com.android.kotlin.multiplatform.library (AGP 9 KMP library plugin)"
    - "SQLDelight 2.3.2 (AppDatabase, Greeting schema)"
    - "Ktor 3.4.0 (HttpClient with OkHttp/Darwin engines)"
    - "Koin 4.2.1 (coreModule)"
    - "vanniktech gradle-maven-publish 0.36.0"
    - "AndroidSqliteDriver (androidMain)"
    - "NativeSqliteDriver (iosMain)"
  patterns:
    - "expect/actual for platform-specific DatabaseDriverFactory"
    - "Koin coreModule wires HttpClient + AppDatabase; platform modules provide DatabaseDriverFactory"
    - "iosMain binaries.framework linkerOpts.add('-lsqlite3') for NativeSqliteDriver"
    - "Version catalog alias (libs.plugins.*) for all plugin declarations"

key-files:
  created:
    - "shared-core/build.gradle.kts"
    - "shared-core/src/commonMain/sqldelight/dev/viethung/core/db/Greeting.sq"
    - "shared-core/src/commonMain/kotlin/dev/viethung/core/db/DatabaseDriverFactory.kt"
    - "shared-core/src/androidMain/kotlin/dev/viethung/core/db/DatabaseDriverFactory.android.kt"
    - "shared-core/src/iosMain/kotlin/dev/viethung/core/db/DatabaseDriverFactory.ios.kt"
    - "shared-core/src/commonMain/kotlin/dev/viethung/core/network/KtorClient.kt"
    - "shared-core/src/commonMain/kotlin/dev/viethung/core/di/CoreModule.kt"
  modified: []

key-decisions:
  - "Applied com.android.kotlin.multiplatform.library (not com.android.library) per D-14 / Pitfall 20 / SCAF-03"
  - "iosArm64 + iosSimulatorArm64 only; iosX64 absent (D-01)"
  - "NativeSqliteDriver with linkerOpts.add('-lsqlite3') in iosMain framework block (D-18 / Pitfall 19)"
  - "Koin coreModule wires HttpClient + AppDatabase; DatabaseDriverFactory provided by platform modules"
  - "Ktor LogLevel.HEADERS only (T-02-01 mitigation; no body logging)"
  - "vanniktech coordinates: dev.viethung:shared-core:0.1.0-SNAPSHOT for publishToMavenLocal dry-run"

patterns-established:
  - "expect/actual boundary: DatabaseDriverFactory in commonMain, platform actuals in androidMain/iosMain"
  - "Koin split: coreModule (common) + platform modules (provide DatabaseDriverFactory with context)"
  - "SQLDelight packageName = dev.viethung.core.db; .sq files in src/commonMain/sqldelight/dev/viethung/core/db/"

requirements-completed:
  - SCAF-01
  - SCAF-03
  - SCAF-07
  - SCAF-08

duration: 3min
completed: 2026-05-08
---

# Phase 01 Plan 02: shared-core KMP Module Summary

**AGP-9 KMP library module with SQLDelight Greeting schema (NativeSqliteDriver + -lsqlite3), Ktor HttpClient scaffold (OkHttp/Darwin), Koin coreModule, and vanniktech maven-publish dry-run wiring**

## Performance

- **Duration:** 3 min
- **Started:** 2026-05-08T10:53:20Z
- **Completed:** 2026-05-08T10:55:53Z
- **Tasks:** 2
- **Files modified:** 7

## Accomplishments

- Created `:shared-core/build.gradle.kts` with `com.android.kotlin.multiplatform.library` (AGP 9), iosArm64+iosSimulatorArm64 targets, SQLDelight, and vanniktech maven-publish coordinates
- Added SQLDelight Greeting schema with `CREATE TABLE`, hello-world seed row, and two named queries; `NativeSqliteDriver` iOS actual uses `-lsqlite3` linker flag in the framework block
- Implemented `createHttpClient()` Ktor factory and `coreModule` Koin wiring; `DatabaseDriverFactory` expect/actual provides Android (AndroidSqliteDriver) and iOS (NativeSqliteDriver) platform drivers

## Task Commits

Each task was committed atomically:

1. **Task 1: shared-core/build.gradle.kts** - `2f70f82` (feat)
2. **Task 2: SQLDelight schema, Ktor client, driver factories, CoreModule** - `88f792d` (feat)

## Files Created/Modified

- `shared-core/build.gradle.kts` - AGP-9 KMP library build config with iOS targets, SQLDelight, Ktor, Koin, vanniktech
- `shared-core/src/commonMain/sqldelight/dev/viethung/core/db/Greeting.sq` - SQLDelight schema with Greeting table and hello-world seed
- `shared-core/src/commonMain/kotlin/dev/viethung/core/db/DatabaseDriverFactory.kt` - expect class in commonMain
- `shared-core/src/androidMain/kotlin/dev/viethung/core/db/DatabaseDriverFactory.android.kt` - AndroidSqliteDriver actual
- `shared-core/src/iosMain/kotlin/dev/viethung/core/db/DatabaseDriverFactory.ios.kt` - NativeSqliteDriver actual
- `shared-core/src/commonMain/kotlin/dev/viethung/core/network/KtorClient.kt` - createHttpClient() factory with ContentNegotiation + Logging
- `shared-core/src/commonMain/kotlin/dev/viethung/core/di/CoreModule.kt` - Koin coreModule wiring HttpClient + AppDatabase

## Decisions Made

- Plugin alias `libs.plugins.android.kmp.library` maps to `com.android.kotlin.multiplatform.library`; plugin ID comment added inline per D-14 / SCAF-03
- `coreModule` omits `DatabaseDriverFactory` binding since Android needs Context and iOS is no-arg — platform Koin setup (in `:androidApp` and `iosApp`) provides the actual factory instance
- Ktor `LogLevel.HEADERS` (not BODY) per threat T-02-01 mitigation — no sensitive body logging

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## Known Stubs

- `KtorClient.kt`: No `HttpTimeout` plugin installed (T-02-03 accepted — add `requestTimeoutMillis = 30_000` before Phase 6 real network calls)
- `CoreModule.kt`: `DatabaseDriverFactory` instance not bound in `coreModule`; platform modules must provide it — this is intentional (documented in plan and code)

## Threat Flags

| Flag | File | Description |
|------|------|-------------|
| threat_flag: information-disclosure | shared-core/src/commonMain/kotlin/dev/viethung/core/network/KtorClient.kt | Ktor LogLevel.HEADERS; must downgrade to NONE before production (T-02-01) |

## Next Phase Readiness

- `:shared-core` module structure is ready for plan 01-03+ to depend on
- Plan 01-01 (parallel) provides `gradle/libs.versions.toml`, `settings.gradle.kts`, and root `build.gradle.kts` — these are required for `:shared-core` to build
- After orchestrator merges both worktrees, `:shared-core` should be included in `settings.gradle.kts` via `include(":shared-core")`
- No blockers for continuation

## Self-Check: PASSED

Files exist:
- shared-core/build.gradle.kts: FOUND
- shared-core/src/commonMain/sqldelight/dev/viethung/core/db/Greeting.sq: FOUND
- shared-core/src/commonMain/kotlin/dev/viethung/core/db/DatabaseDriverFactory.kt: FOUND
- shared-core/src/androidMain/kotlin/dev/viethung/core/db/DatabaseDriverFactory.android.kt: FOUND
- shared-core/src/iosMain/kotlin/dev/viethung/core/db/DatabaseDriverFactory.ios.kt: FOUND
- shared-core/src/commonMain/kotlin/dev/viethung/core/network/KtorClient.kt: FOUND
- shared-core/src/commonMain/kotlin/dev/viethung/core/di/CoreModule.kt: FOUND

Commits exist:
- 2f70f82: feat(01-02): create shared-core/build.gradle.kts with AGP-9 KMP plugin
- 88f792d: feat(01-02): add SQLDelight schema, Ktor client, driver factories, CoreModule

---
*Phase: 01-kmp-scaffold-tooling*
*Completed: 2026-05-08*
