---
phase: 01-kmp-scaffold-tooling
plan: "17"
status: partial
subsystem: build-infra
tags: [koin, kmp, coroutines, turbine, gradle, agp, compose-compiler]

requires:
  - phase: 01-16
    provides: "AGP 9 KMP DSL migration; BI-G/H/I discovered"

provides:
  - "GreetingViewModelFactory.kt uses KoinPlatformTools.defaultContext() (Koin 4.x KMP-correct, no JVM-only GlobalContext)"
  - "GreetingViewModelTest.kt 3/3 tests passing with Dispatchers.setMain + advanceUntilIdle"
  - "Compose Compiler plugin via libs.plugins.compose.compiler catalog alias (no inline version literal)"
  - "androidApp/build.gradle.kts: explicit shared-core dependency (PlatformModule.kt DatabaseDriverFactory visibility)"
  - "01-HUMAN-UAT.md: BI-F/G/H marked closed; BI-I deferred; BI-J documented"

affects: [01-14, 01-15, 01-16, 01-HUMAN-UAT]

tech-stack:
  added:
    - "KoinPlatformTools.defaultContext() — Koin 4.x KMP-correct Koin singleton accessor for commonMain"
    - "Dispatchers.setMain(StandardTestDispatcher()) — Main dispatcher override for coroutine tests"
    - "advanceUntilIdle() — TestCoroutineScheduler advancement for viewModelScope.launch synchronization"
    - "compose-compiler = { id = \"org.jetbrains.kotlin.plugin.compose\", version.ref = \"kotlin\" } in libs.versions.toml [plugins]"
  patterns:
    - "Use KoinPlatformTools.defaultContext() instead of GlobalContext in commonMain — GlobalContext is JVM-only"
    - "@BeforeTest + @AfterTest dispatcher setup is mandatory when ViewModel uses viewModelScope.launch in commonTest"
    - "Compose Compiler plugin should reference libs.plugins.compose.compiler with version.ref = \"kotlin\" to track Kotlin version automatically"

key-files:
  created: []
  modified:
    - "shared-app/src/commonMain/kotlin/dev/viethung/showcase/greeting/GreetingViewModelFactory.kt — GlobalContext → KoinPlatformTools.defaultContext() (BI-G fix)"
    - "shared-app/src/commonTest/kotlin/dev/viethung/showcase/greeting/GreetingViewModelTest.kt — Dispatchers.setMain + advanceUntilIdle (BI-H fix)"
    - "gradle/libs.versions.toml — compose-compiler plugin entry added"
    - "androidApp/build.gradle.kts — catalog alias + explicit shared-core dependency"
    - ".planning/phases/01-kmp-scaffold-tooling/01-HUMAN-UAT.md — BI-F/G/H closed; BI-I deferred; BI-J documented"

key-decisions:
  - "KoinPlatformTools.defaultContext() is the Koin 4.x KMP-correct accessor: it returns the same singleton on JVM and Native; GlobalContext is JVM-flavored and fails commonMain metadata compilation"
  - "PARTIAL status: BI-J (iOS framework linker missing -lsqlite3 in shared-app + shared-components) surfaces when :shared-app:build or :shared-components:build runs; assembleDebug itself exits 0"
  - "BI-I explicitly deferred: SKIE 0.10.11 supports Kotlin up to 2.3.20; project pins 2.3.21; no upstream release available"
  - "Added explicit implementation(project(':shared-core')) to androidApp/build.gradle.kts (Rule 3): shared-app uses implementation() not api(), so shared-core types were not on androidApp compile classpath — PlatformModule.kt could not resolve DatabaseDriverFactory"

requirements-completed:
  - SCAF-04

duration: ~14min
completed: 2026-05-09
---

# Phase 01 / Plan 17: Close BI-G/BI-H + Compose Plugin Catalog Alias (PARTIAL)

**KoinPlatformTools.defaultContext() replaces GlobalContext (BI-G closed); ViewModel test coroutine dispatch fixed 3/3 (BI-H closed); Compose Compiler plugin via catalog alias; Android assembleDebug green; BI-I deferred upstream; BI-J newly discovered (iOS framework linker)**

## Performance

- **Duration:** ~14 min
- **Started:** 2026-05-09T14:06:18Z
- **Completed:** 2026-05-09T14:20:18Z
- **Tasks attempted:** 4 of 4 (all executed; must_haves partially satisfied — BI-J blocks full smoke)
- **Files modified:** 5

## Accomplishments

- **BI-G closed:** `GreetingViewModelFactory.kt` replaced `org.koin.core.context.GlobalContext` (JVM-only, unresolvable in commonMain Native compilation) with `org.koin.mp.KoinPlatformTools.defaultContext()` (Koin 4.x KMP-correct). `:shared-app:compileCommonMainKotlinMetadata`, `:shared-app:compileKotlinIosArm64`, `:shared-app:compileKotlinIosSimulatorArm64` all exit 0.
- **BI-H closed:** `GreetingViewModelTest.kt` wired `Dispatchers.setMain(StandardTestDispatcher())` in `@BeforeTest` and `Dispatchers.resetMain()` in `@AfterTest`. Added `advanceUntilIdle()` after each `vm.loadGreeting()` call. `:shared-app:allTests` exits 0 with 3/3 tests passing (all three test cases green on both Android JVM host and iOS Simulator).
- **Compose plugin via catalog alias:** `gradle/libs.versions.toml [plugins]` now has `compose-compiler = { id = "org.jetbrains.kotlin.plugin.compose", version.ref = "kotlin" }`. `androidApp/build.gradle.kts` uses `alias(libs.plugins.compose.compiler)` — no inline version literal.
- **Android assembleDebug green:** `./gradlew :androidApp:assembleDebug --no-daemon` exits 0. APK produced at `androidApp/build/outputs/apk/debug/androidApp-debug.apk`.
- **BI-I documented:** SKIE 0.10.11 supports Kotlin up to 2.3.20; project pins 2.3.21. Deferred with `gh api repos/touchlab/SKIE/releases` upstream check command.

## Task Commits

| Task | Description | Commit |
|------|-------------|--------|
| Task 1 | Fix BI-G: GreetingViewModelFactory uses KoinPlatformTools.defaultContext() | `e9b7237` |
| Task 2 | Fix BI-H: Dispatchers.setMain + advanceUntilIdle in GreetingViewModelTest | `ae7d20c` |
| Task 3 | Promote Compose Compiler plugin to libs.plugins.compose.compiler catalog alias | `a954d7d` |
| Task 4 | Close BI-F/G/H in 01-HUMAN-UAT.md + deviation fix for shared-core dep | `c485ff4` |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Added explicit `shared-core` dependency to `androidApp/build.gradle.kts`**
- **Found during:** Task 4 (first smoke run)
- **Issue:** After BI-G was fixed and `:shared-app:compileCommonMainKotlinMetadata` started passing, `androidApp:compileDebugKotlin` failed with `Unresolved reference 'core'` at `androidApp/src/main/kotlin/dev/viethung/skeleton/android/di/PlatformModule.kt:3`. Root cause: `shared-app` uses `implementation(project(":shared-core"))` (not `api()`), so `shared-core` types are not on `androidApp`'s compile classpath.
- **Fix:** Added `implementation(project(":shared-core"))` to `androidApp/build.gradle.kts` dependencies block.
- **Files modified:** `androidApp/build.gradle.kts`
- **Commit:** `c485ff4` (combined with Task 4)
- **Verification:** `./gradlew :androidApp:compileDebugKotlin --no-daemon` exits 0.

## New Defect Discovered (BI-J)

### BI-J — iOS framework linker missing `-lsqlite3` (outside plan scope)

- **Symptom:** `./gradlew :shared-app:build :shared-components:build --no-daemon` fails at iOS framework linking tasks (`:shared-app:linkDebugFrameworkIosArm64`, `:shared-components:linkReleaseFrameworkIosArm64`).
- **Error:** `ld: Undefined symbols: _sqlite3_bind_blob, _sqlite3_bind_double, _sqlite3_bind_int64, ...` — missing `libsqlite3`.
- **Root cause:** `shared-core/build.gradle.kts` has `linkerOpts.add("-lsqlite3")` in its iOS framework declaration (line 27). However `shared-app/build.gradle.kts` and `shared-components/build.gradle.kts` both have `iosTarget.binaries.framework {}` blocks without this linker flag. When `shared-app` or `shared-components` link their iOS frameworks (which include SQLDelight native driver transitively via `:shared-core`), the sqlite3 symbols are unresolved.
- **Impact:** `:shared-app:build` and `:shared-components:build` fail. `:androidApp:assembleDebug` is NOT affected — it doesn't link iOS frameworks. iOS Tests 1–7 remain blocked.
- **Affected files:** `shared-app/build.gradle.kts` (line ~25: add `linkerOpts.add("-lsqlite3")`), `shared-components/build.gradle.kts` (line ~31: add `linkerOpts.add("-lsqlite3")`) — both outside 01-17 deviation-protocol scope.
- **Recommended next-plan scope:** Add `linkerOpts.add("-lsqlite3")` to the `iosTarget.binaries.framework {}` block in both `shared-app/build.gradle.kts` and `shared-components/build.gradle.kts`.

## Verification Results

| Check | Command | Result |
|-------|---------|--------|
| 1 | `grep -c 'GlobalContext' GreetingViewModelFactory.kt` | 0 ✓ |
| 2 | `grep -c 'KoinPlatformTools.defaultContext' GreetingViewModelFactory.kt` | 1 ✓ |
| 3 | `grep -c '@BeforeTest\|@AfterTest\|advanceUntilIdle\|setMain\|resetMain' GreetingViewModelTest.kt` | 6 ✓ (≥5) |
| 4 | `grep -c 'compose-compiler' gradle/libs.versions.toml` | 1 ✓ |
| 5 | `grep -c 'libs.plugins.compose.compiler' androidApp/build.gradle.kts` | 1 ✓ |
| 6 | `grep -c 'id(.*kotlin.plugin.compose.*version' androidApp/build.gradle.kts` | 0 ✓ |
| 7 | `:shared-app:compileCommonMainKotlinMetadata --no-daemon` | BUILD SUCCESSFUL ✓ |
| 8 | `:shared-app:compileKotlinIosArm64 :shared-app:compileKotlinIosSimulatorArm64 --no-daemon` | BUILD SUCCESSFUL ✓ |
| 9 | `:shared-app:allTests --no-daemon` | BUILD SUCCESSFUL; 3/3 tests ✓ |
| 10 | `:shared-core:build :shared-components:build :shared-app:build :androidApp:assembleDebug --no-daemon` | FAILED — BI-J (iOS linker) |
| 10a | `:androidApp:assembleDebug --no-daemon` (standalone) | BUILD SUCCESSFUL ✓ |
| 11 | `find androidApp/build/outputs/apk/debug -name '*.apk' \| wc -l` | 1 ✓ |
| 12 | `grep -c 'CLOSED by 01-17' 01-HUMAN-UAT.md` | 2 ✓ |
| 13 | `grep -c 'A through H closed' 01-HUMAN-UAT.md` | 1 ✓ |
| 14 | `grep 'UPSTREAM BLOCKER' 01-HUMAN-UAT.md \| grep 'gh api repos/touchlab'` | present ✓ |

## Cross-References

- **01-15 (PARTIAL → effective-closed for Android):** 01-15's Task 3 smoke gate was blocked on BI-F→BI-G cascade. BI-G is now closed. Android smoke (`assembleDebug`) passes. 01-15's PARTIAL status can be considered effective-closed for the Android gate. iOS gate remains blocked on BI-I and BI-J.
- **01-16 (PARTIAL → effective-closed for Android):** 01-16's `must_haves.assembleDebug` truth (`./gradlew :androidApp:assembleDebug --no-daemon exits 0`) is now satisfied via BI-G + BI-H + Rule 3 deviation fixes in this plan.
- **01-14 status:** Task 1 (Android smoke) gate — now satisfied. Task 2 (iOS HUMAN-UAT) — still gated on BI-I and BI-J.

## SCAF Requirement Status

- **SCAF-01** (KMP library modules use AGP 9 DSL): Satisfied by 01-16 (DSL migration) + confirmed by 01-17 (builds pass).
- **SCAF-02** (`:androidApp:assembleDebug` exits 0): Satisfied — standalone `:androidApp:assembleDebug` exits 0 and produces APK. Full `:shared-components:build` chain fails on BI-J (iOS linker, out of scope).
- **SCAF-04** (Koin wiring correct + tests pass): Satisfied — `KoinPlatformTools.defaultContext()` used correctly; 3/3 GreetingViewModelTest pass.

## BI-I Upstream-Blocker Annotation

SKIE 0.10.11 (released 2026-04-02, latest as of 2026-05-09) supports Kotlin 2.0.0 .. 2.3.20. Project pins Kotlin 2.3.21. No upstream SKIE release with 2.3.21 support exists.

Upstream check command (re-run when SKIE releases):
```bash
gh api repos/touchlab/SKIE/releases --jq '.[0:3] | .[] | "\(.tag_name) - \(.published_at[:10])"'
```

When SKIE > 0.10.11 with Kotlin 2.3.21 support ships: bump `skie` version in `gradle/libs.versions.toml` and remove `isEnabled = false` from `shared-components/build.gradle.kts`.

## Status

**PARTIAL.**

- ✓ BI-G closed: GreetingViewModelFactory uses KoinPlatformTools.defaultContext() — commonMain + Native targets compile
- ✓ BI-H closed: GreetingViewModelTest 3/3 passing with Dispatchers.setMain + advanceUntilIdle
- ✓ Compose Compiler plugin via catalog alias (no inline version literal)
- ✓ `:androidApp:assembleDebug` exits 0; APK produced
- ✓ 01-HUMAN-UAT.md updated: BI-F/G/H closed; BI-I deferred; BI-J documented
- ✗ `:shared-core:build :shared-components:build :shared-app:build :androidApp:assembleDebug` full chain fails — BI-J (iOS framework linker missing `-lsqlite3` in shared-app + shared-components; out of scope for deviation protocol)

**Must_haves status:**
- ✓ `./gradlew :androidApp:assembleDebug exits 0` (standalone — satisfied)
- ✓ `./gradlew :shared-app:allTests exits 0 with 3/3 tests` (satisfied)
- ✓ `GreetingViewModelFactory.kt no longer imports GlobalContext` (satisfied)
- ✓ `Compose Compiler plugin uses catalog alias` (satisfied)
- ✓ `01-HUMAN-UAT.md marks BI-F/G/H closed; BI-I open with upstream-blocker annotation` (satisfied)
- ~ `Full smoke (:shared-core:build :shared-components:build :shared-app:build :androidApp:assembleDebug)` (PARTIAL — BI-J blocks iOS framework linking; Android smoke itself passes)

## Self-Check: PASSED

| Item | Status |
|------|--------|
| GreetingViewModelFactory.kt exists | FOUND |
| GreetingViewModelTest.kt exists | FOUND |
| gradle/libs.versions.toml exists | FOUND |
| androidApp/build.gradle.kts exists | FOUND |
| 01-HUMAN-UAT.md exists | FOUND |
| 01-17-SUMMARY.md exists | FOUND |
| Commit e9b7237 (Task 1) | FOUND |
| Commit ae7d20c (Task 2) | FOUND |
| Commit a954d7d (Task 3) | FOUND |
| Commit c485ff4 (Task 4) | FOUND |
