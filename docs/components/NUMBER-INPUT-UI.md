# Reusable Number Input — UI Specifications

| Field | Value |
|---|---|
| **Status** | Draft — pairs with PRD v0.1 |
| **PRD** | [`NUMBER-INPUT-PRD.md`](./NUMBER-INPUT-PRD.md) |
| **Plan** | [`NUMBER-INPUT-IMPLEMENTATION-PLAN.md`](./NUMBER-INPUT-IMPLEMENTATION-PLAN.md) |
| **Tech** | iOS 16+ · SwiftUI · UIKit `inputAccessoryView` (UIToolbar) · `NSNumberFormatter` |
| **Tokens** | [`shared-core/.../theme/DesignTokens.kt`](../../shared-core/src/commonMain/kotlin/dev/viethung/core/theme/DesignTokens.kt) |
| **Doc version** | 0.1 (2026-05-19) |

> **Scope of this doc:** what the component **looks like** and **how it behaves**. The how-it's-built lives in the Implementation Plan.

---

## 1. View Inventory

| # | View | Type | Purpose | PRD ref |
|---|---|---|---|---|
| 1 | **`NumberInputField`** | SwiftUI public `View` | The drop-in input. Renders a styled text field; manages focus, toolbar, formatting. | FR-01, FR-10 |
| 2 | **`KeyboardToolbar`** | `UIToolbar` wrapped as inputAccessoryView | The 3-button accessory bar above `.decimalPad`. | FR-02 |
| 3 | **`NumberInputShowcaseScreen`** | SwiftUI demo (in `:shared-app` + Swift Package preview) | Three fields side-by-side in `en-US`, `vi-VN`, `de-DE`, plus signed/unsigned demo. | §10.C of PRD |

---

## 2. Toolbar Layout

Per PRD §10.D — recommended layout (Apple HIG: primary action on the right).

```
 ┌─────────────────────────────────────────────────────────────────┐
 │  Clear       ±         ····· flex spacer ·····          Done    │ <- UIToolbar
 │                                                                 │   inputAccessoryView
 ├─────────────────────────────────────────────────────────────────┤
 │  1     2     3                                                  │
 │  4     5     6                                                  │ <- .decimalPad
 │  7     8     9                                                  │   (system keyboard,
 │  .     0     ⌫                                                 │    locale's decimal
 │                                                                 │    separator on '.')
 └─────────────────────────────────────────────────────────────────┘
```

### Button specs

| Button | Visual | UIBarButtonItem | a11y identifier | a11y label | Disabled when |
|---|---|---|---|---|---|
| **Clear** | Text "Clear" (localized) | `.plain` style, leading | `numberInput.toolbar.clear` | "Clear field" | `value == nil && rawText.isEmpty` |
| **±** | Symbol `plus.slash.minus` (SF Symbol) | `.plain` style, after Clear | `numberInput.toolbar.toggleSign` | "Toggle sign" | `allowNegative == false` OR `value == nil` |
| **Done** | Text "Done" (localized, bold) | `.done` style, trailing | `numberInput.toolbar.done` | "Done" | never (always available) |

Spacing: a `UIBarButtonItem.flexibleSpace()` between **±** and **Done** pushes Done to the trailing edge.

### Visual constants

| Property | Value | Source |
|---|---|---|
| Toolbar height | 44 pt (UIKit default) | system |
| Toolbar background | `.systemBackground` (auto light/dark) | system |
| Button tint | `DesignTokens.accent` | tokens |
| "Done" font weight | semibold | system `.done` style default |
| Symbol size for `±` | 17 pt body | system |

---

## 3. State Machine

The component's UI is driven by `NumberInputUiState` (sealed interface in PRD §7). Three states; transitions below.

```
                        ┌─────────────────────────────────┐
              app load  │  Idle                            │
              ──────────▶│  • field shows formattedText    │
                        │  • binding = value               │
                        │  • toolbar HIDDEN (no focus)     │
                        └────────────────┬─────────────────┘
                                         │ user taps field
                                         ▼
                        ┌─────────────────────────────────┐
                        │  Editing                         │◀────┐
                        │  • field shows formattedText     │     │
                        │    (live-grouped integer +       │     │  keystroke
                        │    decimal portion as typed)     │     │  / ± toggle
                        │  • toolbar VISIBLE               │─────┘
                        │  • cursor at end (resets on      │
                        │    each binding update)          │
                        │  • binding updated per keystroke │
                        └────┬───────────┬───────────┬─────┘
                  Clear tap  │           │ Done tap   │ focus lost
                  (→ self,   │           │            │ (e.g. tap
                   rawText="")           │            │ outside)
                             │           ▼            ▼
                             │   ┌─────────────────────────┐
                             │   │  Committed              │
                             │   │  • format(value)        │
                             │   │  • emit onCommit(value) │
                             │   │  • dismiss keyboard     │
                             │   └────────────┬────────────┘
                             │                │ next frame
                             │                ▼
                             │   ┌─────────────────────────┐
                             └──▶│  Idle                   │
                                 │  (formatted, unfocused) │
                                 └─────────────────────────┘
```

### Transition table

| From | Event | To | Side effects |
|---|---|---|---|
| `Idle` | field gains focus | `Editing` | toolbar appears; `rawText` and `formattedText` ← Idle's `formattedText` (the locale-grouped string already on screen) |
| `Editing` | keystroke (digit / decimal sep / backspace) | `Editing` | `rawText` ← what the user typed; `value` re-parsed; `formattedText` ← `formatLive(rawText, locale)` (integer regrouped, decimal-and-after preserved verbatim, sign preserved); binding emits |
| `Editing` | ± tap (FR-05) | `Editing` | if `value != nil`: `value ← -value`; both `rawText` and `formattedText` ← `format(-value, sigDigits, locale)` (locale-correct decimal separator); else no-op |
| `Editing` | Clear tap (FR-04) | `Editing` | `rawText ← ""`, `formattedText ← ""`, `value ← nil`, binding emits, keyboard stays |
| `Editing` | Done tap (FR-03) | `Committed → Idle` | format `value` to `formattedText` with sigDigits padding/rounding; `onCommit(value)` fires; keyboard dismisses |
| `Editing` | focus lost (e.g. tap outside) | `Committed → Idle` | same as Done tap |

### Edge cases

| Case | Behavior |
|---|---|
| User types `1.2.3` (two decimal seps) | The `.decimalPad` system keyboard already prevents this — second `.` is ignored at the OS level. No additional handling needed. |
| User types a value exceeding `Double.MAX_SAFE_INTEGER` precision | Display formats best-effort; binding holds `Double` (precision drift accepted per §10.A risk). |
| User pastes `"abc"` | `rawText` parser rejects; field reverts to last valid `rawText`. No visual flash beyond one frame. |
| User pastes `"1234,56"` while in `en-US` locale | Parse fails (no thousands separator support in `decimalPad` input); pasted text rejected. v2 may add tolerant paste handling. |
| User taps ± with `value = 0` | `0 * -1 = 0` — visible no-op. Acceptable. |
| User taps ± then Clear | Sign toggle takes effect, then Clear empties. State chain: `Editing(42) → Editing(-42) → Editing(empty)`. |
| User backspaces over a grouping separator | The separator is auto-regenerated. E.g., `"1,000"` → backspace → `"1,00"` → re-formatLive → `"100"` (no grouping needed); `"1,000,000"` → backspace into the comma → `"1,000000"` → re-formatLive → `"1,000,000"` (comma snaps back). Cursor lands at end of string. |
| User types only `"-"` | Field displays `"-"`. Allows starting a negative number; subsequent digits build the value. |
| Device-locale decimal char ≠ field-locale decimal char | `.decimalPad` only offers the device locale's decimal symbol. If field locale's decimal differs (e.g. device `en-US` with `.`, field `vi-VN`/`de-DE` with `,`), the UITextField delegate substitutes the typed character on insertion so the user can enter decimals regardless of device settings. Substitution applies to single-character `.` or `,` keypresses; multi-char paste falls through. |
| Significant-digits truncation: user typed `1.2345`, `significantDigits = 2` | On commit: `"1.23"` (half-to-even). The binding's `value` is `1.23` after commit. |
| Significant-digits padding: user typed `0.1`, `significantDigits = 3` | On commit: `"0.100"`. Binding's `value` is `0.1` (numeric `0.1`, not `0.100`). |

---

## 4. Visual Specifications

### 4.1 Field appearance

```
 Idle (unfocused, value = 1234.5, locale = en-US, sigDigits = 2)
 ┌──────────────────────────────────┐
 │ 1,234.50                         │  16 pt label color
 └──────────────────────────────────┘

 Idle (unfocused, value = nil)
 ┌──────────────────────────────────┐
 │ Enter amount                     │  16 pt secondaryLabel color (placeholder)
 └──────────────────────────────────┘

 Editing (focused, user typed "1234.5", locale = en-US)
 ┌──────────────────────────────────┐
 │ 1,234.5                         ▏│  16 pt label color, cursor visible
 └──────────────────────────────────┘
                                  ▲
                              caret

 Integer portion is live-grouped using the locale's grouping separator;
 the decimal-separator-and-after portion is preserved verbatim from what
 the user typed (no `significantDigits` padding mid-edit). vi-VN/de-DE
 show "1.234,5"; fr-FR shows "1 234,5".

 Disabled (allowNegative=false, but otherwise normal)
 ┌──────────────────────────────────┐
 │ 1,234.50                         │  16 pt tertiaryLabel color, no underline
 └──────────────────────────────────┘
```

### 4.2 Design tokens consumed

Per CLAUDE.md §2 — no raw colors. The view consumes tokens via the existing iOS token bridge.

| Element | Token | Notes |
|---|---|---|
| Text color (idle / editing) | `DesignTokens.textPrimary` | resolved to `.label` in light, `.label` in dark |
| Placeholder color | `DesignTokens.textSecondary` | resolved to `.secondaryLabel` |
| Disabled text color | `DesignTokens.textTertiary` | resolved to `.tertiaryLabel` |
| Caret / tint | `DesignTokens.accent` | applies to caret and toolbar buttons |
| Field background | `DesignTokens.backgroundSurface` | matches Login screen's field |
| Field border (focused) | `DesignTokens.accent` 1.5 pt | optional, matches Login pattern |
| Toolbar background | system `.systemBackground` | not tokenized — Apple guidance is to inherit |

### 4.3 Typography

| Element | Token | Default |
|---|---|---|
| Field value | `DesignTokens.body` | 16 pt regular |
| Placeholder | `DesignTokens.body` | 16 pt regular, `textSecondary` |
| Toolbar buttons | system body | 17 pt regular ("Done" is semibold via `.done` barButton style) |

### 4.4 Layout dimensions

| Property | Value |
|---|---|
| Field height (min) | 44 pt (HIG tap target) |
| Field internal padding | 12 pt horizontal, 8 pt vertical |
| Field corner radius | 8 pt (matches Login form fields) |
| Toolbar height | 44 pt (UIKit default; not customizable) |
| Toolbar internal margins | 16 pt leading/trailing (system) |

---

## 5. Locale Formatting Rules

`LocaleNumberFormatter` (PRD §7) wraps `NSNumberFormatter` with these properties locked:

| `NSNumberFormatter` property | Value | Why |
|---|---|---|
| `numberStyle` | `.decimal` | Generic numeric, not currency |
| `usesGroupingSeparator` | `true` | Per FR-06 — locale's thousands separator |
| `minimumFractionDigits` | `significantDigits` | Pad with trailing zeros (FR-07) |
| `maximumFractionDigits` | `significantDigits` | Round half-to-even to cap (FR-07) |
| `roundingMode` | `.halfEven` | Banker's rounding; matches `kotlin.math.roundToInt` default |
| `locale` | Caller-supplied or `.current` | FR-06 |

### Reference outputs

For `value = 1234567.89`, `significantDigits = 2`:

| Locale | Expected output | Notes |
|---|---|---|
| `en-US` | `"1,234,567.89"` | `,` grouping, `.` decimal |
| `en-GB` | `"1,234,567.89"` | identical to en-US |
| `vi-VN` | `"1.234.567,89"` | `.` grouping, `,` decimal |
| `de-DE` | `"1.234.567,89"` | identical to vi-VN |
| `fr-FR` | `"1 234 567,89"` | NBSP (` `) grouping, `,` decimal |
| `ja-JP` | `"1,234,567.89"` | identical to en-US |
| `ar-EG` | `"١٬٢٣٤٬٥٦٧٫٨٩"` | Eastern Arabic digits; we accept the output as-is (display correctness is `NSNumberFormatter`'s contract) |

For `value = -0.1`, `significantDigits = 3`:

| Locale | Expected output |
|---|---|
| `en-US` | `"-0.100"` |
| `vi-VN` | `"-0,100"` |
| `de-DE` | `"-0,100"` |
| `fr-FR` | `"-0,100"` |

### Negative-sign placement

`NSNumberFormatter` handles this via locale's `negativeFormat`. We don't override it. For all major locales we support, this means leading `-`. We accept Apple's defaults; we do NOT support parenthesis-style negatives (`(123.45)` for accounting) in v1.

---

## 6. Accessibility

| Concern | Implementation |
|---|---|
| **VoiceOver: field** | `accessibilityLabel` = caller-supplied label (defaults to placeholder); `accessibilityValue` = `formattedText` (when idle) or `rawText` (when editing); `accessibilityHint` = "Double tap to enter a number" |
| **VoiceOver: toolbar buttons** | Per §2 table — Clear / Toggle sign / Done labels |
| **Dynamic Type** | Font scales with system; tested at `xxLarge`. Field height auto-grows. |
| **Reduce Motion** | No bespoke animations; system keyboard transitions only |
| **Right-to-left UI** | Toolbar leading/trailing automatically mirrors; ± icon does NOT flip (math symbol) |
| **Keyboard (external)** | Standard text-field behavior — typing, Tab to next field, etc.; ± / Clear NOT keyboard-shortcut-addressable in v1 |
| **High-contrast** | System tokens carry contrast; no hardcoded colors |

---

## 7. Showcase Screen Layout

The `:shared-app` showcase screen demonstrates all three primary cases.

```
 ┌──────────────────────────────────────────────────────┐
 │  ← Back        Number Input Showcase                  │
 ├──────────────────────────────────────────────────────┤
 │                                                       │
 │  Default (locale = en-US, sigDigits = 2)              │
 │  ┌──────────────────────────────────┐                 │
 │  │ 1,234.50                         │                 │
 │  └──────────────────────────────────┘                 │
 │                                                       │
 │  Vietnamese locale (vi-VN, sigDigits = 2)             │
 │  ┌──────────────────────────────────┐                 │
 │  │ 1.234,50                         │                 │
 │  └──────────────────────────────────┘                 │
 │                                                       │
 │  German locale (de-DE, sigDigits = 3)                 │
 │  ┌──────────────────────────────────┐                 │
 │  │ 1.234,500                        │                 │
 │  └──────────────────────────────────┘                 │
 │                                                       │
 │  Unsigned (allowNegative = false)                     │
 │  ┌──────────────────────────────────┐                 │
 │  │ 42                               │  (± disabled    │
 │  └──────────────────────────────────┘   in toolbar)   │
 │                                                       │
 │  Reset all                                            │
 │                                                       │
 └──────────────────────────────────────────────────────┘
```

---

## 8. Cross-Reference: PRD ↔ UI

| PRD requirement | UI section | Verified by |
|---|---|---|
| FR-01 (decimal pad) | §4.1 + §5 | AC-01, AC-02 |
| FR-02 (toolbar) | §2 | AC-06 |
| FR-03 (Done) | §3 transitions + §2 | AC-06 |
| FR-04 (Clear) | §3 transitions + §2 | AC-05 |
| FR-05 (± toggle) | §3 transitions + §3 edge cases | AC-03, AC-04 |
| FR-06 (locale format on commit) | §5 + §3 transitions | AC-01, AC-02 |
| FR-07 (significantDigits) | §3 edge cases + §5 (formatter properties) | AC-07 |
| FR-08 (negative sign) | §5 negative-sign placement | AC-03 |
| FR-09 (StateFlow) | §3 | AC-11 |
| FR-10 (SwiftUI modifiers) | §1 inventory | AC-09 (consumer build) |
| FR-11 (SPM) | _implementation concern, see Plan §11_ | AC-09 |
| FR-12 (tokens) | §4.2 | AC-10 |

---

## 9. Open UI Questions (defer to PRD §14)

- ✅ Toolbar order — recommended `[Clear] [±] [···] [Done]` (PRD §10.D)
- ❓ Should the field show an inline error state (e.g., red border) when significantDigits truncation would change the value materially? **Recommendation: NO** for v1 — formatting is silent; we don't surface "rounded" feedback. Caller can implement on top.
- ❓ Should Clear require a long-press confirmation? **Recommendation: NO** — Clear is a recoverable action (user can re-type); confirmation friction not justified.
- ❓ Should the field auto-format on first appearance if a non-nil value is provided? **Recommendation: YES** — Idle state always shows `formattedText`.
