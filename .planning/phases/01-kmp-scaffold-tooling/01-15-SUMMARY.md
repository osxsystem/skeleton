---
phase: 01-kmp-scaffold-tooling
plan: "15"
status: partial
subsystem: build-infra
tags: [gradle, agp, ksp, kmp, wrapper]

requires:
  - phase: 01-01
    provides: "gradle/wrapper/gradle-wrapper.properties (committed) — referenced gradle-9.5.0-bin.zip but the wrapper script and jar were never committed"
provides:
  - "Working Gradle 9.5.0 wrapper (./gradlew bootstraps and prints `Gradle 9.5.0`)"
  - "Root build.gradle.kts plugins block compiles cleanly under Gradle 9.5.0"
  - "KSP plugin version pinned to a real, published artifact (2.3.7)"
  - "AGP 9 / kotlin.multiplatform extension conflict bypassed via gradle.properties flags"
  - "Newly identified BI-F (KMP android{} DSL migration) documented for follow-up plan 01-16"
affects: [01-14, 01-16, ci.yml]

tech-stack:
  added: []
  patterns:
    - "Wrapper artifacts generated via empty temp project to avoid project-side plugin conflicts"
    - "AGP 9 temporary-bypass flags (android.builtInKotlin=false, android.newDsl=false) until proper migration"

key-files:
  created:
    - "gradlew"
    - "gradlew.bat"
    - "gradle/wrapper/gradle-wrapper.jar"
    - ".planning/phases/01-kmp-scaffold-tooling/01-15-SUMMARY.md"
  modified:
    - "build.gradle.kts (root)"
    - "gradle/libs.versions.toml"
    - "gradle.properties"
    - ".planning/phases/01-kmp-scaffold-tooling/01-HUMAN-UAT.md"

key-decisions:
  - "Generated wrapper from an empty temp project rather than the live tree (live tree's plugins block tripped AGP 9 + KMP conflicts during the wrapper task's project evaluation)"
  - "Bumped KSP `2.3.21-2.0.4` (legacy KSP1 naming, never published) to `2.3.7` (latest published KSP for Kotlin 2.3.x line)"
  - "Used AGP 9 temporary-bypass flags rather than restructure androidApp — restructuring deferred to a planned migration"

patterns-established:
  - "Build-infra defects (BI-A through BI-F) are tracked in 01-HUMAN-UAT.md `## Pre-Flight Build-Infra Gate` + the structured `## Gaps` YAML"
  - "Atomic per-defect commits (one BI-x close per commit) for easy revert and audit"

requirements-completed:
  - "SCAF-01 (partial — wrapper boots and root plugins resolve; assembleDebug still gated by BI-F)"

duration: ~90min
completed: 2026-05-09
---

# Phase 01 / Plan 15: Build-Infra Gap Closure (PARTIAL)

**Five build-infra defects (BI-A/B/C/D/E) closed; sixth defect (BI-F: KMP `android{}` DSL incompatible with AGP 9) discovered and documented for a follow-up plan. Android `assembleDebug` smoke gate remains blocked.**

## Performance

- **Duration:** ~90 min (interactive, user-checkpointed)
- **Started:** 2026-05-09 (after `--gaps-only` invocation on phase 01)
- **Completed:** 2026-05-09 (stopped at BI-F discovery per user direction)
- **Tasks attempted:** 3 of 3 (Tasks 1 + 2 fully closed plus 2 out-of-scope inline fixes; Task 3 partially completed — UAT updated, smoke not green)
- **Files modified:** 7

## Accomplishments

- **BI-A + BI-B closed**: `gradlew`, `gradlew.bat`, `gradle/wrapper/gradle-wrapper.jar` generated and committed; `./gradlew --version` prints `Gradle 9.5.0` after bootstrap.
- **BI-C closed**: Root `build.gradle.kts` no longer carries the bare versionless `kotlin("jvm") apply false`. Catalog alias `libs.plugins.kotlin.jvm` introduced and `gradle/libs.versions.toml` extended.
- **BI-D closed (out of original scope, user-authorized)**: KSP version reconciled — `ksp = "2.3.21-2.0.4"` (which never existed upstream; legacy KSP1 `<kotlin>-<ksp>` naming) → `ksp = "2.3.7"` (Maven Central latest for the 2.3.x line).
- **BI-E closed (out of original scope, user-authorized)**: AGP 9 + `kotlin.multiplatform` extension conflict bypassed with `android.builtInKotlin=false` + `android.newDsl=false` in `gradle.properties`. Configuration phase now passes the `Cannot add extension with name 'kotlin'` and `ApplicationExtensionImpl cannot be cast to BaseExtension` failures.
- **BI-F discovered and documented**: KMP modules use the pre-AGP-9 top-level `android { namespace; defaultConfig; compileOptions }` block which is no longer valid on `KotlinMultiplatformExtension`. Compilation of `shared-app/build.gradle.kts:39-49` fails with `Unresolved reference: defaultConfig / compileOptions / sourceCompatibility / targetCompatibility`. Plan 01-16 (AGP 9 KMP DSL migration) recommended.

## Task Commits

1. **Task 2 (Step 1) — BI-C source fix** — `dcee746` (`fix(01-15): close BI-C — replace bare kotlin("jvm") with libs.plugins.kotlin.jvm catalog alias`)
2. **Out-of-scope inline — BI-D KSP version** — `d4859b5` (`fix(01-15): close BI-D — set ksp = 2.3.7 (was 2.3.21-2.0.4, which never existed upstream)`)
3. **Task 1 — BI-A + BI-B wrapper artifacts** — `7e20b82` (`feat(01-15): close BI-A/BI-B — add Gradle 9.5.0 wrapper`)
4. **Out-of-scope inline — BI-E AGP 9 bypass flags** — `fad8968` (`fix(01-15): close BI-E — set android.builtInKotlin=false + android.newDsl=false`)
5. **Task 3 (partial) — UAT update + plan summary** — pending (this commit)

## Files Created/Modified

- `gradlew`, `gradlew.bat`, `gradle/wrapper/gradle-wrapper.jar` — newly committed Gradle 9.5.0 wrapper artifacts; gradle-wrapper.properties was unchanged.
- `build.gradle.kts` — line 3 changed from `kotlin("jvm") apply false` to `alias(libs.plugins.kotlin.jvm) apply false`.
- `gradle/libs.versions.toml` — added `kotlin-jvm = { id = "org.jetbrains.kotlin.jvm", version.ref = "kotlin" }` to `[plugins]`; bumped `ksp = "2.3.7"`.
- `gradle.properties` — added `android.builtInKotlin=false` and `android.newDsl=false` with explanatory comments.
- `.planning/phases/01-kmp-scaffold-tooling/01-HUMAN-UAT.md` — Pre-Flight Build-Infra Gate marked closed for A/B/C, augmented with D/E close notes and new BI-F blocker section; `## Gaps` YAML updated to current state.

## Verification

- `./gradlew --version` → prints `Gradle 9.5.0` ✓
- `grep 'libs.plugins.kotlin.jvm' build.gradle.kts` → match ✓
- `grep 'kotlin-jvm' gradle/libs.versions.toml` → match ✓
- `grep 'kotlin("jvm")' build.gradle.kts | wc -l` → 0 ✓
- `./gradlew :androidApp:tasks` → **FAIL** (BI-F: shared-app DSL incompat) ⛔
- `./gradlew :androidApp:assembleDebug` → not run (gated on BI-F)
- `grep -c 'CLOSED by 01-15' 01-HUMAN-UAT.md` → 5 (A, B, C, D, E) ✓

## Discoveries Beyond Plan Scope

The gap closure surfaced three issues that were never in scope of plan 01-15:

1. **BI-D — KSP `2.3.21-2.0.4` is a phantom version.** The CLAUDE.md tech stack table uses the KSP1 `<kotlin>-<ksp>` naming pattern. KSP2 (default since 2.0.0) publishes plain semver. Maven Central, plugins.gradle.org, and Google Maven all top out at 2.3.7 for the 2.3.x line. **Follow-up doc fix needed in CLAUDE.md.**

2. **BI-E — AGP 9 built-in Kotlin conflicts with `kotlin.multiplatform`.** AGP 9.0+ enables built-in Kotlin and a new ApplicationExtension DSL by default. Both clash with the existing module shape (`androidApp` applies `com.android.application` + `kotlin.multiplatform`). Closed via the upstream-recommended temporary bypass; **long-term fix is architectural** — see https://kotl.in/gradle/agp-new-kmp.

3. **BI-F — KMP `android{}` DSL is not on `KotlinMultiplatformExtension`.** With BI-E bypassed, configuration phase reaches the build scripts of the shared-* modules, which use the pre-AGP-9 top-level `android { … }` shape. Migration to the new shape (`androidLibrary { … }` or `kotlin { android { … } }` per the new API) is required. Source-set layout v2 was also warned about. Estimated 3 build.gradle.kts files affected, plus possible source-set directory moves.

## Recommendation

- Open plan **01-16: AGP 9 KMP DSL migration** via `/gsd-plan-phase`. Scope:
  - Migrate `android {}` blocks in `shared-app`, `shared-core`, `shared-components` to AGP 9 shape.
  - Address source-set layout v2 warning for `androidApp`.
  - Run `./gradlew :androidApp:assembleDebug` smoke as the closing gate.
  - Decide long-term direction for BI-E (remove `kotlin.multiplatform` from `androidApp`, OR restructure androidApp to `com.android.kotlin.multiplatform.library`) — until then keep the bypass flags.
- Open a doc-only follow-up to update `CLAUDE.md` tech stack table: KSP `2.3.21-2.0.4` → `2.3.7`, drop the obsolete KSP1 naming language.
- Plan **01-14** is now blocked by BI-F (Android smoke + iOS Tests 1–7 cannot run until BI-F is closed). Resume `--gaps-only` after 01-16 lands.

## Status

**PARTIAL.** Plan 01-15's `must_haves.truths` cannot all be satisfied yet:
- ✓ `./gradlew --version` prints `Gradle 9.5.0`
- ✓ `./gradlew :server:tasks --no-daemon` no longer fails on `UnknownPluginException` (now blocked further down by BI-F before reaching `:server`)
- ⛔ `./gradlew :androidApp:assembleDebug --no-daemon` does not exit 0 — BI-F gate
- ✓ `01-HUMAN-UAT.md` Pre-Flight Build-Infra Gate marks BI-A/B/C closed (plus BI-D/E noted; BI-F surfaced)

Plan 01-15 is closed in PARTIAL state pending 01-16; 01-14 remains blocked.
