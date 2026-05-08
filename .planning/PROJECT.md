# Skeleton

## What This Is

A personal Kotlin Multiplatform mobile-app **skeleton template** — shared Kotlin
business logic, native UI on each platform (Jetpack Compose on Android, SwiftUI
on iOS). The deliverable is a clonable foundation **plus** a library of reusable
native UI components (forms, currency-aware amount input, tree sidebar
navigation, notifications) that any new product cloned from this repo can
consume from day one. A showcase app on both platforms exercises every
component end-to-end.

## Core Value

Cloning this skeleton must give a new product, on day one, a correct
KMP scaffold and the four UI primitives that every mobile product re-implements
badly: forms, amount input, navigation, and notifications.

## Requirements

### Validated

<!-- Shipped and confirmed valuable. -->

(None yet — ship to validate)

### Active

<!-- Current scope. Building toward these. -->

- [ ] Working KMP scaffold per `architecture.md` — `shared/`, `androidApp/`, `iosApp/`, gradle, Koin, Ktor, SQLDelight, SKIE
- [ ] Design-token bridge (light + dark) — `commonMain` primitives mapped to Compose `MaterialTheme` and SwiftUI environment
- [ ] Reusable form component — large/complex forms, field state, validation, error display, on both platforms
- [ ] Currency-aware amount input — locale + currency formatting on entry/display, on both platforms
- [ ] Navigation component — collapsible **tree sidebar** drawer on phones, same drawer larger on tablets
- [ ] In-app notifications component — toasts, banners, snackbars, inline alerts, on both platforms
- [ ] Push notifications end-to-end — FCM (Android) + APNs (iOS) + minimal server stub
- [ ] Networking demo — real Ktor call against a public API in the showcase
- [ ] Persistence demo — SQLDelight-backed feature in the showcase
- [ ] Showcase app — single app on Android and iOS that exercises every component above
- [ ] Published artifacts — Maven Central (Android / shared) + Swift Package (iOS)

### Out of Scope

<!-- Explicit boundaries. Includes reasoning to prevent re-adding. -->

- Compose Multiplatform for iOS UI — explicitly rejected in `architecture.md`; SwiftUI is the iOS UI
- C/C++ shared core — `architecture.md` non-goal
- A third platform (desktop/web) — KMP keeps the door open without paying for it now
- Tablet-first or desktop-class layouts — phones are primary; tablets just get a larger drawer
- Backend/server product — the push-notification server is a minimal stub, not a real backend
- OAuth / third-party login in the showcase — out of scope for v1; auth is not one of the four primitives

## Context

- Solo developer project. Design-phase as of 2026-05-07; first implementation pass starts the same day.
- `README.md` and `architecture.md` define the target architecture in detail — pattern (MVVM with shared `ViewModel` + `StateFlow`, UDF), libraries (Ktor, SQLDelight, Koin, SKIE), versions (`androidx.lifecycle 2.10.0`), and the design-token bridge contract. No source code on disk yet beyond docs.
- `compose-multiplatform-core/` is a **read-only reference checkout** of AndroidX/Compose libraries — useful for looking up library internals, not project source code. Don't ship from it.
- Architecture intentionally tracks official JetBrains and Google KMP guidance so future contributors and AI tools recognise the patterns immediately.

## Constraints

- **Tech stack**: Kotlin Multiplatform, Jetpack Compose (Android), SwiftUI (iOS), Ktor, SQLDelight, Koin, SKIE — locked by `architecture.md`. No alternatives entertained for v1.
- **Lifecycle version**: `androidx.lifecycle 2.10.0` — KMP-capable `ViewModel` artifact.
- **Design tokens in commonMain** must use only primitives (`Long` for ARGB, `Float`, `Int`) — no Compose or SwiftUI types, since they don't compile on the other side.
- **State ownership**: shared `ViewModel`s own state; both UIs are pure projections. Views never mutate state.
- **Form factor**: phones first; tablets get the same drawer larger. Foldables / desktop are not designed for.
- **Solo + AI-assisted**: planning and execution will run through GSD; phase decomposition should respect that one person (with an agent) is doing the work.

## Key Decisions

<!-- Decisions that constrain future work. Add throughout project lifecycle. -->

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Native UI per platform (Compose + SwiftUI), not Compose Multiplatform iOS | Avoids Compose-iOS rendering surprises; full SwiftUI ecosystem; iOS toolchain unchanged | — Pending |
| MVVM with shared `ViewModel` on `StateFlow`, UDF | Matches official JetBrains + Google KMP guidance | — Pending |
| SKIE for Kotlin↔Swift interop | Industry-standard solution for the KMP↔SwiftUI gap | — Pending |
| Tree sidebar nav implemented as a collapsible drawer on phones (not a permanent rail) | Phones are primary form factor; permanent rail is a tablet/desktop pattern | — Pending |
| Push notifications end-to-end (FCM + APNs + minimal server stub) **and** an in-app component library | Both are real first-class concerns; push-first ordering since it has the more painful integration surface | — Pending |
| Skeleton ships as **published artifacts** (Maven Central + Swift Package), not just a clonable repo | Makes the components consumable from real products without copy-paste forks | — Pending |
| Project name `Skeleton` is a placeholder for v1 | Final name + package IDs decided before publish phase, not now | — Pending |
| Showcase networking API: TBD | Likely a currency-rates API so it doubles as data for the amount-input component, but not committed | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-05-08 after initialization*
