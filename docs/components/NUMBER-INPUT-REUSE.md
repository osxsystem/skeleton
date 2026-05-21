# Reusable Number Input — Reuse & Architecture Guide

| Field | Value |
|---|---|
| **Status** | Reference — describes the post-extraction architecture |
| **PRD** | [`NUMBER-INPUT-PRD.md`](./NUMBER-INPUT-PRD.md) — original design (superseded; see §3) |
| **UI spec** | [`NUMBER-INPUT-UI.md`](./NUMBER-INPUT-UI.md) |
| **Plan** | [`NUMBER-INPUT-IMPLEMENTATION-PLAN.md`](./NUMBER-INPUT-IMPLEMENTATION-PLAN.md) — original plan (superseded; see §3) |
| **Document version** | 0.2 (2026-05-21) |

> **Scope of this doc:** how to consume the Number Input, and the trade-off behind the standalone-library architecture.

---

## 1. Architecture (current)

Two standalone libraries. No shared KMP source.

| Platform | Library | Path | Distribution |
|---|---|---|---|
| Android | `:number-input` | [`number-input/`](../../number-input/) | Gradle AAR (`dev.viethung:number-input`) |
| iOS | `NumberInputKit` | [`swift-package/NumberInputKit/`](../../swift-package/NumberInputKit/) | Swift Package (source) or XCFramework |

Both expose the same public API: `NumberInputViewModel`, `NumberInputUiState`, `NumberInputConfig`, `LocaleNumberFormatter`, `NumberInputField`. The implementations are intentionally **duplicated** — Kotlin one side, pure-Swift the other. Neither depends on `:shared-core`, `:shared-components`, or `SkeletonKit.xcframework`.

---

## 2. Trade-off

**Why duplicate?** Consumer reach. A pure-Compose Android app with no KMP setup pulls `:number-input` as a normal AAR. A pure-Swift iOS app pulls `NumberInputKit` as a normal SPM package. No KMP toolchain required on either side.

**Cost.** ~200 LOC of state machine + locale formatting, written twice. The KMP `expect`/`actual` bridge was deleted because the maintenance burden (XCFramework rebuilds + Swift ObjC bridge for `NumberInputViewModelHelper`) outweighed the LOC savings.

**Drift risk.** The two implementations can diverge silently. Mitigation (not yet wired): a shared JSON contract fixture (`input, locale, sigDigits, allowNegative → display`) consumed by both test suites, CI failure on any divergence. Tracked in the 2026-05-21 `/ck-predict` risk report.

---

## 3. Historical note

The original design (PRD / Implementation Plan, dated 2026-05-19) placed the business logic in `:shared-components/commonMain` and exposed it to iOS via `SkeletonKit.xcframework`. That model shipped successfully — see [`reports/numberinput-smoke-2026-05-19.md`](./reports/numberinput-smoke-2026-05-19.md). It was extracted to standalone libraries on 2026-05-20 to drop the KMP dependency for non-KMP consumers. The PRD §11 / §14 decisions and Implementation Plan §4.6 / Steps 7-9 describe the now-removed bridge architecture and are kept as a design record.

---

## 4. References

- [`number-input/README.md`](../../number-input/README.md) — Android consumer guide
- [`swift-package/NumberInputKit/README.md`](../../swift-package/NumberInputKit/README.md) — iOS consumer guide
- [`../../CLAUDE.md`](../../CLAUDE.md) §3 — overall state-ownership and platform-binding rules (note: this component is now an exception to "share logic, write UI natively" — it duplicates logic intentionally)
