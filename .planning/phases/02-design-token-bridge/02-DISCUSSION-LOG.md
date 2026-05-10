# Phase 2: Design Token Bridge - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-10
**Phase:** 02-design-token-bridge
**Areas discussed:** Color vocabulary, Typography token shape, SwiftUI token injection API, Spacing & radius scale

---

## Color vocabulary

| Option | Description | Selected |
|--------|-------------|----------|
| Full M3 ColorScheme mirror (~30 roles) | Define every M3 color role; Compose adapter passes all to ColorScheme(); no M3 defaults leak in | ✓ |
| Minimal semantic subset (~12 roles) | primary/secondary/background/surface/error + on-* pairs; remaining M3 slots use M3 defaults | |
| You decide | Planner picks the scope | |

**User's choice:** Full M3 ColorScheme mirror (~30 roles)
**Notes:** Consistent with the skeleton template goal — consuming products can override any color slot.

---

| Option | Description | Selected |
|--------|-------------|----------|
| Real palette — intentional Skeleton identity | Indigo/teal/neutral-grey palette; showcase looks finished; cloned products see a real override example | ✓ |
| Minimal placeholder palette | Generic values that compile; products always replace them anyway | |
| You decide | Planner picks | |

**User's choice:** Real palette — intentional Skeleton identity
**Notes:** Planner selects exact hex values targeting an indigo-primary / teal-tertiary / neutral-grey scheme.

---

## Typography token shape

| Option | Description | Selected |
|--------|-------------|----------|
| Minimal: size + weight only | `data class TextStyleToken(val size: Float, val weight: Int)` | |
| Standard: size + weight + lineHeight | Adds vertical rhythm control | |
| Full: size + weight + lineHeight + letterSpacing | Mirrors all four M3 TextStyle fields | ✓ |

**User's choice:** Full: size + weight + lineHeight + letterSpacing
**Notes:** Max fidelity for a template; planner handles the letterSpacing mapping difference between M3 (sp) and SwiftUI (kerning points).

---

| Option | Description | Selected |
|--------|-------------|----------|
| Full M3 type scale — all 15 roles | DisplayLarge/Medium/Small, HeadlineLarge/Medium/Small, TitleLarge/Medium/Small, BodyLarge/Medium/Small, LabelLarge/Medium/Small | ✓ |
| Common subset — 8 roles | 8 most common roles; remaining fall back to M3 defaults | |
| You decide | Planner picks | |

**User's choice:** Full M3 type scale — all 15 roles
**Notes:** Consistent with the full ColorScheme mirror decision — full fidelity throughout.

---

## SwiftUI token injection API

| Option | Description | Selected |
|--------|-------------|----------|
| Single @Environment(\.appTheme) object | One `AppTheme` struct holds colors, typography, spacing, radius sub-properties; one EnvironmentKey | ✓ |
| Per-category environment keys | Separate @Environment(\.themeColors), @Environment(\.themeTypography), etc. | |
| You decide | Planner picks | |

**User's choice:** Single @Environment(\.appTheme) object
**Notes:** Standard design-system pattern for SwiftUI; scales cleanly as token categories grow.

---

| Option | Description | Selected |
|--------|-------------|----------|
| WindowGroup root in iosApp.swift | @Environment(\.colorScheme) read at root; .environment(\.appTheme, AppTheme.build(isDark)) applied once | ✓ |
| ContentView using .environmentObject | AppTheme as @EnvironmentObject from ContentView | |
| You decide | Planner picks | |

**User's choice:** WindowGroup root in iosApp.swift
**Notes:** Ensures Pitfall 7 is mitigated — Swift owns dark/light selection; Kotlin never selects the palette.

---

## Spacing & radius scale

| Option | Description | Selected |
|--------|-------------|----------|
| Semantic names: xs/sm/md/lg/xl (+ xxs/xxl) | Human-readable; 7 steps (2/4/8/16/24/32/48f) | ✓ |
| Numeric multiples of 4dp: 4/8/12/16/24/32/48 | Forces 4dp grid; mirrors M3 spacing spec but less readable API | |
| You decide | Planner picks | |

**User's choice:** Semantic names: xs/sm/md/lg/xl (+ xxs/xxl)
**Notes:** Cleaner API for consumers of the skeleton template.

---

| Option | Description | Selected |
|--------|-------------|----------|
| Semantic names: none/xs/sm/md/lg/xl/full | 0/4/8/12/16/28/9999f; Compose maps to M3 Shapes roles | ✓ |
| M3 Shapes mapping: extraSmall/small/medium/large/extraLarge/full | 1-to-1 with M3 Shapes roles; more verbose names | |
| You decide | Planner picks | |

**User's choice:** Semantic names mirroring spacing: none/xs/sm/md/lg/full
**Notes:** Consistent naming convention across all token categories.

---

## Claude's Discretion

- Exact hex values for the Skeleton identity palette (indigo/teal/neutral-grey direction given, specific values left to planner)
- Whether `DesignTokens` is a Kotlin `object` (singleton) or top-level `const val` declarations
- Whether `ThemeColors`, `ThemeTypography`, etc. are Swift `struct` or `class`
- Whether to add a demo color-swatch or typography-sample screen to the showcase in Phase 2

## Deferred Ideas

- Runtime light/dark theme toggle in showcase UI (SHOW-04 → Phase 6)
- Brand refinement / final production color values (per-product concern)
- Custom font loading (per-product concern; Phase 2 uses system fonts)
- Dynamic color / Material You (explicit opt-out for skeleton template)
