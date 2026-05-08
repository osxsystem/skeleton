# Phase 1: KMP Scaffold + Tooling - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-08
**Phase:** 1-kmp-scaffold-tooling
**Areas discussed:** iOS targets, Group ID, Forward-loaded toolchain, Sample feature shape

---

## Gray Area Selection

| Option | Description | Selected |
|--------|-------------|----------|
| Sample feature shape | What concretely satisfies SCAF-06 (sample VM resolvable from both DI graphs), SCAF-08 (SQLDelight hello-world query), and SCAF-10 (one commonTest)? | ✓ |
| Forward-loaded toolchain | Wire risky later-phase toolchain in Phase 1 to surface integration pain early — KMMBridge, vanniktech, `:server`, Compose Nav 3 — vs keep Phase 1 strictly to 'compiles green'. | ✓ |
| Group ID strategy | Use placeholder `dev.skeleton` and rename at Phase 7, vs commit to a real domain-verified group ID now. | ✓ |
| iOS targets + simulator-arch coverage | Pin all three `iosX64()` + `iosArm64()` + `iosSimulatorArm64()` for full coverage, or drop `iosX64()` since dev hardware and CI runner are arm64. | ✓ |

**User's choice:** All four areas discussed.

---

## iOS targets + simulator-arch coverage

**Q: Which iOS Kotlin targets should `:shared-components` (the umbrella `SkeletonKit` framework) compile for?**

| Option | Description | Selected |
|--------|-------------|----------|
| arm64 + simulatorArm64 only | Drops Intel-Mac support. Faster builds, smaller XCFramework, matches the `macos-14` CI runner. | ✓ |
| All three: x64 + arm64 + simulatorArm64 | KMP default. Lets contributors on Intel Macs run the simulator. ~30% slower builds; matches public KMP samples. | |
| You decide | Let planner / researcher pick. | |

**User's choice:** arm64 + simulatorArm64 only (Recommended)
**Notes:** Skeleton ships in 2026 — Intel Macs are minority hardware; CI runner is `macos-14` Apple Silicon.

---

## Group ID strategy

**Q: Phase 7 requires a domain-verified group ID for Maven Central. Which group ID should Phase 1 commit to?**

| Option | Description | Selected |
|--------|-------------|----------|
| `io.github.<your-username>` now | Maven Central accepts `io.github.<verified-username>` without owning a domain. | |
| Keep `dev.skeleton` placeholder, rename at Phase 7 | Defer the decision; rename PR sweeps every package path at Phase 7. | |
| A real owned domain (you'll provide it) | Cleanest option — same as Maven Central will accept at publish time, no rename ever. | ✓ |

**User's choice:** A real owned domain — provided as `dev.viethung.*` in follow-up
**Notes:** Group ID locks to `dev.viethung`. Package roots: `dev.viethung.core/components/showcase`. iOS bundle prefix: `dev.viethung.skeleton.*`. Domain ownership only required at Phase 7 publish — not now.

---

## Forward-loaded toolchain

**Q: Which later-phase toolchain gets wired in Phase 1 to surface integration pain early vs deferred?**

| Option | Description | Selected |
|--------|-------------|----------|
| vanniktech maven-publish plugin (Phase 7) | Apply now and run `publishToMavenLocal` dry-run in CI. Mitigates Pitfall 22 partially. | ✓ |
| KMMBridge + XCFramework wiring (Phase 7) | Configure KMMBridge from day 1; validates SPM publish path early. | ✓ |
| `:server` Ktor module skeleton (Phase 4) | Empty `:server` module with `/health` route; verifies Ktor server pulls from version catalog. | ✓ |
| None of the above — strict scaffold-only | Phase 1 = SCAF-01..SCAF-11 verbatim, no forward-wiring. | |

**User's choice:** All three forward-wired.
**Notes:** Aggressive front-loading accepted to surface publish-toolchain pain before Phase 7's immutable-Maven-Central window.

### Follow-up: KMMBridge dry-run shape

**Q: For Phase 1 KMMBridge validation, what's the target?**

| Option | Description | Selected |
|--------|-------------|----------|
| Local-path-only dry run | KMMBridge writes XCFramework to `build/spm/`; no remote push, no GitHub repo. | ✓ |
| Empty companion GitHub repo now | Sibling `skeleton-spm` repo with CI write token; full publish flow on a `0.0.0-test` tag. | |
| You decide later | Planner picks based on CI complexity. | |

**User's choice:** Local-path-only dry run (Recommended)
**Notes:** Real SPM repo push deferred to Phase 7.

---

## Sample feature shape

**Q: SCAF-06 (sample VM), SCAF-08 (SQLDelight hello-world), and SCAF-10 (one commonTest) all need a concrete placeholder. What shape?**

| Option | Description | Selected |
|--------|-------------|----------|
| One cohesive `Greeting` feature | Single `GreetingViewModel` reads one row from a `greeting` SQLDelight table; commonTest drives `Loading → Ready`. SCAF-06/08/10 hit the same stub. | ✓ |
| Three isolated stubs | `PingViewModel` (no DB), separate `dummy` table, trivial pure-function commonTest. No coupling. | |
| Minimal: a `Hello` value class + commonTest only | Defer SCAF-06/08 to Phases 2/3. Phase 1 = just-compile + test-runner. | |

**User's choice:** One cohesive `Greeting` feature (Recommended)
**Notes:** `Greeting` becomes the canonical "how a feature is structured" reference — VM in `:shared-app`, schema in `:shared-core/sqldelight/`, commonTest in `:shared-app`, Compose + SwiftUI screens render the state.

---

## Claude's Discretion

User answered "I'm ready for context" — declined to explore additional gray areas. The following implementation choices are left to the planner with reasonable defaults pre-selected in CONTEXT.md:

- **SQLDelight iOS driver:** `NativeSqliteDriver` + `linkerOpts.add("-lsqlite3")` chosen as default (D-18); `BundledSQLiteDriver` is the fallback if linker flag friction emerges.
- **`@Throws` convention scope:** convention applied to every public suspend function exposed across the iOS bridge (D-19); enforcement via code-review checklist, no static check yet.
- **SKIE generics validation gate:** CI step greps `SkeletonKit.framework/Headers/*.h` for `Any?` patterns (D-16); planner finalizes the exact regex / failure message.
- **Koin module split:** KaMPKit pattern (`coreModule` + `platformModule`) is the preferred reference per research; planner finalizes module boundaries.
- **Compose Navigation 3 wiring:** deferred to Phase 5 — Phase 1 uses `setContent { }` with no NavHost.
- **Compose screen for `Greeting`:** planner decides whether to render a minimal Compose screen or expose the VM via Koin only; recommended to render so `collectAsStateWithLifecycle()` is end-to-end exercised.

## Deferred Ideas

- Real Maven Central credentials + signing key + Sonatype OSSRH ticket — Phase 7.
- KMMBridge SPM repo push to a companion GitHub repo + CI write token — Phase 7.
- `POST /token` and `POST /send` Ktor routes in `:server` — Phase 4.
- Compose Navigation 3 NavHost — Phase 5.
- Design tokens / `MaterialTheme` and SwiftUI environment plumbing — Phase 2.
- Form, amount-input, in-app notification, drawer ViewModels — Phases 3 and 5.
- iOS device push verification — Phase 4.
- Final `dev.viethung` domain ownership / DNS setup — required before Phase 7 publish.
- `architecture.md` / `docs/ARCHITECTURE.md` deeper doc reconciliation — Phase 6/7 doc pass; Phase 1 only adds the single-`shared/` → 3-module note (D-21).
