# Reusable Number Input — Reuse & Architecture Guide

| Field | Value |
|---|---|
| **Status** | Reference — companion to PRD/UI/Plan |
| **PRD** | [`NUMBER-INPUT-PRD.md`](./NUMBER-INPUT-PRD.md) |
| **UI spec** | [`NUMBER-INPUT-UI.md`](./NUMBER-INPUT-UI.md) |
| **Plan** | [`NUMBER-INPUT-IMPLEMENTATION-PLAN.md`](./NUMBER-INPUT-IMPLEMENTATION-PLAN.md) |
| **Document version** | 0.1 (2026-05-19) |

> **Scope of this doc:** what's actually shared vs platform-specific, and how to reuse this component in a pure-iOS-native project that doesn't use KMP.

---

## 1. What's Shared (Kotlin `commonMain`)

The **business logic** lives once, in `:shared-components/commonMain`:

- `NumberInputViewModel` — the state machine (Idle / Editing / Committed transitions; `onTextChange`, `onToggleSign`, `onClear`, `onCommit`).
- `NumberInputUiState` — the sealed state types.
- `NumberInputConfig` — the API surface (`significantDigits`, `locale`, `allowNegative`, `placeholder`).
- `LocaleNumberFormatter` interface.
- The `liveFormat` helper that does the grouping algorithm.
- All `formatLive` semantics: split on decimal separator, strip grouping, regroup integer portion, preserve sign and partial decimal.

Both Android and iOS run **the same Kotlin code** for all of that. Same state machine, same grouping rules, same edge-case handling. A bug fix to `formatLive` lands in both platforms simultaneously.

---

## 2. What's Platform-Specific (Necessarily)

Only two surfaces:

### 2.1 `LocaleNumberFormatter` `actual`

- iOS uses `NSNumberFormatter`.
- Android uses `java.text.DecimalFormat` + `DecimalFormatSymbols`.

Both are ~30 lines, and both delegate the grouping algorithm to the shared `liveFormat` helper in commonMain. They exist because each platform has a different native formatter API; Kotlin `commonMain` has no locale-aware formatter built in.

### 2.2 The View Layer (UI)

By deliberate architectural choice (CLAUDE.md §3 — "MVVM with shared `androidx.lifecycle.ViewModel` … native UI per platform"):

- **Android:** Jetpack Compose.
- **iOS:** SwiftUI + UIKit (`UIViewRepresentable` wrapping `UITextField`).

The iOS `NumberInputUITextField` / `NumberInputBridge` / programmatic `UIToolbar` exist because:

- SwiftUI `TextField` ignores mid-edit binding writes — we had to drop to `UITextField` to make live re-formatting visible.
- `.decimalPad` keyboard locale needs delegate-level substitution so vi-VN/de-DE fields accept the device's decimal character.
- The iOS keyboard accessory toolbar (Done / Clear / ±) has no Compose analog.

**None of that view-layer code contains business logic** — it's all glue that calls into the shared Kotlin VM via `NumberInputViewModelHelperKt`.

---

## 3. Reusing in a Pure-iOS-Native Project

Two paths.

### 3.1 Path A — Use this Swift Package as-is (recommended)

The Swift Package (`swift-package/NumberInput/`) depends on `SkeletonKit.xcframework`, which contains the shared KMP business logic. A pure-Swift consumer project pulls in:

- The Swift Package (the SwiftUI/UIKit views).
- The XCFramework binary (the Kotlin VM + formatter).

The XCFramework is a few MB, has no runtime dependencies beyond what Kotlin/Native produces, and the Swift Package's `Package.swift` already declares the `binaryTarget`. A pure Swift app consumes it via `.package(path: ...)` like any other SPM dependency.

**Trade-offs:**

| Pro | Con |
|---|---|
| Zero code duplication | Adds an XCFramework binary to the consumer's bundle |
| Bug fixes in `formatLive` / VM land automatically | Consumer needs to build/refresh the XCFramework when the Kotlin side changes |
| Locale-correct formatting validated by KMP contract tests | Consumer tooling has to handle the binary target (Xcode + SPM handle this cleanly) |

### 3.2 Path B — Pure-Swift Rewrite

If the consumer project must not contain any Kotlin, port the following to Swift:

- The state machine (~140 LOC of `NumberInputViewModel`).
- `formatLive` (~30 LOC plus the locale-aware decimal/grouping split via `Locale`/`NumberFormatter`).
- The sealed state types.

Total: ~200 lines of Swift. Doable, but the consumer loses the shared bug-fix surface — any future fix lands twice.

---

## 4. Decision Guide

| Situation | Recommendation |
|---|---|
| Greenfield iOS-only project, willing to ship an XCFramework | **Path A** — fastest reuse, smallest maintenance footprint |
| Existing iOS-only project with strict "no Kotlin/Native binaries" policy | **Path B** — port the ~200 lines |
| Multi-platform project (KMP) | Use the modules directly (`:shared-components`) — no Swift Package needed |
| Just want to copy the SwiftUI styling but not the VM | Path B, but extract only the view layer; supply your own state holder |

---

## 5. The Architectural Principle

> Share logic, write UI natively.

This component does not duplicate behavior. It duplicates only the unavoidable platform glue (formatter `actual`s + native views). The VM, the state types, and the formatting algorithm are written **once** in `commonMain`.

If a future bug requires changing the live-grouping rule, you change `liveFormat` in `commonMain` and rebuild the XCFramework — both Android and iOS pick up the fix without any view-layer changes.

---

## 6. References

- `shared-components/src/commonMain/kotlin/dev/viethung/components/numberinput/` — the shared logic.
- `shared-components/src/iosMain/kotlin/dev/viethung/components/numberinput/` — iOS `actual` + Swift bridge helper.
- `shared-components/src/androidMain/kotlin/dev/viethung/components/numberinput/` — Android `actual`.
- `swift-package/NumberInput/` — SwiftUI/UIKit views consumed by iOS apps.
- [`../ARCHITECTURE.md`](../ARCHITECTURE.md) — overall KMP module layout.
- [`../../CLAUDE.md`](../../CLAUDE.md) §3 — state-ownership and platform-binding rules.
