# Phase 1: KMP Scaffold + Tooling - Context

**Gathered:** 2026-05-08
**Status:** Ready for planning

<domain>
## Phase Boundary

A multi-module Gradle project (`:shared-core`, `:shared-components`, `:shared-app`, `:androidApp`, `:server`) and an Xcode project compile green on both platforms with the fully locked toolchain wired in. Every infrastructure concern — AGP 9 KMP plugin, Koin DI, Ktor client stub, SQLDelight stub, SKIE, `kotlin.test` harness, `IosViewModelStoreOwner` lifecycle, CI on `ubuntu-latest` + `macos-14` — is correct before any feature code is written. A single cohesive `Greeting` placeholder exercises the VM + Koin + SQLDelight + commonTest seams end-to-end. Maven publish (vanniktech) and SPM publish (KMMBridge) are wired and dry-run validated locally — no remote publish.

**In scope:** SCAF-01..SCAF-11 (REQUIREMENTS.md). Plus three forward-loaded scaffolds: `:server` Ktor module shell, vanniktech maven-publish dry-run, KMMBridge XCFramework dry-run.
**Out of scope:** any user-visible feature, design tokens (Phase 2), the four component families (Phase 3+), real Maven Central / SPM publish (Phase 7).

</domain>

<decisions>
## Implementation Decisions

### iOS targets
- **D-01:** iOS Kotlin targets are `iosArm64()` + `iosSimulatorArm64()` only. **`iosX64()` is dropped.** Rationale: dev hardware and CI runner (`macos-14`) are Apple Silicon; Intel-Mac developers are minority. Cuts XCFramework slices from 3 to 2; ~30% faster iOS build.
- **D-02:** iOS deployment target is `17.0` (CLAUDE.md, locked).

### Group ID / namespace
- **D-03:** Group ID is **`dev.viethung`** — committed from day 1 in `gradle/libs.versions.toml`, every `commonMain/kotlin/dev/viethung/...` package path, and the iOS bundle ID prefix (`dev.viethung.skeleton.*`). Replaces the `dev.skeleton` placeholder. Rationale: domain-backed coordinate that Maven Central will accept at Phase 7 publish; no rename PR ever.
- **D-04:** Package layout: `dev.viethung.core.*` in `:shared-core`, `dev.viethung.components.*` in `:shared-components`, `dev.viethung.showcase.*` in `:shared-app`, `dev.viethung.skeleton.android.*` in `:androidApp`. iOS Swift code uses `import SkeletonKit` (the framework `baseName`).
- **D-05:** Domain ownership of `viethung.dev` is required only at Phase 7 publish — not now.

### Forward-loaded toolchain
- **D-06:** **vanniktech maven-publish `0.36.0`** is applied to `:shared-core` and `:shared-components` in Phase 1. CI runs `./gradlew publishToMavenLocal` and asserts the artifacts are emitted to `~/.m2/repository/dev/viethung/`. No remote publish; no signing key required yet. Rationale: Pitfall 22 (Maven Central duplicate publish) is partly mitigated by exercising the publish path early; immutable Maven Central makes Phase-7-only validation expensive.
- **D-07:** **KMMBridge `1.1.0`** is wired to `:shared-components` in Phase 1, but emits the `SkeletonKit.xcframework` to a **local Gradle path (`build/spm/`)** only — no companion GitHub repo, no SPM repo push, no CI write-token. CI verifies the XCFramework is produced and `Package.swift` is generated. Real SPM repo push deferred to Phase 7.
- **D-08:** **`:server` Ktor module skeleton** is created in Phase 1 with `ktor-server-cio 3.4.0`, `ktor-server-content-negotiation 3.4.0`, `ktor-serialization-kotlinx-json 3.4.0`. Exposes one `/health` route returning 200 OK. `./gradlew :server:run` starts it on `localhost:8080`. The `:server` module is **never published**. Real `POST /token` and `POST /send` routes belong in Phase 4.
- **D-09:** Fallback if KMMBridge maintenance fails before Phase 7: switch to `ge-org/multiplatform-swiftpackage`. Same XCFramework → SPM flow; track `touchlab/KMMBridge` activity.

### Sample feature shape
- **D-10:** A single cohesive **`Greeting` feature** satisfies SCAF-06 (sample VM resolvable from both Koin graphs), SCAF-08 (SQLDelight hello-world query), and SCAF-10 (one passing `commonTest`):
  - `greeting` SQLDelight table with one row (`message TEXT NOT NULL`) and one query (`SELECT message FROM greeting WHERE id = 1`).
  - `GreetingViewModel : ViewModel()` exposing `StateFlow<UiState>` with `Loading` / `Ready(String)` / `Error(String)` variants.
  - `commonTest` drives the VM through `Loading → Ready("Hello, KMP")` using `kotlinx-coroutines-test` + Turbine.
  - Compose screen in `:androidApp` and SwiftUI screen in `iosApp/` each render the state.
- **D-11:** Greeting placement: `greeting` SQLDelight schema in `:shared-core/sqldelight/` (alongside the SQLDelight driver scaffold); `GreetingViewModel`, repository, use case, Koin wiring, and commonTest in `:shared-app` (showcase-only, never published). Keeps `:shared-core` and `:shared-components` free of placeholder content.

### Pitfall mitigations (Phase 1 owns these)
- **D-12:** `IosViewModelStoreOwner` declared `@StateObject` (never `@ObservedObject`); `deinit` calls `viewModelStore.clear()` and logs a `[IosViewModelStoreOwner] deinit cleared store` line. A manual smoke step in Phase 1 verifies the log fires on navigation pop. (Pitfall 1 + 2; SCAF-05.)
- **D-13:** `libs.versions.toml` pins **Kotlin 2.3.21 / KSP 2.3.21-2.0.4 / AGP 9.2.0 / SKIE 0.10.11** as a single block with the literal comment `# Update these four together` immediately above it (SCAF-04; Pitfall 3).
- **D-14:** All KMP modules apply **`com.android.kotlin.multiplatform.library`**, never `com.android.library` (Pitfall 20; SCAF-03).
- **D-15:** iOS framework **`baseName = "SkeletonKit"`**, never `"shared"`. iOS code does `import SkeletonKit`. (Pitfall 21; SCAF-02.)
- **D-16:** SKIE generics validation gate: a CI step greps `SkeletonKit.framework/Headers/*.h` for `Any?` patterns in the sample sealed `UiState` signature. Fails the build if found. (Pitfall 4; SCAF-11.)
- **D-17:** `kotlin.test` harness imports `kotlin.test.Test` — not `org.junit.Test`. Enforced by a `commonTest` source-set rule. (Pitfall 18; SCAF-10.)
- **D-18:** SQLDelight iOS driver: **`NativeSqliteDriver` with the `-lsqlite3` linker flag** added in `iosX.binaries.framework { linkerOpts.add("-lsqlite3") }`. (Not `BundledSQLiteDriver` — keeps the framework slim; flag is a one-line cost.) (Pitfall 19; SCAF-08.)
- **D-19:** `@Throws(CancellationException::class, Exception::class)` is added to **every public suspend function exposed in the iOS-bridged surface**. Convention enforced by code-review checklist; no static check in Phase 1. (Pitfall 5.)
- **D-20:** CI iOS job pins `runs-on: macos-14` (not `macos-latest`) and sets `timeout-minutes: 30`. Runs `iosSimulatorArm64Test` as a **separate step** from the build, so simulator-flake failures are visible distinctly. (Pitfall 23; SCAF-09.)

### Documentation reconciliation
- **D-21:** `architecture.md` (in repo root) describes a **single `shared/` module**, while ROADMAP/REQUIREMENTS lock a **3-module split** (`:shared-core`, `:shared-components`, `:shared-app`). The roadmap shape is canonical (SCAF-01..03). Phase 1 plan must include a one-line update to `architecture.md` noting the multi-module shape and pointing at `.planning/REQUIREMENTS.md` SCAF-01 as the authority.

### Toolchain pinning
- **D-22:** **JDK 21** is the Gradle daemon + compilation target. Phase 1 commits a `.tool-versions` file (or equivalent) so a fresh clone uses the right JDK without manual setup.
- **D-23:** Gradle **9.5.0** with **configuration cache enabled** (preferred execution mode in Gradle 9). `gradle.properties` sets `org.gradle.configuration-cache=true`.

### Claude's Discretion
- Exact Compose Navigation 3 wiring in `:androidApp`: deferred — Phase 5 introduces real navigation. Phase 1 may use a single-screen `setContent {}` with no NavHost.
- Whether to scaffold a placeholder `:shared-app` Compose screen vs. just expose the VM via Koin: planner decides. Recommend a minimal Compose screen rendering the `Greeting` to validate `collectAsStateWithLifecycle()` end-to-end.
- Koin module shape (one big `coreModule` vs split `coreModule` + `platformModule` per KaMPKit pattern): planner decides — KaMPKit split is the safer default and SUMMARY.md endorses it.
- `BundledSQLiteDriver` vs `NativeSqliteDriver` was decided in **D-18** in favor of native driver + linker flag. Planner can revisit if the linker flag causes Xcode-side friction.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project requirements + roadmap
- `.planning/PROJECT.md` — Skeleton project goals, constraints, key decisions table; "Out of Scope" section is authoritative for what NOT to add.
- `.planning/REQUIREMENTS.md` §SCAF — SCAF-01..SCAF-11 are the binding success criteria for Phase 1. Re-read every requirement before sub-planning.
- `.planning/ROADMAP.md` §"Phase 1: KMP Scaffold + Tooling" — Goal, depends-on, requirements, success criteria, pitfall refs (1–5, 18–21, 23).
- `.planning/STATE.md` — Current phase + accumulated decisions log.

### Architecture + research
- `.planning/research/SUMMARY.md` — Authoritative pre-planning research; especially "Phase 1: KMP Scaffold + Tooling Foundation" section and the "Key Findings → Recommended Stack" table.
- `.planning/research/STACK.md` — Validated `libs.versions.toml` block; do not deviate from versions without re-running research.
- `.planning/research/PITFALLS.md` — Detailed pitfall write-ups; Phase 1 must address Pitfalls 1, 2, 3, 4, 5, 18, 19, 20, 21, 23.
- `.planning/research/ARCHITECTURE.md` — Module shape rationale and umbrella-framework pattern.
- `.planning/research/FEATURES.md` — Feature-level expectations across all phases.
- `architecture.md` (repo root) — Locked MVVM + StateFlow + UDF pattern; iOS `IosViewModelStoreOwner` contract; **note the single-`shared/` shape is superseded by SCAF-01..03's 3-module split — Phase 1 plan updates this file (D-21).**
- `docs/ARCHITECTURE.md` — Generated companion to `architecture.md`; same pattern, same reconciliation note applies.
- `docs/references.md` — Tier-1 reference projects: KMP-App-Template-Native (JetBrains), KaMPKit (Touchlab), kmp-production-sample (JetBrains). Use KaMPKit as the canonical pattern set per its SKIE provenance.

### Project-level conventions
- `CLAUDE.md` (repo root) — Locked tech stack table, library versions (authoritative), "What NOT to Use" table, version compatibility matrix.
- `README.md` — Project overview; mirrors `architecture.md` at a higher level.
- `CONTRIBUTING.md` — Contributor process if relevant to CI conventions.

### External (canonical, version-pinned per CLAUDE.md)
- JetBrains KMP ViewModel docs — `https://kotlinlang.org/docs/multiplatform/compose-viewmodel.html`
- Google KMP ViewModel guide — `https://developer.android.com/kotlin/multiplatform/viewmodel` (especially the `IosViewModelStoreOwner` example)
- AGP 9.2.0 release notes — `https://developer.android.com/build/releases/agp-9-2-0-release-notes`
- SKIE docs — `https://skie.touchlab.co/`
- KMMBridge docs — `https://kmmbridge.touchlab.co/docs/`
- vanniktech maven-publish — `https://github.com/vanniktech/gradle-maven-publish-plugin/releases`
- KaMPKit reference — `https://github.com/touchlab/KaMPKit`

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- None on disk yet — repo is in design phase. `compose-multiplatform-core/` is a **read-only reference checkout** of AndroidX/Compose libraries. Useful for looking up library internals (e.g., `lifecycle/` source, `navigation/` Nav3). **Do not depend on it from Gradle; do not include it in the KMP project tree.** Add `compose-multiplatform-core/` to `settings.gradle.kts` exclusion or simply do not register it as a project.

### Established Patterns
- Locked architectural pattern (already canonized in `architecture.md`):
  - MVVM with shared `androidx.lifecycle.ViewModel` in `commonMain`.
  - State via `StateFlow<UiState>`; `UiState` as `sealed interface { Loading; Ready; Error }`.
  - UDF: state down, intents up; views never mutate state.
  - DI via Koin; Hilt is explicitly rejected.
  - SKIE bridges `StateFlow → AsyncSequence` for SwiftUI.
- Locked module-shape pattern (REQUIREMENTS.md):
  - `:shared-core` (api-deps `:shared-core` types via re-export); published.
  - `:shared-components` depends on `:shared-core` via `api`; published.
  - `:shared-app` depends on `:shared-core` + `:shared-components` via `implementation`; never published.
  - iOS umbrella framework compiled from `:shared-components` exporting `:shared-core`.

### Integration Points
- `gradle/libs.versions.toml` — single source of truth for every version; D-13 lockstep block goes here.
- `:shared-components/build.gradle.kts` — KMMBridge plugin block + `framework { baseName = "SkeletonKit"; export(...) }` configuration; `iosArm64()` + `iosSimulatorArm64()` only (D-01).
- `:shared-core/build.gradle.kts` + `:shared-components/build.gradle.kts` — vanniktech `maven-publish` plugin block.
- `iosApp/iosApp/Common/IosViewModelStoreOwner.swift` — `@StateObject` lifecycle, `deinit` clears store with log line (D-12).
- `.github/workflows/ci.yml` — split jobs: `ubuntu-latest` for Gradle build + JVM tests + `publishToMavenLocal`; `macos-14` (timeout-minutes: 30) for `iosSimulatorArm64Test` + XCFramework + KMMBridge dry-run + headers grep gate (D-16).
- `:server/build.gradle.kts` — `ktor-server-cio` config (D-08); never published.

</code_context>

<specifics>
## Specific Ideas

- The `Greeting` feature is a one-string read; `message = "Hello, KMP"` is fine for the seed. The placeholder content matters less than the seam validation.
- KaMPKit's Koin module split (`coreModule` + `platformModule`) is the preferred reference for DI shape — see SUMMARY.md sources.
- Use `BundledSQLiteDriver` only if the `-lsqlite3` linker flag becomes painful; default is `NativeSqliteDriver + linkerOpts.add("-lsqlite3")` (D-18).
- The `# Update these four together` comment must be **literal text** in `libs.versions.toml` — it is verified by Pitfall-3 mitigation review.

</specifics>

<deferred>
## Deferred Ideas

- **Real Maven Central credentials + signing key + Sonatype OSSRH ticket** — Phase 7. Phase 1's `publishToMavenLocal` dry-run does not need them.
- **KMMBridge SPM repo push to a companion GitHub repo + CI write token** — Phase 7. Phase 1 emits to local `build/spm/` only.
- **`POST /token` and `POST /send` Ktor routes in `:server`** — Phase 4. Phase 1 only exposes `/health`.
- **Compose Navigation 3 NavHost wiring** — Phase 5 (drawer phase introduces real navigation).
- **Design tokens / `MaterialTheme` and SwiftUI environment plumbing** — Phase 2.
- **Form, amount-input, in-app notification, drawer ViewModels** — Phases 3 and 5.
- **iOS device push verification (physical device only)** — Phase 4 (sim cannot receive APNs).
- **Final `dev.viethung` domain ownership / DNS setup** — must be resolved before Phase 7 publish, but not now.
- **Decompose / Molecule** — explicitly rejected in CLAUDE.md "What NOT to Use"; reaffirmed.
- **Document conflict cleanup** for any `architecture.md` / `docs/ARCHITECTURE.md` drift beyond the single-`shared/` → 3-module note — Phase 6/7 doc pass.

</deferred>

---

*Phase: 1-kmp-scaffold-tooling*
*Context gathered: 2026-05-08*
