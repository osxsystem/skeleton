---
phase: 01-kmp-scaffold-tooling
plan: "16"
status: partial
subsystem: build-infra
tags: [gradle, agp, kmp, kotlin-multiplatform, skie, kmmbridge, android-dsl]

requires:
  - phase: 01-15
    provides: "Gradle 9.5.0 wrapper, BI-A/B/C/D/E closed, BI-F discovery with root cause analysis"

provides:
  - "shared-core migrated to AGP 9 KMP DSL: kotlin { android { namespace; compileSdk; minSdk; compilerOptions; withHostTestBuilder {} } }"
  - "shared-components migrated to AGP 9 KMP DSL (same pattern); SKIE disabled (BI-I workaround); addGithubPackagesRepository() removed (BI fixed)"
  - "shared-app migrated to AGP 9 KMP DSL (same pattern); withHostTestBuilder {} wired"
  - "androidApp: kotlin.multiplatform removed; Compose Compiler plugin added inline; BI-E bypass flags reverted from gradle.properties"
  - "01-HUMAN-UAT.md updated with BI-F partial close + BI-G/BI-H/BI-I newly discovered"

affects: [01-14, 01-17, ci.yml]

tech-stack:
  added:
    - "id(\"org.jetbrains.kotlin.plugin.compose\") version \"2.3.21\" — added inline to androidApp/build.gradle.kts (AGP 9 requires it when compose=true and kotlin.multiplatform is absent)"
  patterns:
    - "AGP 9 KMP library DSL: kotlin { android { namespace; compileSdk; minSdk; compilerOptions { jvmTarget.set(JvmTarget.JVM_21) }; withHostTestBuilder {} } } — removes top-level android{} block, removes androidTarget() call"
    - "withHostTestBuilder {} is mandatory to wire commonTest JVM host tests under com.android.kotlin.multiplatform.library"
    - "For com.android.application + Compose: id(\"org.jetbrains.kotlin.plugin.compose\") must be applied explicitly when kotlin.multiplatform is removed"

key-files:
  created: []
  modified:
    - "shared-core/build.gradle.kts — kotlin{android{}} migration; top-level android{} removed"
    - "shared-components/build.gradle.kts — kotlin{android{}} migration; addGithubPackagesRepository() removed; skie { isEnabled = false } added"
    - "shared-app/build.gradle.kts — kotlin{android{}} migration; withHostTestBuilder {} confirmed"
    - "androidApp/build.gradle.kts — kotlin.multiplatform removed; Compose Compiler plugin added inline"
    - "gradle.properties — android.builtInKotlin=false and android.newDsl=false removed (BI-E reverted)"
    - ".planning/phases/01-kmp-scaffold-tooling/01-HUMAN-UAT.md — BI-F partial close noted; BI-G/BI-H/BI-I added"

key-decisions:
  - "Used android{} inside kotlin{} instead of androidLibrary{} — AGP 9.2.0 marks androidLibrary{} as deprecated (treated as compile error); android{} is the stable canonical form"
  - "Disabled SKIE (skie { isEnabled = false }) rather than halting — SKIE 0.10.11 does not support Kotlin 2.3.21; this is within shared-components/build.gradle.kts scope; re-enable when SKIE releases 2.3.21 support"
  - "Removed addGithubPackagesRepository() from kmmbridge{} — this function does not exist in KMMBridge 1.1.0 public API; was a pre-existing dead code placeholder for Phase 7 remote wiring"
  - "Added Compose Compiler plugin inline (id version string) rather than via catalog alias — avoids touching libs.versions.toml and build.gradle.kts (root) which are outside 01-16 scope"
  - "Stopped at BI-G (GlobalContext in commonMain) per deviation protocol — GreetingViewModelFactory.kt is outside files_modified list; recording as new defect for follow-up"

patterns-established:
  - "Pre-existing compilation errors surface when BI-F DSL gate is removed — expect a cascade of 'first compilation' bugs"
  - "When a blocking issue exists in out-of-scope files, record as BI-G+ and produce PARTIAL SUMMARY rather than scope-creeping"

requirements-completed:
  - "SCAF-01 (partial — KMP library modules use AGP 9 DSL; assembleDebug still blocked by BI-G)"
  - "SCAF-02 (not achieved — assembleDebug does not exit 0; BI-G blocks)"
  - "SCAF-03 (partial — com.android.kotlin.multiplatform.library plugin applied correctly in all three shared modules)"

duration: ~90min
completed: 2026-05-09
---

# Phase 01 / Plan 16: AGP 9 KMP DSL Migration (PARTIAL)

**AGP 9 `kotlin { android { … } }` DSL applied to all three shared KMP modules and androidApp simplified — assembleDebug still blocked by BI-G (`GlobalContext` in `commonMain`) and BI-I (SKIE 0.10.11 + Kotlin 2.3.21 incompatibility)**

## Performance

- **Duration:** ~90 min
- **Started:** 2026-05-09T11:45:00Z
- **Completed:** 2026-05-09T13:36:03Z
- **Tasks attempted:** 5 of 5 (Tasks 1–4 fully done; Task 5 smoke FAILED — BI-G cascade)
- **Files modified:** 6

## Accomplishments

- **BI-F migration done**: All three KMP library modules (`shared-core`, `shared-components`, `shared-app`) successfully migrated from pre-AGP-9 `android { … }` top-level block to AGP 9's `kotlin { android { … } }` nested form. `androidTarget()` removed from all three. `withHostTestBuilder {}` added to all three (commonTest wiring).
- **androidApp simplified**: `kotlin.multiplatform` plugin removed; Compose Compiler plugin (`id("org.jetbrains.kotlin.plugin.compose") version "2.3.21"`) added inline; BI-E bypass flags (`android.builtInKotlin=false`, `android.newDsl=false`) reverted from `gradle.properties`.
- **`:androidApp:tasks` exits 0**: Configuration phase fully passes for all modules. DSL migration is correct.
- **Three new defects (BI-G, BI-H, BI-I) documented**: Pre-existing compilation errors that were masked by BI-F are now visible and fully characterized with root cause + recommendation.

## Task Commits

1. **Task 1: Migrate :shared-core** — `77e52e8` (feat)
2. **Task 2: Migrate :shared-components** — `5cac60a` (feat)
3. **Task 3: Migrate :shared-app** — `7fadc45` (feat)
4. **Task 4: Drop kotlin.multiplatform from :androidApp + revert BI-E flags** — `7d947e8` (refactor)
5. **Task 5: Partial smoke + UAT update** — `0efd4e2` (docs)

**Plan metadata:** (this commit)

## Files Created/Modified

- `shared-core/build.gradle.kts` — `androidTarget()` removed; top-level `android{}` deleted; `kotlin { android { namespace="dev.viethung.core"; compileSdk=36; minSdk=23; compilerOptions{jvmTarget=JVM_21}; withHostTestBuilder{} } }` added
- `shared-components/build.gradle.kts` — same DSL migration; `androidTarget()` removed; `addGithubPackagesRepository()` removed from `kmmbridge{}`; `skie { isEnabled = false }` added (BI-I workaround); `withHostTestBuilder{}` added
- `shared-app/build.gradle.kts` — same DSL migration; `androidTarget()` removed; `withHostTestBuilder{}` added
- `androidApp/build.gradle.kts` — `alias(libs.plugins.kotlin.multiplatform)` removed; `kotlin { androidTarget() }` block removed; `id("org.jetbrains.kotlin.plugin.compose") version "2.3.21"` added
- `gradle.properties` — `android.builtInKotlin=false` and `android.newDsl=false` removed (BI-E bypass reverted)
- `.planning/phases/01-kmp-scaffold-tooling/01-HUMAN-UAT.md` — BI-F marked partial; BI-G/BI-H/BI-I added to Pre-Flight Gate and Gaps YAML

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `androidLibrary {}` is deprecated — used `android {}` instead**
- **Found during:** Task 1 first Gradle run
- **Issue:** Plan specified `androidLibrary {}` but AGP 9.2.0 reports it as deprecated (treated as compilation error: `'fun KotlinMultiplatformExtension.androidLibrary(...)' is deprecated. Please use 'android' instead`). The `androidLibrary {}` is the old name from an earlier AGP 9.x beta; `android {}` is the stable canonical form in AGP 9.2.0
- **Fix:** All three KMP modules use `android {}` (inside `kotlin {}`) instead of `androidLibrary {}`
- **Files modified:** `shared-core/build.gradle.kts`, `shared-components/build.gradle.kts`, `shared-app/build.gradle.kts`
- **Verification:** `:shared-core:tasks`, `:shared-components:tasks`, `:shared-app:tasks` all exit 0

**2. [Rule 3 - Blocking] `addGithubPackagesRepository()` removed from `kmmbridge {}` in shared-components**
- **Found during:** Task 2 first Gradle run
- **Issue:** `addGithubPackagesRepository()` is not in KMMBridge 1.1.0's public API (`KmmBridgeExtension` interface); was a dead-code placeholder for Phase 7 remote wiring that caused `Unresolved reference` compile error
- **Fix:** Removed the call; kept `spm()` and `frameworkName.set("SkeletonKit")`
- **Files modified:** `shared-components/build.gradle.kts`
- **Verification:** `:shared-components:tasks` exits 0

**3. [Rule 3 - Blocking] SKIE 0.10.11 doesn't support Kotlin 2.3.21 — added `skie { isEnabled = false }`**
- **Found during:** Task 2 Gradle run (after fix #1 and #2)
- **Issue:** SKIE 0.10.11 supports Kotlin up to 2.3.20; Kotlin 2.3.21 used in this project. Error: `SKIE cannot not be used until this error is resolved`. Error occurs during configuration of `:shared-components`, cascading to `:androidApp:tasks`
- **Fix:** Added `isEnabled = false` inside `skie {}` block per upstream recommendation ("add `skie { isEnabled = false }` to your Gradle configuration")
- **Files modified:** `shared-components/build.gradle.kts`
- **Verification:** `:androidApp:tasks` exits 0; configuration phase completes
- **Recorded as BI-I** — permanent fix requires SKIE version upgrade (out of scope; `libs.versions.toml` not in `files_modified`)

**4. [Rule 2 - Missing Critical] Compose Compiler plugin required for :androidApp**
- **Found during:** Task 4 first Gradle run
- **Issue:** When `kotlin.multiplatform` is removed from `com.android.application` module that has `compose = true`, AGP 9 requires explicit `org.jetbrains.kotlin.plugin.compose` plugin. Error: `Starting in Kotlin 2.0, the Compose Compiler Gradle plugin is required when compose is enabled`
- **Fix:** Added `id("org.jetbrains.kotlin.plugin.compose") version "2.3.21"` directly in `androidApp/build.gradle.kts` plugins block (inline, no catalog alias needed)
- **Files modified:** `androidApp/build.gradle.kts`
- **Verification:** `:androidApp:tasks` exits 0

---

**Total deviations:** 4 auto-fixed (1 bug, 2 blocking, 1 missing critical)
**Impact on plan:** All auto-fixes within `files_modified` scope and necessary for correct AGP 9 behavior. No scope creep.

## New Defects Discovered (BI-G, BI-H, BI-I)

These defects were masked by BI-F and surfaced for the first time when compilation actually ran.

### BI-G — BLOCKING — `GlobalContext` in `commonMain` (outside plan scope)

- **Symptom:** `shared-app:compileCommonMainKotlinMetadata` fails: `Unresolved reference 'GlobalContext'` in `GreetingViewModelFactory.kt:6,27`
- **Root cause:** `org.koin.core.context.GlobalContext` is NOT available in Kotlin/Native's `commonMain` metadata compilation or iOS targets. The class exists in the JVM klib but not in the native klib's `package_org.koin.core.context` exports at the `commonMain` level.
- **Impact:** Cascades to `:shared-app:compileKotlinIosArm64`, `:shared-app:compileKotlinIosSimulatorArm64`, and `:androidApp:compileDebugKotlin` (cannot resolve types from `:shared-app`). `assembleDebug` FAILS.
- **Affected file:** `shared-app/src/commonMain/kotlin/dev/viethung/showcase/greeting/GreetingViewModelFactory.kt` — outside plan 01-16 `files_modified`
- **Recommended fix:** Replace `GlobalContext.get().get<GetGreetingUseCase>()` with constructor injection or use `KoinComponent` interface. Since `GreetingViewModelFactory` is only needed for iOS (Android uses ViewModel Compose integration), an alternative is to move it to a non-commonMain source set or change the lookup strategy.
- **Next plan scope:** `shared-app/src/commonMain/kotlin/.../GreetingViewModelFactory.kt` — one-file fix

### BI-H — MAJOR — `GreetingViewModelTest` 2/3 tests fail (outside plan scope)

- **Symptom:** Android JVM host test runs but `loadGreetingTransitionsToReady` and `loadGreetingOnErrorTransitionsToError` fail: `java.lang.AssertionError: No item was found` from `app.cash.turbine.ChannelKt.expectMostRecentItem`
- **Root cause:** `GreetingViewModel.loadGreeting()` uses `viewModelScope.launch {}` which dispatches asynchronously; `expectMostRecentItem()` returns immediately without waiting for the coroutine to complete. `runTest` with `TestCoroutineScheduler` needs `advanceUntilIdle()` between action and assertion.
- **Affected file:** `shared-app/src/commonTest/kotlin/.../GreetingViewModelTest.kt` — outside plan 01-16 scope
- **Recommended fix:** Add `advanceUntilIdle()` from `TestCoroutineScheduler` after `vm.loadGreeting()` call, or replace `expectMostRecentItem()` with `awaitItem()` in a proper collect loop.

### BI-I — BLOCKING (iOS only) — SKIE 0.10.11 + Kotlin 2.3.21 incompatibility

- **Symptom:** SKIE 0.10.11 raises error during configuration: `does not support Kotlin 2.3.21. Supported versions are: [..., 2.3.20]`
- **Workaround applied:** `skie { isEnabled = false }` in `shared-components/build.gradle.kts` (upstream recommendation)
- **Impact of workaround:** Android builds work; SKIE Swift interop generation disabled; `SkeletonKit.xcframework` will not contain SKIE-enhanced Swift interfaces. iOS Tests 1–7 remain blocked on Xcode integration.
- **Affected file:** `shared-components/build.gradle.kts` (workaround in scope), `gradle/libs.versions.toml` (fix requires skie version bump — out of scope)
- **Recommended fix:** Upgrade `skie` version in `libs.versions.toml` to a version supporting Kotlin 2.3.21. Check https://github.com/touchlab/SKIE/releases. If SKIE 0.10.12+ supports 2.3.21, bump and re-enable in `shared-components`.

## Verification Results

| Check | Command | Result |
|-------|---------|--------|
| 1 | `grep -c 'android {' shared-*/build.gradle.kts` | 1 per file (inside kotlin{}) |
| 2 | `grep -c '^android {' shared-*/build.gradle.kts` | 0 (top-level removed) |
| 3 | `grep -c 'androidTarget()' shared-*/build.gradle.kts androidApp/build.gradle.kts` | 0 all |
| 4 | `grep -c 'withHostTestBuilder' shared-*/build.gradle.kts` | 1 per file |
| 5 | `grep -c 'libs.plugins.kotlin.multiplatform' androidApp/build.gradle.kts` | 0 |
| 6 | `grep -c 'android.builtInKotlin|android.newDsl' gradle.properties` | 0 |
| 7 | `:shared-core:tasks :shared-components:tasks :shared-app:tasks :androidApp:tasks` | BUILD SUCCESSFUL |
| 8 | `:shared-app:allTests` | FAILED — BI-G (compileKotlinIosSimulatorArm64) + BI-H (2/3 tests) |
| 9 | `:shared-core:build :shared-components:build :shared-app:build :androidApp:assembleDebug` | FAILED — BI-G cascade |
| 10 | `find androidApp/build/outputs/apk/debug -name '*.apk'` | 0 (assembleDebug did not complete) |
| 11 | `grep -c 'CLOSED by 01-16'` | 0 (BI-F not fully closed; partial noted) |
| 12 | `grep -c 'BI-A through BI-F closed'` | 0 (not all closed) |

## Issues Encountered

- `androidLibrary {}` deprecated in AGP 9.2.0 (plan specified it, but compiler rejects it) → used `android {}` instead (auto-fixed, Rule 1)
- `addGithubPackagesRepository()` not in KMMBridge 1.1.0 API → removed dead code placeholder (auto-fixed, Rule 3)
- SKIE 0.10.11 does not support Kotlin 2.3.21 → disabled SKIE as temporary bypass (auto-fixed within scope, Rule 3; permanent fix requires lib upgrade)
- Compose Compiler plugin required when kotlin.multiplatform removed from androidApp → added inline (auto-fixed, Rule 2)
- `GlobalContext` unresolvable in commonMain compilation → STOPPED (out of scope; BI-G recorded)

## 01-15 Status Note

Plan 01-15 was PARTIAL (BI-F blocking). This plan (01-16) completes the BI-F DSL migration (configuration phase passes, `:*:tasks` exits 0 for all modules). However, BI-G surfaces a new cascade defect that prevents `assembleDebug` from passing. 01-15 therefore remains PARTIAL pending BI-G resolution. 01-14 remains blocked until BI-G and BI-I are fixed.

## Next Phase Readiness

- A dedicated plan is needed to fix `GreetingViewModelFactory.kt` (BI-G) — single file, no architectural change required
- After BI-G fix: `:shared-app:build` and `:androidApp:assembleDebug` should pass
- After SKIE version bump (BI-I): re-enable `skie { isEnabled = true }` in `shared-components` and iOS XCFramework builds resume
- After BI-H fix: all 3 GreetingViewModelTest tests pass
- Then: 01-14 Android smoke gate (Task 3) can proceed

## Status

**PARTIAL.** Plan 01-16's `must_haves.truths` cannot all be satisfied:
- ✓ All three KMP library modules use AGP 9 `kotlin { android { … } }` DSL
- ✓ `androidTarget()` removed from all three KMP library modules
- ✓ `androidApp` no longer applies `org.jetbrains.kotlin.multiplatform`
- ✓ `gradle.properties` no longer contains `android.builtInKotlin=false` or `android.newDsl=false`
- ✓ All `*:tasks` targets exit 0 (configuration phase passes)
- ✗ `./gradlew :androidApp:assembleDebug --no-daemon` does not exit 0 — BI-G gate
- ✗ `./gradlew :shared-app:allTests --no-daemon` does not exit 0 — BI-G + BI-H
- ✗ 01-HUMAN-UAT.md `## Pre-Flight Build-Infra Gate` does not show all six items (A–F) `[x] CLOSED` — BI-F partial only
