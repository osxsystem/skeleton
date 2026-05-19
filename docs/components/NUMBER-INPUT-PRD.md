# Reusable Number Input — Product Requirements Document

| Field | Value |
|---|---|
| **Status** | **Approved 2026-05-19** — §14 decisions resolved; ready for implementation |
| **Owner** | _unassigned_ |
| **Companion plan** | [`NUMBER-INPUT-IMPLEMENTATION-PLAN.md`](./NUMBER-INPUT-IMPLEMENTATION-PLAN.md) |
| **UI spec** | [`NUMBER-INPUT-UI.md`](./NUMBER-INPUT-UI.md) |
| **Phase** | First reusable component in `:shared-components` (precedes amount input, form kit) |
| **Target sprint** | 1 sprint (~3 days, sequential build per plan §4) |
| **Document version** | 0.1 (2026-05-19) |

---

## 1. Problem Statement

1. **The skeleton has zero reusable input components.** A scan of `:shared-components` returns only `SampleUiState.kt`, `SkieConventions.kt`, and `ComponentsModule.kt` — none provide form inputs. CLAUDE.md §3 names `:shared-components` as the home for "reusable component ViewModels + `expect`/`actual` services (forms, amount input, sidebar nav, notifications)", but the first such component has not been built yet. Every screen that needs a numeric value (amount, quantity, threshold) currently has no shared primitive to lean on.
2. **iOS `.decimalPad` keyboard is missing two things every numeric form needs.** Apple ships no Done key (the pad has no Return) and no minus sign — both are documented limitations ([Apple Forums](https://developer.apple.com/forums/thread/670271), [Hacking with Swift forum](https://www.hackingwithswift.com/forums/swiftui/decimalpad-and-custom-button-for-minus-sign/12219)). Every iOS app that wants signed decimal input has to roll its own keyboard accessory toolbar. We want to roll it once, well, and reuse it.
3. **Locale-correct numeric formatting is non-trivial across KMP.** Decimal separators (`.` vs `,`), grouping separators, and digit ordering vary by locale. Doing this in `commonMain` requires `expect`/`actual` because Kotlin has no built-in locale-aware formatter (community confirms this; see [Cash App blog](https://code.cash.app/kotlin-multiplatform-money-formatter), [pale-blue-kmp-core](https://www.paleblueapps.com/rockandnull/kmp-currency-number-formatter-kmmresult/)). The skeleton has no `expect` formatter today.
4. **Other iOS apps in the org need this too.** The component must be installable as a Swift Package, not only via the in-repo XCFramework. That changes the distribution shape (see §11 below).

---

## 2. Goals & Success Metrics

| Goal | Measurement | Target |
|---|---|---|
| Establish the first `:shared-components` ViewModel pattern | `NumberInputViewModel` + `NumberInputUiState` + `commonTest` covering state transitions | 100% of state branches asserted via Turbine |
| Locale-correct formatting on iOS | Sample value `1234567.89` formats correctly under `en-US`, `vi-VN`, `de-DE`, `fr-FR` | 4/4 locales match `NSNumberFormatter` reference output |
| Keyboard gap closed | Decimal pad + custom toolbar (Done, Clear, ±) | Toolbar visible on focus, dismissable, sign-toggle works |
| External reusability | Component installable from SPM by an unrelated iOS app | A bare `SwiftUI` consumer app builds and runs against the published Swift Package |
| No architectural drift | Zero violations of CLAUDE.md §2 rules (no platform types in `commonMain`, single source of versions in `libs.versions.toml`) | `./gradlew check` clean |

---

## 3. User Stories

- **US-01.** As a **developer building a form**, I want to **drop in `NumberInputField(value:, significantDigits:)`** so that **I get locale-correct numeric input without re-inventing keyboard plumbing**.
- **US-02.** As an **end user entering a value**, I want to **see Done, Clear, and ± buttons above the decimal keyboard**, so that **I can dismiss the keyboard, clear the field, and enter negative numbers — none of which `.decimalPad` supports natively**.
- **US-03.** As an **end user in Vietnam (vi-VN)**, I want **`1.234,56` to render with my locale's separators**, so that **the number reads naturally to me**.
- **US-04.** As a **developer writing a settings screen with a precision-3 percentage**, I want to **configure `significantDigits = 3`**, so that **the field clamps and pads display to 3 digits past the decimal**.
- **US-05.** As an **iOS developer in a sibling app**, I want to **`import NumberInput` via Swift Package Manager**, so that **I can reuse this without depending on the entire skeleton repo**.

---

## 4. Scope

### In scope

- **iOS-first**: SwiftUI `NumberInputField` view, `UIToolbar`-backed keyboard accessory (Done / Clear / ±), `.decimalPad` keyboard, locale-aware display via `NSNumberFormatter`.
- **Shared KMP logic in `:shared-components`**:
  - `NumberInputViewModel` (extends `androidx.lifecycle.ViewModel`, exposes `StateFlow<NumberInputUiState>`).
  - `NumberInputUiState` (sealed interface — see §7).
  - `expect class LocaleNumberFormatter` with iOS `actual` using `NSNumberFormatter`.
  - `commonTest` covering state transitions and formatter contract.
- **Hybrid SPM distribution**: KMP exports `:shared-components` to XCFramework as today, plus a thin Swift Package (`NumberInput`) that wraps the XCFramework as a `.binaryTarget` and adds SwiftUI views + toolbar. Sibling iOS apps consume the Swift Package.
- **Negative number support** via toolbar ± button (toggles sign of the current value).
- **Configurable `significantDigits`** (semantics: see §6 — fixed digits after the decimal point, padded with trailing zeros).
- **Programmatic API**:
  - `value: Decimal?` binding (Swift) / `Double?` exposure (Kotlin) — final type decision in §14.A.
  - `significantDigits: Int` (default `2`).
  - `allowNegative: Bool` (default `true`).
  - `locale: Locale` override (defaults to `Locale.current` on iOS, `Locale.current()` on KMP).
  - `placeholder: String`.
- **State events**:
  - `onValueChange(Decimal?)` — fires per user interaction.
  - `onCommit(Decimal?)` — fires when Done is tapped or focus is lost.
  - `onClear()` — fires when Clear is tapped.
- **Sample showcase** wired into `:shared-app` (or `:iosApp`) demonstrating the component in three locales.

### Out of scope (see §13)

- **Android Compose UI** — Android adapter is deferred to a follow-up PRD. The KMP shared logic is designed to support it, but no Compose view is built now.
- **Currency formatting** (currency symbol, currency-code lookup) — separate component, separate PRD.
- **Percentage / scientific notation** modes — separate modes, not in v1.
- **Hardware-keyboard input filtering** on iPad with external keyboard — best-effort but not validated.
- **Right-to-left "banking-style" fill** (cents-from-right) like [`swiftui-currency-field`](https://github.com/jtrinc/swiftui-currency-field).
- **Stepper-style increment/decrement buttons**.
- **Async validation / debounced server checks** — caller's responsibility.
- **iPadOS Slide Over multi-toolbar interaction** edge cases.
- **Accessibility audit beyond VoiceOver basics** (Switch Control, larger text, RTL UI mirroring) — covered at "basic correctness" level, not certified.

---

## 5. Functional Requirements

| ID | Requirement | Plan ref |
|---|---|---|
| **FR-01** | The component SHALL render a single-line text field that accepts numeric input via the iOS `.decimalPad` keyboard. | §10.1 |
| **FR-02** | The component SHALL render an `inputAccessoryView` (UIToolbar) above the keyboard with three `UIBarButtonItem`s: **Done**, **Clear**, **±**. | §10.2 |
| **FR-03** | Tapping **Done** SHALL dismiss the keyboard, commit the current value to the binding, and emit `onCommit(value)`. | §10.2 |
| **FR-04** | Tapping **Clear** SHALL set the field to empty (binding becomes `nil` / `null`), keep keyboard focused, and emit `onClear()`. | §10.2 |
| **FR-05** | Tapping **±** SHALL multiply the current value by `-1`. If the field is empty, ± SHALL be a no-op (no `-0` insertion). Disabled when `allowNegative = false`. | §10.2, §10.5 |
| **FR-06** | The component SHALL format the displayed value using `LocaleNumberFormatter` keyed to the supplied `locale` (defaulting to `Locale.current`). Formatting applies on commit / focus loss — NOT mid-typing (avoids cursor-jump problem documented by [swiftui-numberfield](https://github.com/edw/swiftui-numberfield)). | §10.3 |
| **FR-07** | The component SHALL clamp / pad the value to `significantDigits` digits after the decimal point when formatting. `0.1` with `significantDigits = 3` displays as `"0.100"`; `1.2345` with `significantDigits = 2` displays as `"1.23"` (rounded half-to-even). | §10.3, §10.4 |
| **FR-08** | The component SHALL accept negative numbers entered with a leading minus sign (via the ± button) and SHALL display them with the locale's negative-sign placement (prefix in most locales). | §10.3 |
| **FR-09** | The component SHALL emit a non-null state via `StateFlow<NumberInputUiState>` exposed by `NumberInputViewModel`, consumable from both Compose (Android, future) and SwiftUI (iOS, now). | §7, §10.6 |
| **FR-10** | The component SHALL pass through standard SwiftUI modifiers (`.font`, `.foregroundColor`, `.padding`, `.disabled`, `.focused($focus, equals: ...)`) — its public surface SHALL be a normal SwiftUI `View`, not a `UIViewRepresentable` leak. | §10.6 |
| **FR-11** | The component SHALL expose itself as a Swift Package `NumberInput` consumable by sibling iOS apps. Package dependencies: the shared KMP XCFramework (as `.binaryTarget`) plus the SwiftUI views. No transitive Kotlin Gradle plugin requirement on consumers. | §11 |
| **FR-12** | The component SHALL respect platform color tokens via `shared-core/.../theme/DesignTokens.kt` — no hardcoded colors in the SwiftUI view (per CLAUDE.md §2). | §10.6 |

---

## 6. The `significantDigits` Naming Caveat (PLEASE CONFIRM)

**Open decision flagged for product owner.**

You requested `significantDigits` as the API name, with the example `significantDigits = 3 → "0.001", "0.000"`. The two examples both have **3 digits after the decimal point**, which is the strict mathematical definition of *fractional digits* — not *significant digits*.

| Term | Strict mathematical meaning | Example with value `0.001` |
|---|---|---|
| **Significant digits** | Number of meaningful digits in the value, regardless of decimal position | `0.001` has **1** significant digit (just the `1`); `0.000` has **0** |
| **Fractional digits** (a.k.a. decimal places) | Number of digits after the decimal point | `0.001` has **3** fractional digits; `0.000` has **3** |

Your examples match **fractional digits** behavior, which is also what `NSNumberFormatter.minimumFractionDigits` / `maximumFractionDigits` provide and what is most natural for a fixed-precision input.

**Proposal:** Keep the API name `significantDigits` (your preference) but precisely define its semantics in our docs as:

> *Fixed number of digits to show after the decimal point. Display is padded with trailing zeros to match. Input is rounded half-to-even to fit. (Equivalent to `NSNumberFormatter.minimumFractionDigits == maximumFractionDigits`.)*

**Alternative:** Rename to `fractionDigits` to remove ambiguity at the API surface. This would match Apple's terminology.

→ **Decision needed in §14.B before implementation.**

---

## 7. State Model

```kotlin
// commonMain
sealed interface NumberInputUiState {
    val rawText: String          // What the user is typing (may include grouping separators)
    val formattedText: String    // Grouped display string. Idle/Committed: full format with sigDigits padding.
                                 //                       Editing: live grouping of integer portion,
                                 //                       decimal portion preserved verbatim, no padding.
    val value: Double?           // Parsed numeric value, null if empty
    val significantDigits: Int   // Echoes the configured precision
    val locale: String           // BCP-47 tag, e.g. "en-US"

    data class Idle(/* ... */) : NumberInputUiState        // Field not focused
    data class Editing(/* ... */) : NumberInputUiState     // Field focused, user typing
    data class Committed(/* ... */) : NumberInputUiState   // Done tapped or focus lost
}
```

**Transition rules:**
- `Idle → Editing` when field gains focus. `rawText` and `formattedText` carry the Idle `formattedText` (the locale-grouped form the user already sees), so editing continues from that string.
- `Editing → Editing` on each keystroke. `value` reparsed; `rawText` stores the typed text; `formattedText` recomputed via `LocaleNumberFormatter.formatLive(rawText, locale)` — integer portion regrouped with the locale's grouping separator; decimal-separator-and-after preserved verbatim (no `significantDigits` padding mid-edit); leading `-` preserved.
- `Editing → Idle` on Clear (binding becomes `null`, both `rawText` and `formattedText` become `""`).
- `Editing → Committed → Idle` on Done tap or focus loss. `formattedText` becomes the full `format(value, sigDigits, locale)` output (padded/rounded).
- ± toggles the sign of `value` within whichever state is current; `rawText` and `formattedText` are set to the locale-correct `format(-value, sigDigits, locale)` so non-en locales get the right decimal separator. If `value == null`, ± is a no-op (FR-05).

**See `NUMBER-INPUT-UI.md` §3 for ASCII transition diagram.**

---

## 8. Acceptance Criteria

| AC | Statement | Verified by |
|---|---|---|
| **AC-01** | Typing `1234.5` and tapping Done in `en-US` displays `"1,234.50"` (with `significantDigits = 2`). | XCUITest + unit test on `LocaleNumberFormatter` |
| **AC-02** | Typing `1234.5` and tapping Done in `vi-VN` displays `"1.234,50"`. | XCUITest + unit test |
| **AC-03** | Tapping ± on a value of `42.5` produces `-42.5`. Tapping ± again produces `42.5`. | XCUITest |
| **AC-04** | Tapping ± on an empty field is a no-op (no `-` is inserted; `value` remains `nil`). | XCUITest |
| **AC-05** | Tapping Clear on `42.5` produces empty field, `value == nil`, keyboard remains visible. | XCUITest |
| **AC-06** | Tapping Done dismisses the keyboard within 1 frame of the tap. | XCUITest assertion on `firstResponder` |
| **AC-07** | `significantDigits = 3` formats `0.1` as `"0.100"` and `1.23456` as `"1.235"` (rounded half-to-even). | Unit test on `LocaleNumberFormatter` |
| **AC-08** | `allowNegative = false` disables the ± button and rejects programmatic negative values (clamped to `0`). | Unit test + XCUITest |
| **AC-09** | A sibling iOS app referencing the published Swift Package via SPM URL builds and runs against three locales. | Manual smoke (separate consumer project) |
| **AC-10** | `:shared-components:allTests` is green; `./gradlew check` clean; no platform types in `commonMain`. | CI + manual grep |
| **AC-11** | `NumberInputViewModel` state machine has a `commonTest` driving Idle → Editing → Committed → Idle with Turbine. | `:shared-components:allTests` |
| **AC-12** | All toolbar buttons have an `accessibilityIdentifier` for XCUITest selection and a `accessibilityLabel` for VoiceOver. | Manual VoiceOver pass + UI tests |

---

## 9. Non-Functional Requirements

| ID | Requirement |
|---|---|
| **NFR-01** | Formatter call (`format(value, locale)`) SHALL return within 5 ms p99 on iPhone 13 or newer (NSNumberFormatter is well within this; included as a regression budget). |
| **NFR-02** | The Swift Package SHALL NOT introduce any non-Apple runtime dependencies (no SwiftSyntax, no third-party packages) — only the XCFramework binary target. |
| **NFR-03** | The component SHALL support iOS 16+ (matches the skeleton's existing iOS minimum; lets us use modern SwiftUI `.toolbar(placement: .keyboard)` and `@FocusState`). |
| **NFR-04** | Memory: no retain cycles between SwiftUI view and the underlying `UITextField` Coordinator (verified with Instruments leak run during smoke). |
| **NFR-05** | Thread safety: `NumberInputViewModel` SHALL only mutate state from its `viewModelScope` main dispatcher. |

---

## 10. Open Architectural Decisions

These are the decisions that need to be **resolved before** the Sonnet implementation pass.

### 10.A — Numeric type at the API surface

| Option | Pro | Con |
|---|---|---|
| **A1. `Double?` everywhere** | Simplest; Kotlin-native; SwiftUI binds via `Double` cleanly | IEEE-754 precision loss — `0.1 + 0.2 == 0.3` is `false`; subtle bugs in significantDigits rounding |
| **A2. `Decimal?` (iOS), `String + scale` (KMP)** | Avoids precision loss in iOS-facing surface; matches Apple's recommendation for monetary-like values | KMP has no `Decimal` type in commonMain; needs an `expect class Decimal` or a `String + Int scale` representation |
| **A3. `String` everywhere, parse at consumer** | Maximally portable; no precision questions | Pushes parsing burden to every consumer; worst DX |

**Recommendation:** **A1** for v1 (general numeric input, precision-3 is well within `Double` safety). Flag a TODO to revisit if a `:shared-components:CurrencyInput` lands later — that one needs A2.

### 10.B — `significantDigits` vs `fractionDigits` API name

See §6. **Recommendation:** keep `significantDigits` per your preference, define semantics precisely as fractional digits. Confirm before implementation.

### 10.C — Sample / showcase placement

Where does the demo screen for this component live?

| Option | Pro | Con |
|---|---|---|
| **C1. `:shared-app/.../showcase/numberinput/`** | Matches existing `Greeting` showcase pattern | Currently `:shared-app` has no other showcase entry |
| **C2. SwiftUI preview in the Swift Package** | Self-contained; visible in Xcode previews to external SPM consumers | Doesn't exercise the KMP shared logic from `:shared-app` |
| **C3. Both** | Best of both worlds | More files; minor duplication |

**Recommendation:** **C3** — small SwiftUI preview lives inside the Swift Package (for SPM consumers), and a `NumberInputShowcaseScreen` in `:shared-app` for the in-repo demo.

### 10.D — Sign-toggle button placement order

iOS keyboard accessory bars are read left-to-right. The toolbar group has three buttons. Conventional iOS apps order destructive/utility on the **left** and confirmation on the **right** ([Apple HIG: Toolbars](https://developer.apple.com/design/human-interface-guidelines/toolbars)).

| Option | Layout |
|---|---|
| **D1.** `[Clear] [±] [···flex···] [Done]` | Recommended — matches HIG; Done is the primary action on the right |
| **D2.** `[±] [Clear] [···flex···] [Done]` | ± most prominent on the left |
| **D3.** `[···flex···] [Clear] [±] [Done]` | All grouped right |

**Recommendation:** **D1**. UI spec (`NUMBER-INPUT-UI.md` §2) renders this.

---

## 11. Distribution Architecture (SPM Hybrid)

Per your decision, distribution is hybrid: KMP module produces the formatter logic and state machine; a Swift Package wraps the XCFramework and adds SwiftUI views.

```
   ┌──────────────────────────────────────────────────────────────┐
   │ skeleton repo                                                │
   │                                                              │
   │  :shared-components (KMP)                                    │
   │   ├ commonMain                                               │
   │   │   ├ NumberInputViewModel.kt                              │
   │   │   ├ NumberInputUiState.kt                                │
   │   │   └ LocaleNumberFormatter.kt   (expect)                  │
   │   ├ iosMain                                                  │
   │   │   └ LocaleNumberFormatter.kt   (actual, NSNumberFormatter)│
   │   └ build.gradle.kts → exports XCFramework: SharedComponents │
   │                                                              │
   │  swift-package/NumberInput/         (new — SPM root)         │
   │   ├ Package.swift                                            │
   │   ├ Sources/NumberInput/                                     │
   │   │   ├ NumberInputField.swift  (SwiftUI view)               │
   │   │   ├ KeyboardToolbar.swift   (Done/Clear/± view)          │
   │   │   └ NumberInputViewModel+Extensions.swift                │
   │   ├ Sources/NumberInput.binaryTarget → SharedComponents.xcframework │
   │   └ Tests/NumberInputTests/                                  │
   │                                                              │
   │  :iosApp/iosApp.xcodeproj                                    │
   │   └ Adds the local Swift Package `swift-package/NumberInput` │
   │     via "Add Local Package…" — same pattern other org apps   │
   │     follow when consuming the published version.             │
   └──────────────────────────────────────────────────────────────┘

   Other org iOS apps consume via:
     .package(url: "https://github.com/<org>/skeleton-number-input", from: "1.0.0")
```

**Open decision:** is the Swift Package hosted in the **same repo** (subdirectory like `swift-package/NumberInput/`) or **extracted** to its own repo for publishing? See §14.E.

---

## 12. Risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| `.decimalPad` keyboard accessory edge cases on iPad (split keyboard, external keyboard) | Medium | Low | Manual smoke on iPad simulator; document known limitations |
| Cursor-jumping during live formatting (well-documented problem; see [edw/swiftui-numberfield](https://github.com/edw/swiftui-numberfield)) | High if we format mid-typing | Medium | **Mitigated by design**: format only on commit / focus loss, not per keystroke (FR-06) |
| `Double` precision drift across very small or very large values | Low for v1 (general input, sig digits ≤ 6 typical) | Low–Medium | Document the `Double` choice in §10.A; flag for currency follow-up |
| XCFramework as `.binaryTarget` requires careful versioning when consumers SPM-pull | Medium | Medium | Implementation plan §11.5 covers versioning + checksum protocol |
| SKIE limitation — `:shared-components` has `skie { isEnabled = false }` (per [`docs/auth/LOGIN-PRD.md`](../auth/LOGIN-PRD.md) §1.4 / `shared-components/build.gradle.kts:66-71`). iOS Swift consumers cannot use SKIE-generated sugar | Confirmed | Medium | Use the existing per-VM helper pattern from `GreetingViewModelHelper.kt`. Implementation plan §10.6 spells this out. |
| Locale data drift between Apple's ICU and other platforms (when Android joins later) | Medium | Low | Snapshot test against fixed reference outputs per locale |

---

## 13. Future Work (Explicitly Deferred)

1. **Android Compose adapter** — `androidMain` `actual` of `LocaleNumberFormatter` via `java.text.DecimalFormat`, plus a Jetpack Compose `NumberInputField` composable.
2. **Currency mode** — currency symbol, currency-code lookup, separate component.
3. **Percentage mode** — auto-append `%`, multiply/divide for `value` vs displayed.
4. **Scientific notation toggle**.
5. **Custom toolbar items** — let consumers add app-specific buttons (e.g., a "max" button for a transfer screen).
6. **`Decimal` precision upgrade** — when currency lands, formalize the `expect class Decimal` or `String + scale` representation.

---

## 14. Decisions to Resolve Before Implementation

**Status: RESOLVED 2026-05-19 — all five decisions approved as recommended. Ready for Sonnet implementation pass.**

- [x] **§10.A** Numeric type: **`Double?`** (A1). Flag for revisit if/when a Currency component lands.
- [x] **§10.B** API name: **`significantDigits`** kept per product preference. Semantics documented precisely as "fixed digits after the decimal point, padded with trailing zeros, rounded half-to-even" (= `NSNumberFormatter.minimumFractionDigits == maximumFractionDigits`). KDoc on `NumberInputConfig.significantDigits` must spell this out.
- [x] **§10.C** Showcase placement: **C3** — Swift Package Xcode preview + `:shared-app` showcase screen.
- [x] **§10.D** Toolbar layout: **`[Clear] [±] [···flex···] [Done]`** (D1, matches Apple HIG).
- [x] **§11** Swift Package hosting: **in-repo** `swift-package/NumberInput/` subfolder for v1. Promotion to its own repo is a separate workstream after AC-09 passes.
- [x] **Plan §5.2** Toolbar construction: **SwiftUI `ToolbarItemGroup(placement: .keyboard)`** accepted as the implementation technique for FR-02 (renders as `UIBarButtonItem`s internally, visually + behaviorally identical to a hand-rolled `inputAccessoryView`). UIViewRepresentable fallback is documented as a v2 option only if `ToolbarItemGroup` proves problematic inside `Form`/`List` rows.

---

## 15. References

### Open-source prior art (researched 2026-05-19)

- [NumberTextField (mikeCenters)](https://github.com/mikeCenters/NumberTextField) — SwiftUI live-formatting w/ `Decimal` binding, `.inputAccessory` API. Closest pattern match.
- [CurrencyText (marinofelipe)](https://github.com/marinofelipe/CurrencyText) — UIKit+SwiftUI, three SPM targets, builder-pattern config.
- [swiftui-numberfield (edw)](https://github.com/edw/swiftui-numberfield) — Two-Decimal trick to avoid cursor-jump on live format.
- [SwiftNumberPad (openalloc)](https://github.com/openalloc/SwiftNumberPad) — Custom pad (not text-field based). Different use case.
- [swiftui-currency-field (jtrinc)](https://github.com/jtrinc/swiftui-currency-field) — Banking RTL fill, Int-cents binding.
- [pale-blue-kmp-core](https://www.paleblueapps.com/rockandnull/kmp-currency-number-formatter-kmmresult/) — KMP NumberFormatter / CurrencyFormatter, native-backed.
- [Cash App: Multiplatform Money Formatter](https://code.cash.app/kotlin-multiplatform-money-formatter) — Hybrid pattern (delegate to NSNumberFormatter / ICU).
- [Kotlin Multiplatform regional format docs](https://kotlinlang.org/docs/multiplatform/compose-regional-format.html).

### Apple references

- [`UITextField.inputAccessoryView`](https://developer.apple.com/documentation/uikit/uitextfield/1619638-inputaccessoryview)
- [`UIToolbar` + `UIBarButtonItem`](https://developer.apple.com/documentation/uikit/uitoolbar)
- [`NSNumberFormatter`](https://developer.apple.com/documentation/foundation/numberformatter)
- [`ToolbarItemGroup(placement: .keyboard)`](https://developer.apple.com/documentation/swiftui/toolbaritemplacement/keyboard) — modern SwiftUI alternative; chosen over `inputAccessoryView` (FR-02 wording aside) when possible
- [Apple HIG: Toolbars](https://developer.apple.com/design/human-interface-guidelines/toolbars)
- [`@FocusState`](https://developer.apple.com/documentation/swiftui/focusstate) for keyboard dismissal coordination

### Internal references

- [`CLAUDE.md`](../../CLAUDE.md) — coding standards
- [`architecture.md`](../../architecture.md) — module graph + iOS `ViewModel` bridge
- [`shared-core/.../theme/DesignTokens.kt`](../../shared-core/src/commonMain/kotlin/dev/viethung/core/theme/DesignTokens.kt) — design tokens (no raw colors in views)
- [`shared-components/build.gradle.kts`](../../shared-components/build.gradle.kts) — current SKIE-off configuration
