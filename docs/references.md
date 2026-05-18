# Reference open-source projects

Curated for the `skeleton` KMP architecture (shared Kotlin logic + **native** Compose/SwiftUI UIs, SKIE interop, Ktor + SQLDelight + Koin, StateFlow ViewModels, design tokens in `shared/commonMain`).

Compiled 2026-05-08 via WebSearch. Context7 was not available at compile time; when it is, this file should be revisited so each library section can be backed by live, version-pinned documentation.

---

## Tier 1 — direct architectural match

### Kotlin/KMP-App-Template-Native
- URL: https://github.com/Kotlin/KMP-App-Template-Native
- Maintainer: JetBrains
- Stack overlap: native Compose + SwiftUI, shared business logic, Ktor, no Compose Multiplatform.
- Why it ranks first: official template that explicitly chose the same path the skeleton does (UI implemented twice, shared everything else). Cleanest reference for module layout and the "what goes where" question.
- What to study: `shared/build.gradle.kts`, the `iosApp` SPM/framework wiring, the bridge points where SwiftUI consumes Kotlin observables.
- Gap relative to skeleton: no design-token layer; SKIE not enabled by default in older revisions of this template — verify the current `main` before copying Gradle config.

### touchlab/KaMPKit
- URL: https://github.com/touchlab/KaMPKit
- Architecture doc: https://github.com/touchlab/KaMPKit/blob/main/docs/GENERAL_ARCHITECTURE.md
- Maintainer: Touchlab (the company behind SKIE)
- Stack overlap: very high — Koin (`coreModule` / `platformModule` split), SQLDelight (with `AndroidSqliteDriver` / `NativeSqliteDriver`), Ktor, StateFlow ViewModels, integrated SKIE.
- Why it ranks: written and maintained by the team that wrote SKIE. Treat it as the canonical pattern set unless you have a reason to deviate.
- What to study:
  - DI module split (mirrors the "platform actuals" split the skeleton describes).
  - The Android-side ViewModel inheritance trick (Android consumes the common ViewModel directly; iOS gets a SKIE-bridged version).
  - The migration commit that pulled in SKIE — diff is short and instructive.
- Gap relative to skeleton: no design-token layer.

### Kotlin/kmp-production-sample
- URL: https://github.com/Kotlin/kmp-production-sample
- Maintainer: JetBrains. Shipped to App Store and Google Play.
- Stack overlap: native SwiftUI + Compose for mobile; also targets Compose Desktop and React for web from the same shared code.
- Why it ranks: real production constraints (real network errors, real persistence, navigation across many screens). Use it to sanity-check that your stub VM evolves cleanly into a multi-screen production app.
- What to study: error handling at the Repository boundary; navigation entry points on each platform.
- Gap relative to skeleton: design tokens not separated as primitives.

---

## Tier 2 — strong adjacent references

### joreilly/PeopleInSpace
- URL: https://github.com/joreilly/PeopleInSpace
- Maintainer: John O'Reilly (Google Developer Expert for Kotlin)
- Notable: native Compose + SwiftUI plus Wear, Desktop, and Web targets — the breadth is the value.
- What to study: Gradle config for many targets simultaneously, Koin patterns, Ktor client setup. If the skeleton ever sprouts a Wear or Desktop variant, this is the prior art.

### russhwolf/To-Do
- URL: https://github.com/russhwolf/To-Do
- Maintainer: Russ Wolf (author of `multiplatform-settings`)
- Why it's useful: smallest end-to-end example with the exact "shared logic + Compose + SwiftUI" framing. Read this first if onboarding a new collaborator.

### touchlab/SKIEDemoSample
- URL: https://github.com/touchlab/SKIEDemoSample
- Maintainer: Touchlab
- Use it for: SKIE Gradle plugin configuration, sealed-class-as-Swift-enum demonstrations, Flow → AsyncSequence patterns. The skeleton's iOS adapter relies entirely on SKIE — this is the source of truth for what's idiomatic.

---

## Tier 3 — advanced / niche

### Appmilla/ComposablePresenterCounter
- URL: https://github.com/Appmilla/ComposablePresenterCounter
- Pattern: Molecule + SKIE with separate `events` / `state` channels.
- When to come back to it: if and when the StateFlow ViewModel pattern starts feeling cramped (e.g., you want unidirectional event flow that doesn't leak into the View layer). Not needed for v1.

### Kotlin/kmp-logic-sharing-simple-example
- URL: https://github.com/Kotlin/kmp-logic-sharing-simple-example
- Use it for: absolute-minimum sanity check. Useful if a Gradle problem in the skeleton looks structural and you want a known-good comparison.

---

## Tools to know about (not full samples)

### icerockdev/moko-resources
- URL: https://github.com/icerockdev/moko-resources
- What it does: shared image/string resources accessible from both Compose and SwiftUI.
- Relevance: complementary to the design-token layer. Tokens cover sizing/color/typography primitives; moko-resources covers the actual asset files. Worth evaluating for v2 if the product needs branded imagery.

---

## Gap analysis: what the public references DON'T cover

The skeleton's README commits to a **design-token layer in `shared/commonMain`** — `Long` / `Float` / `Int` primitives in `object`s, with platform adapters mapping them to Compose `MaterialTheme` and SwiftUI `Color`/`Font`.

After surveying the references above, this pattern is **not strongly represented** in any of them:

- KaMPKit, PeopleInSpace, the JetBrains templates: no shared token layer. UI styling is per-platform, idiomatic to each.
- Compose Multiplatform projects do have shared theming, but they share the *Compose UI* itself — that's a different shape from what the skeleton wants.
- The pattern shows up in Medium articles (token classes + `CompositionLocalProvider` on the Compose side) but no flagship repo demonstrates the full Compose + SwiftUI fan-out from primitives.

**Implication for the doc-upgrade phase:** the design-token chapter of the eventual docs is original work, not summarisation. It needs to be written carefully because there's no public example to point developers at.

---

## Proposed structure for the next-phase docs

Suggesting a `docs/` directory with these chapters, each one anchored to references above plus (eventually) Context7-pulled live docs for the named libraries:

1. **`docs/architecture.md`** — expanded version of the README's architecture section. References: KaMPKit's GENERAL_ARCHITECTURE.md, kmp-production-sample.
2. **`docs/design-tokens.md`** — original work, no good public reference. Document the `Long` ARGB choice, the `TextStyleToken` shape, the platform-adapter contract, and a worked example of adding a new token.
3. **`docs/skie-interop.md`** — the Kotlin↔Swift bridge. References: SKIEDemoSample, Touchlab Flows-in-SwiftUI docs.
4. **`docs/state-management.md`** — StateFlow VM pattern, lifecycle on each platform. References: KaMPKit's ViewModel inheritance approach.
5. **`docs/data-layer.md`** — Ktor + SQLDelight + repositories. References: PeopleInSpace, KaMPKit.
6. **`docs/di.md`** — Koin module split. Reference: KaMPKit `coreModule`/`platformModule`.
7. **`docs/conventions.md`** — coding conventions, expanding the README's "Conventions" bullet list with examples and lint configuration when ktlint/detekt land.
8. **`docs/decisions/`** — ADRs for the choices the README marks "to revisit per real project" (SQLDelight vs Room-KMP; Koin vs Kotlin-Inject; Navigation 3 vs Decompose).

Each chapter should: state the principle, point to the relevant tier-1 or tier-2 reference, and call out where the skeleton intentionally deviates.
