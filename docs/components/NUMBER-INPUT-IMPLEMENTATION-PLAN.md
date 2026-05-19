# Reusable Number Input — Technical Implementation Plan

**Status:** **Approved 2026-05-19** — PRD §14 sign-off complete; ready for Sonnet execution pass
**Owner:** _to be assigned (Sonnet dig)_
**Audience:** Engineer (or Sonnet agent) implementing the component in this skeleton
**Companion docs:** [`NUMBER-INPUT-PRD.md`](./NUMBER-INPUT-PRD.md), [`NUMBER-INPUT-UI.md`](./NUMBER-INPUT-UI.md), [`../../CLAUDE.md`](../../CLAUDE.md), [`../../architecture.md`](../../architecture.md)

---

## Validation Summary

**Validated:** 2026-05-19
**Questions asked:** 4 (genuine implementation ambiguities not resolved by PRD §14)

### Confirmed Decisions

1. **Formatter declaration shape (Plan §4.3, §8.1, §12 risk #1)**
   → **Interface + expect factory.** `interface LocaleNumberFormatter` + `expect fun newLocaleNumberFormatter(): LocaleNumberFormatter`. `FakeLocaleNumberFormatter` becomes a trivial commonTest implementation. Decision locked in at Step 1.

2. **`allowNegative = false` clamp (AC-08, Plan §4.2, §4.4)**
   → **VM-side clamp in `init` + `onTextChange`.** In `NumberInputViewModel.init`: if `allowNegative=false && initialValue<0` → coerce to `0.0`. In `onTextChange`: if parsed value is negative & `allowNegative=false` → reject the change (keep prior value, update `rawText` only). `onToggleSign` no-op when `allowNegative=false` is unchanged.

3. **`decimalSeparator(locale)` API (Plan §4.3, §4.5)**
   → **Drop for v1.** Remove from both `expect` declaration and the iOS `actual`. No consumer calls it. Re-add when a future consumer (amount/currency input) needs it. CLAUDE.md §1 ("no abstractions for single-use code").

4. **Showcase scope (PRD §10.C / §14 vs Plan §7.2)**
   → **Build both per PRD C3.** Implement `NumberInputShowcaseViewModel.kt` in `:shared-app` AND `NumberInputPreviews.swift` (Swift package) AND `NumberInputShowcaseView.swift` (iosApp). Plan §7.2 wording ("optional") was the contradiction; PRD §14 §10.C resolution is binding.

### Action Items — **all applied 2026-05-19**

- [x] **§4.3** — Rewrote `LocaleNumberFormatter` contract as `interface` + `expect fun newLocaleNumberFormatter()`. Removed `decimalSeparator(locale)`.
- [x] **§4.5** — Updated iOS impl: private `IosLocaleNumberFormatter : LocaleNumberFormatter` + `actual fun newLocaleNumberFormatter()`. Removed `decimalSeparator` implementation.
- [x] **§4.2** — Added `seedValue` clamp (negative `initialValue` → `0.0` when `allowNegative=false`) as a property initializer. Documented `onTextChange` rejection of negative parsed values in the body comment + implementation notes.
- [x] **§4.4** — Added full KDoc on `NumberInputConfig` including the `allowNegative` clamp semantics. No `require` added — clamp lives in the VM (consistent with the decision); KDoc points at §4.2.
- [x] **§7.2** — Removed "Skip if … sufficient" language. Section now reads **REQUIRED per PRD §10.C C3**.
- [x] **§8.1** — Updated `FakeLocaleNumberFormatter` snippet to `: LocaleNumberFormatter` (interface impl, no `()` constructor + no `expect`-class workaround).
- [x] **§8.1** — Added VM test rows #12 (clamp on init) and #13 (clamp on `onTextChange`).
- [x] **§9 Step 2 gate** — Updated to mention the interface + `newLocaleNumberFormatter()` symbols by name.
- [x] **§12 risk #1** — Marked **RESOLVED 2026-05-19**; row struck through with reference to Validation Summary decision #1.

### Recommendation

**Proceed to implementation.** Plan body is now aligned with the four validated decisions; PRD §14 decisions and the §9 ten-step build order are intact.

---

## Related Docs (READ before implementing)

- **PRD:** [`NUMBER-INPUT-PRD.md`](./NUMBER-INPUT-PRD.md) — requirements, acceptance criteria, open decisions (§14)
- **UI Spec:** [`NUMBER-INPUT-UI.md`](./NUMBER-INPUT-UI.md) — state machine, toolbar layout, locale rules
- **Style:** [`CLAUDE.md`](../../CLAUDE.md) §2 (coding standards), §3 (architecture), §4 (platform bindings)
- **Reference feature:** [`auth/LOGIN-IMPLEMENTATION-PLAN.md`](../auth/LOGIN-IMPLEMENTATION-PLAN.md) — sibling pattern this plan mirrors

---

## 1. Goal

Build a reusable, locale-aware, signed numeric input component:

1. **Shared logic** in `:shared-components` (Kotlin Multiplatform): `NumberInputViewModel`, `NumberInputUiState`, `LocaleNumberFormatter` (`expect`/`actual`).
2. **iOS UI** in a new in-repo **Swift Package** (`swift-package/NumberInput/`): `NumberInputField` (SwiftUI view), `KeyboardToolbar` (UIKit toolbar wrapped as accessory view), bridging code.
3. **Showcase** in `:shared-app` + Swift Package Xcode preview.
4. **Tests**: `commonTest` for the VM + formatter contract; XCTest for the SwiftUI view; manual smoke against three locales.

This document tells the implementer **what to build, in what order, where it lives, and why**. It does NOT contain the final source code — it contains contracts, signatures, and step-by-step gates.

---

## 2. Why This Plan Looks the Way It Does

The skeleton's pattern is **MVVM with a shared `ViewModel` exposing `StateFlow<UiState>`** (per [`architecture.md`](../../architecture.md)). The KMP module provides the contract; each platform renders. Per CLAUDE.md §3:

> `:shared-components` — reusable component ViewModels + `expect`/`actual` services (forms, amount input, sidebar nav, notifications).

This is the **first** component to be built in `:shared-components`. The structure we lay down here will be copy-pasted by future components (currency input, amount input, sidebar nav). That means:

- **Be conservative.** Don't speculate features beyond the PRD.
- **Be precise.** Where there's a design call, document it. The next component will inherit the pattern.
- **Mirror the auth feature.** The Login implementation plan is the closest sibling. Match its file layout cadence (one VM, one UiState, one expect/actual pair, one helper).

```
   [SwiftUI NumberInputField]                 [Compose NumberInputField — FUTURE]
        │ binding: @State amount: Double?          │ (Android adapter deferred)
        ▼
        ────── NumberInputViewModel  (commonMain) ─────
                       │  state: StateFlow<NumberInputUiState>
                       │
                       ▼
              LocaleNumberFormatter (expect)
              ├─ iosMain actual: NSNumberFormatter-backed
              └─ androidMain actual: DecimalFormat — FUTURE
```

---

## 3. Where Each Piece Lives

```
skeleton/
├── shared-components/
│   ├── build.gradle.kts                    [MODIFY — §6.1]
│   └── src/
│       ├── commonMain/kotlin/dev/viethung/components/numberinput/
│       │   ├── NumberInputUiState.kt        [NEW — §4.1]
│       │   ├── NumberInputViewModel.kt      [NEW — §4.2]
│       │   ├── LocaleNumberFormatter.kt     [NEW — §4.3, expect]
│       │   └── NumberInputConfig.kt         [NEW — §4.4, value class for sig digits + bounds]
│       ├── iosMain/kotlin/dev/viethung/components/numberinput/
│       │   ├── LocaleNumberFormatter.ios.kt [NEW — §4.5, actual]
│       │   └── NumberInputViewModelHelper.kt[NEW — §4.6, SKIE-less iOS bridge]
│       ├── commonTest/kotlin/dev/viethung/components/numberinput/
│       │   ├── NumberInputViewModelTest.kt  [NEW — §8.1]
│       │   └── LocaleNumberFormatterContractTest.kt [NEW — §8.2, exercised on iosTest]
│       └── (androidMain — UNCHANGED for now; android actual deferred to follow-up)
│
├── shared-app/
│   └── src/commonMain/kotlin/dev/viethung/showcase/numberinput/
│       └── (showcase wiring stub — §7.1)
│
├── swift-package/                          [NEW directory at repo root]
│   └── NumberInput/
│       ├── Package.swift                   [NEW — §6.2]
│       ├── Sources/NumberInput/
│       │   ├── NumberInputField.swift      [NEW — §5.1]
│       │   ├── KeyboardToolbar.swift       [NEW — §5.2]
│       │   ├── NumberInputCoordinator.swift[NEW — §5.3, UIViewRepresentable]
│       │   ├── DesignTokenBridge.swift     [NEW — §5.4, tokens → SwiftUI Color/Font]
│       │   └── Preview/NumberInputPreviews.swift [NEW — §5.5]
│       ├── Sources/NumberInputBinary/      [NEW — §6.2.b]
│       │   └── (XCFramework .binaryTarget reference)
│       └── Tests/NumberInputTests/
│           └── NumberInputFieldTests.swift [NEW — §8.3]
│
└── iosApp/
    └── iosApp.xcodeproj                    [MODIFY — §6.3]
        └── (add local package reference to swift-package/NumberInput)
```

> **Rationale for `swift-package/` at repo root** (not under `iosApp/`): `Package.swift` resolves paths relative to itself; placing the package at the repo root keeps the relative path to the XCFramework artifact short and stable, and it sits next to `androidApp/`, `iosApp/`, `shared-*` as a sibling — consistent with how the repo treats top-level concerns.

---

## 4. Shared (KMP) Files — Detailed Contracts

### 4.1 `NumberInputUiState.kt` (commonMain)

```kotlin
package dev.viethung.components.numberinput

/**
 * Sealed UI state for [NumberInputViewModel].
 * See NUMBER-INPUT-PRD.md §7 and NUMBER-INPUT-UI.md §3.
 */
sealed interface NumberInputUiState {
    val rawText: String          // unformatted, what the user is typing
    val formattedText: String    // what's shown when not focused
    val value: Double?           // parsed numeric, null if empty
    val significantDigits: Int
    val locale: String           // BCP-47, e.g. "en-US"
    val allowNegative: Boolean

    data class Idle(
        override val rawText: String,
        override val formattedText: String,
        override val value: Double?,
        override val significantDigits: Int,
        override val locale: String,
        override val allowNegative: Boolean,
    ) : NumberInputUiState

    data class Editing(
        override val rawText: String,
        override val formattedText: String,    // last-known formatted; not re-computed mid-edit
        override val value: Double?,
        override val significantDigits: Int,
        override val locale: String,
        override val allowNegative: Boolean,
    ) : NumberInputUiState

    data class Committed(
        override val rawText: String,
        override val formattedText: String,
        override val value: Double?,
        override val significantDigits: Int,
        override val locale: String,
        override val allowNegative: Boolean,
    ) : NumberInputUiState
}
```

**Contract:**
- Three branches: `Idle`, `Editing`, `Committed` — matches UI spec §3.
- All fields are non-null except `value` (which is `null` when the field is empty).
- `Committed` is a transient state — VM emits it then immediately transitions to `Idle` on the next frame (see §4.2 `onCommit`).

### 4.2 `NumberInputViewModel.kt` (commonMain)

```kotlin
package dev.viethung.components.numberinput

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

class NumberInputViewModel(
    private val formatter: LocaleNumberFormatter,
    initialValue: Double? = null,
    private val significantDigits: Int = 2,
    private val locale: String = "en-US",
    private val allowNegative: Boolean = true,
) : ViewModel() {

    // Per Validation Summary decision #2 / AC-08: clamp negative initialValue to 0.0 when allowNegative=false.
    private val seedValue: Double? =
        if (!allowNegative && initialValue != null && initialValue < 0.0) 0.0 else initialValue

    private val _state: MutableStateFlow<NumberInputUiState> = MutableStateFlow(
        NumberInputUiState.Idle(
            rawText = seedValue?.toString().orEmpty(),
            formattedText = seedValue?.let { formatter.format(it, significantDigits, locale) }.orEmpty(),
            value = seedValue,
            significantDigits = significantDigits,
            locale = locale,
            allowNegative = allowNegative,
        )
    )
    val state: StateFlow<NumberInputUiState> = _state.asStateFlow()

    // ── User events ──────────────────────────────────────────────────

    fun onFocusChanged(focused: Boolean) { /* Idle <-> Editing */ }

    fun onTextChange(newRawText: String) {
        /* Parse via formatter.parse(newRawText, locale), then:
           - If allowNegative == false AND parsed < 0 → REJECT the value change
             (keep prior state.value), but still update state.rawText so the user
             sees what they typed. Same shape as the parse-failure path.
           - Else update state.value to the parse result and state.rawText to newRawText.
           Per AC-08. */
    }

    fun onToggleSign() { /* value -> -value, no-op if null or !allowNegative */ }

    fun onClear() { /* rawText="", value=null, stay Editing */ }

    fun onCommit() { /* format, emit Committed, then Idle */ }
}
```

**Implementation notes for Sonnet:**
- All state mutations happen on `viewModelScope` (uses main dispatcher by default).
- `onTextChange` parses with the locale's decimal separator. If parse fails, keep the old `value` but update `rawText` (caller sees the raw text, value doesn't drift).
- `onTextChange` with `allowNegative=false` and a negative parsed value: same shape — keep prior `value`, update `rawText` only.
- `onCommit` emits `Committed` then immediately re-emits `Idle` with the same payload — view collects the `Idle` re-emission as the "settled" state.
- `onToggleSign` when `allowNegative == false` is a strict no-op; do NOT throw.
- Do NOT add `init {}` side effects beyond setting `_state` (the `seedValue` clamp is a property initializer, not a side effect). The VM's behavior is event-driven only.

### 4.3 `LocaleNumberFormatter.kt` (commonMain — interface + expect factory)

```kotlin
package dev.viethung.components.numberinput

/**
 * Locale-aware number formatter contract. Implemented per platform via [newLocaleNumberFormatter].
 * Declared as `interface` (not `expect class`) so commonTest can supply a `FakeLocaleNumberFormatter`
 * trivially — see Validation Summary decision #1 and §8.1.
 */
interface LocaleNumberFormatter {
    /**
     * Format [value] for display with exactly [significantDigits] digits after the decimal point.
     * @param locale BCP-47 tag (e.g. "en-US"). Falls back to platform default if blank.
     * @return formatted string per locale's grouping + decimal symbols + half-even rounding.
     */
    fun format(value: Double, significantDigits: Int, locale: String): String

    /**
     * Parse a user-typed [rawText] into a [Double] using [locale]'s decimal separator.
     * Grouping separators are tolerated but not required.
     * @return parsed value, or null if [rawText] is empty / unparseable.
     */
    fun parse(rawText: String, locale: String): Double?
}

/** Platform factory — iOS uses NSNumberFormatter; Android (future) uses java.text.DecimalFormat. */
expect fun newLocaleNumberFormatter(): LocaleNumberFormatter
```

### 4.4 `NumberInputConfig.kt` (commonMain)

```kotlin
package dev.viethung.components.numberinput

/**
 * Immutable configuration for a NumberInput instance.
 * Keep this separate from UiState so the VM constructor stays short.
 *
 * @property significantDigits Fixed digits after the decimal point. Padded with trailing zeros;
 *   rounded half-to-even. Equivalent to `NSNumberFormatter.minimumFractionDigits == maximumFractionDigits`.
 *   Must be in 0..9 (enforced by `init`).
 * @property locale BCP-47 tag (e.g. "en-US", "vi-VN"). Used by [LocaleNumberFormatter].
 * @property allowNegative When `false`, [NumberInputViewModel] clamps a negative `initialValue` to
 *   `0.0` and rejects negative text input (see §4.2). The ± toolbar button is also disabled.
 *   Validation lives in the VM, not here, so this data class stays a pure value carrier.
 * @property placeholder Empty-state hint shown by the platform field.
 */
data class NumberInputConfig(
    val significantDigits: Int = 2,
    val locale: String = "en-US",
    val allowNegative: Boolean = true,
    val placeholder: String = "",
) {
    init {
        require(significantDigits in 0..9) {
            "significantDigits must be in 0..9, got $significantDigits"
        }
    }
}
```

> **Note for PRD §10.B:** API keeps the user-requested name `significantDigits`. The KDoc above spells out the semantics ("fixed digits after the decimal point; padded with trailing zeros; rounded half-to-even").

### 4.5 `LocaleNumberFormatter.ios.kt` (iosMain — actual factory + private impl)

```kotlin
package dev.viethung.components.numberinput

import platform.Foundation.NSLocale
import platform.Foundation.NSNumber
import platform.Foundation.NSNumberFormatter
import platform.Foundation.NSNumberFormatterDecimalStyle
import platform.Foundation.NSNumberFormatterRoundHalfEven

private class IosLocaleNumberFormatter : LocaleNumberFormatter {

    override fun format(value: Double, significantDigits: Int, locale: String): String {
        val nf = NSNumberFormatter().apply {
            this.locale = NSLocale(localeIdentifier = locale)
            this.numberStyle = NSNumberFormatterDecimalStyle
            this.usesGroupingSeparator = true
            this.minimumFractionDigits = significantDigits.toULong()
            this.maximumFractionDigits = significantDigits.toULong()
            this.roundingMode = NSNumberFormatterRoundHalfEven
        }
        return nf.stringFromNumber(NSNumber(double = value)).orEmpty()
    }

    override fun parse(rawText: String, locale: String): Double? {
        if (rawText.isBlank()) return null
        val nf = NSNumberFormatter().apply {
            this.locale = NSLocale(localeIdentifier = locale)
            this.numberStyle = NSNumberFormatterDecimalStyle
        }
        // Two-pass: NumberFormatter, then String.toDouble() as fallback for "-" / "0.5" w/o grouping.
        return nf.numberFromString(rawText)?.doubleValue
            ?: rawText.replace(nf.groupingSeparator.orEmpty(), "")
                .replace(nf.decimalSeparator.orEmpty(), ".")
                .toDoubleOrNull()
    }
}

actual fun newLocaleNumberFormatter(): LocaleNumberFormatter = IosLocaleNumberFormatter()
```

**Verification (FR-07 / AC-07):**
- `format(0.1, 3, "en-US")` → `"0.100"`
- `format(1.23456, 2, "en-US")` → `"1.23"` (half-even)
- `format(1234567.89, 2, "vi-VN")` → `"1.234.567,89"`

### 4.6 `NumberInputViewModelHelper.kt` (iosMain) — SKIE-less iOS bridge

Per PRD §12, `:shared-components` has `skie { isEnabled = false }`. Mirror the auth pattern (`GreetingViewModelHelper.kt` / `LoginViewModelHelper.kt`):

```kotlin
package dev.viethung.components.numberinput

import androidx.lifecycle.ViewModelStore
import androidx.lifecycle.ViewModelStoreOwner
import androidx.lifecycle.ViewModelProvider
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.launch

/**
 * iOS bridge — creates a [NumberInputViewModel] backed by a [ViewModelStoreOwner]
 * and subscribes Swift to its [NumberInputUiState] stream.
 */

fun createNumberInputViewModel(
    storeOwner: ViewModelStoreOwner,
    formatter: LocaleNumberFormatter,
    initialValue: Double?,
    config: NumberInputConfig,
): NumberInputViewModel {
    val provider = ViewModelProvider(
        store = storeOwner.viewModelStore,
        factory = object : ViewModelProvider.Factory {
            override fun <T : androidx.lifecycle.ViewModel> create(modelClass: kotlin.reflect.KClass<T>, extras: androidx.lifecycle.viewmodel.CreationExtras): T {
                @Suppress("UNCHECKED_CAST")
                return NumberInputViewModel(
                    formatter = formatter,
                    initialValue = initialValue,
                    significantDigits = config.significantDigits,
                    locale = config.locale,
                    allowNegative = config.allowNegative,
                ) as T
            }
        }
    )
    return provider[NumberInputViewModel::class]
}

fun subscribeNumberInputState(
    vm: NumberInputViewModel,
    onState: (NumberInputUiState) -> Unit,
): Job {
    val scope = CoroutineScope(Dispatchers.Main)
    return scope.launch { vm.state.collect { onState(it) } }
}
```

> **Implementation note:** confirm the exact `ViewModelProvider` API used by the Login helper at implementation time — Kotlin 2.3.21 / lifecycle-viewmodel-savedstate APIs may have shifted. Match `LoginViewModelHelper.kt` exactly. Do NOT diverge.

---

## 5. Swift Package — Detailed File Contracts

### 5.1 `NumberInputField.swift` (Sources/NumberInput/)

```swift
import SwiftUI
import SharedComponents   // the XCFramework — see §6.2.b

public struct NumberInputField: View {

    @Binding var value: Double?
    let config: NumberInputConfig
    let placeholder: String

    @StateObject private var bridge: NumberInputBridge
    @FocusState private var focused: Bool

    public init(
        value: Binding<Double?>,
        significantDigits: Int = 2,
        locale: Locale = .current,
        allowNegative: Bool = true,
        placeholder: String = ""
    ) {
        self._value = value
        self.config = NumberInputConfig(
            significantDigits: Int32(significantDigits),
            locale: locale.identifier,
            allowNegative: allowNegative,
            placeholder: placeholder
        )
        self.placeholder = placeholder
        self._bridge = StateObject(wrappedValue: NumberInputBridge(
            initialValue: value.wrappedValue,
            config: config
        ))
    }

    public var body: some View {
        TextField(placeholder, text: bridge.textBinding(focused: focused))
            .keyboardType(.decimalPad)
            .focused($focused)
            .accessibilityIdentifier("numberInput.field")
            .toolbar { KeyboardToolbar(bridge: bridge, focused: $focused) }
            .onChange(of: focused) { _, isFocused in
                bridge.handleFocus(focused: isFocused)
            }
            .onReceive(bridge.$publishedValue) { newValue in
                value = newValue
            }
    }
}
```

**Contract:**
- `value: Binding<Double?>` — bi-directional.
- Field renders `rawText` when focused, `formattedText` when not.
- `@FocusState` drives the toolbar's keyboard accessory.
- `bridge: NumberInputBridge` — Swift wrapper around the Kotlin VM (see §5.3).

### 5.2 `KeyboardToolbar.swift`

```swift
import SwiftUI

struct KeyboardToolbar: ToolbarContent {
    @ObservedObject var bridge: NumberInputBridge
    @FocusState.Binding var focused: Bool

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .keyboard) {
            // Layout: [Clear] [±] [···flex···] [Done]
            Button(action: { bridge.clear() }) {
                Text("Clear")
            }
            .accessibilityIdentifier("numberInput.toolbar.clear")
            .disabled(bridge.clearDisabled)

            Button(action: { bridge.toggleSign() }) {
                Image(systemName: "plus.slash.minus")
            }
            .accessibilityIdentifier("numberInput.toolbar.toggleSign")
            .disabled(bridge.signDisabled)

            Spacer()

            Button(action: {
                bridge.commit()
                focused = false
            }) {
                Text("Done").bold()
            }
            .accessibilityIdentifier("numberInput.toolbar.done")
        }
    }
}
```

> **Why `ToolbarItemGroup(placement: .keyboard)` instead of `inputAccessoryView`:** modern SwiftUI API, attaches to the focused field automatically, survives modal sheets, no `UIViewRepresentable` plumbing. Matches the [Hacking with Swift toolbar pattern](https://www.hackingwithswift.com/quick-start/swiftui/how-to-show-a-toolbar-above-the-keyboard) but adapted for our three-button layout.

> **Caveat:** PRD FR-02 mentions "UIBarButtonItem" — `ToolbarItemGroup(placement: .keyboard)` renders SwiftUI buttons internally backed by `UIBarButtonItem`s. The visual + interaction outcome is identical to a manual `UIToolbar` + `inputAccessoryView`. Confirm this satisfies the requirement (it should — the screenshot from your goal description showed an iOS keyboard toolbar, not a specific construction technique). If product wants explicit `UITextField.inputAccessoryView`, swap §5.1 to `UIViewRepresentable` wrapping `UITextField` — adds ~80 LoC and the cursor-jump risk surface; not recommended.

### 5.3 `NumberInputCoordinator.swift` / `NumberInputBridge`

```swift
import Foundation
import Combine
import SharedComponents

final class NumberInputBridge: ObservableObject {
    @Published private(set) var displayText: String = ""
    @Published private(set) var publishedValue: Double?
    @Published private(set) var clearDisabled: Bool = true
    @Published private(set) var signDisabled: Bool = true

    private let viewModel: NumberInputViewModel
    private let storeOwner: IosViewModelStoreOwner
    private var subscriptionJob: Kotlinx_coroutines_coreJob?

    init(initialValue: Double?, config: NumberInputConfig) {
        let formatter = LocaleNumberFormatter()
        let owner = IosViewModelStoreOwner()
        self.storeOwner = owner
        self.viewModel = NumberInputViewModelHelperKt.createNumberInputViewModel(
            storeOwner: owner,
            formatter: formatter,
            initialValue: initialValue.map { KotlinDouble(value: $0) },
            config: config
        )
        self.subscriptionJob = NumberInputViewModelHelperKt.subscribeNumberInputState(vm: viewModel) { state in
            DispatchQueue.main.async { self.apply(state: state) }
        }
    }

    deinit { subscriptionJob?.cancel(cause: nil) }

    func textBinding(focused: Bool) -> Binding<String> { /* see §5.3 notes */ }

    func handleFocus(focused: Bool) { viewModel.onFocusChanged(focused: focused) }
    func clear()       { viewModel.onClear() }
    func toggleSign()  { viewModel.onToggleSign() }
    func commit()      { viewModel.onCommit() }

    private func apply(state: NumberInputUiState) {
        displayText = (state is NumberInputUiStateEditing) ? state.rawText : state.formattedText
        publishedValue = state.value?.doubleValue
        clearDisabled = state.rawText.isEmpty && state.value == nil
        signDisabled = !state.allowNegative || state.value == nil
    }
}
```

**Implementation notes:**
- `IosViewModelStoreOwner` already exists at [`iosApp/iosApp/Common/IosViewModelStoreOwner.swift`](../../iosApp/iosApp/Common/IosViewModelStoreOwner.swift) — same pattern as Login.
- The `textBinding(focused:)` Binding writes go through `viewModel.onTextChange(newRawText:)`; reads return `displayText`. Document the pattern in code comments.
- The `KotlinDouble`-wrapping for nullable Double is a Kotlin/Native interop quirk; confirm the exact bridging type with what `NumberInputViewModel.kt`'s `initialValue: Double?` exposes through the iosMain `expect` boundary.

### 5.4 `DesignTokenBridge.swift`

Re-uses the existing tokens bridge from `:shared-core/.../theme/DesignTokens.kt` (CLAUDE.md §4). If a Swift-side adapter doesn't yet exist for `:shared-components` (it currently lives in `:iosApp`), add a thin one inside the Swift Package that imports the XCFramework's tokens and maps them to SwiftUI `Color`/`Font`. Document this as a one-line copy from `iosApp/iosApp/Theme/`.

### 5.5 `NumberInputPreviews.swift`

SwiftUI Xcode previews showing the field in `en-US`, `vi-VN`, `de-DE` — matches UI spec §7. Useful for external SPM consumers browsing the package.

---

## 6. Build & Distribution Configuration

### 6.1 `shared-components/build.gradle.kts` — MODIFY

Confirm the XCFramework export already includes everything we add:

```kotlin
// existing:
listOf(
    iosX64(),
    iosArm64(),
    iosSimulatorArm64()
).forEach {
    it.binaries.framework {
        baseName = "SharedComponents"
        isStatic = false
        // Ensure ViewModel + the new types are accessible:
        export(libs.androidx.lifecycle.viewmodel)
    }
}
```

**No new dependencies in `libs.versions.toml`** are required for the KMP side. `androidx.lifecycle.viewmodel` is already pulled in by Login work. `NSNumberFormatter` is part of the platform.Foundation cinterop that ships with Kotlin/Native.

If the existing `:shared-components/build.gradle.kts` does NOT yet export `androidx.lifecycle.viewmodel`, copy the pattern from `:shared-core/build.gradle.kts` exactly (CLAUDE.md §4 calls this out for iOS visibility).

### 6.2 `Package.swift` — NEW

```swift
// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "NumberInput",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "NumberInput", targets: ["NumberInput"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "NumberInput",
            dependencies: ["SharedComponents"]
        ),
        .binaryTarget(
            name: "SharedComponents",
            path: "../shared-components/build/XCFrameworks/release/SharedComponents.xcframework"
        ),
        .testTarget(
            name: "NumberInputTests",
            dependencies: ["NumberInput"]
        )
    ]
)
```

**Build prerequisite:** the XCFramework must be built before the package resolves. Document this in `swift-package/NumberInput/README.md` (one-paragraph file is fine):

```
./gradlew :shared-components:assembleSharedComponentsReleaseXCFramework
```

For Xcode-driven builds within `iosApp.xcodeproj`, add a "Run Script" build phase that invokes this Gradle task before linking — mirror whatever the `iosApp` project already does for the main XCFramework. (If `iosApp` uses `embedAndSign` via Gradle's `kotlinNativeFramework`, replicate that for `shared-components` — the team likely already has this hooked up.)

**Versioning (when externally published):**
- Tag the XCFramework with a release version.
- `.binaryTarget` requires a checksum when published to a remote URL — `swift package compute-checksum SharedComponents.xcframework.zip` produces it.
- Update `Package.swift` with both `url:` and `checksum:` when promoting from in-repo to externally published.

### 6.3 `iosApp.xcodeproj` — MODIFY

Add the local Swift Package via Xcode UI: **File → Add Package Dependencies… → Add Local…** → select `swift-package/NumberInput`. Commit the resulting `project.pbxproj` change.

The showcase screen (§7) will then `import NumberInput`.

---

## 7. Showcase Wiring

### 7.1 Swift-side showcase

`iosApp/iosApp/Showcase/NumberInputShowcaseView.swift` — a small SwiftUI view containing the three locale variants from `NUMBER-INPUT-UI.md` §7. Wire it into the existing showcase navigation if one exists; otherwise add a list-style screen.

### 7.2 Kotlin-side showcase wiring (REQUIRED per PRD §10.C C3)

`shared-app/src/commonMain/kotlin/dev/viethung/showcase/numberinput/NumberInputShowcaseViewModel.kt` — minimal VM that constructs three `NumberInputViewModel` instances for `en-US`, `vi-VN`, `de-DE` (matches UI spec §7). Exposed to iOS via the existing `:shared-app` helper pattern (mirror the Greeting / Login showcase wiring). Required for PRD §10.C C3 conformance per Validation Summary decision #4 — do NOT skip.

---

## 8. Test Plan

### 8.1 `NumberInputViewModelTest.kt` (commonTest)

Drive the state machine end-to-end via Turbine. Required cases:

| # | Test | Asserts |
|---|---|---|
| 1 | `initial state is Idle with formatted initialValue` | Initial emission is `Idle`, `formattedText` matches `formatter.format(initialValue)` |
| 2 | `onFocusChanged(true) transitions Idle to Editing` | `state.value is Editing` |
| 3 | `onTextChange parses to value and stays Editing` | After `onTextChange("42.5")`, `state.value == 42.5` |
| 4 | `onTextChange with invalid text keeps last value` | `onTextChange("abc")` after a valid value leaves `state.value` unchanged |
| 5 | `onToggleSign flips value` | `value = 42.5 → onToggleSign → value = -42.5` |
| 6 | `onToggleSign on null value is no-op` | `value = null → onToggleSign → value = null` |
| 7 | `onToggleSign with allowNegative=false is no-op` | Same as above |
| 8 | `onClear sets value to null and stays Editing` | Post-clear: `value == null`, `state is Editing`, `rawText == ""` |
| 9 | `onCommit emits Committed then Idle` | Two emissions; second is `Idle` with formatted text |
| 10 | `onFocusChanged(false) acts as commit` | Same as #9 |
| 11 | `significantDigits is reflected in Idle.formattedText` | `Double 0.1, sigDigits=3 → "0.100"` |
| 12 | `allowNegative=false clamps negative initialValue to 0.0` | Construct VM with `initialValue=-5.0, allowNegative=false` → initial `state.value == 0.0`, `state.rawText == "0.0"` |
| 13 | `onTextChange with negative parsed value is rejected when allowNegative=false` | Start with `value=10.0`. `onTextChange("-3")` → `state.value == 10.0` (unchanged), `state.rawText == "-3"` |

Use `FakeLocaleNumberFormatter` (test double) to make assertions deterministic — DO NOT exercise `NSNumberFormatter` in commonTest. The actual gets exercised by the next test file's iosTest run.

```kotlin
class FakeLocaleNumberFormatter : LocaleNumberFormatter {
    override fun format(value: Double, significantDigits: Int, locale: String): String =
        "%.${significantDigits}f".format(value)

    override fun parse(rawText: String, locale: String): Double? =
        rawText.takeIf { it.isNotBlank() }?.toDoubleOrNull()
}
```

> Per Validation Summary decision #1, `LocaleNumberFormatter` is an `interface` (§4.3) — the fake is a trivial implementation; no `open` gymnastics required.

### 8.2 `LocaleNumberFormatterContractTest.kt` (commonTest + iosTest)

Exercises the iOS `actual` indirectly via a shared contract test, run on `:shared-components:iosX64Test`:

| # | Input | Locale | sigDigits | Expected output |
|---|---|---|---|---|
| 1 | `1234567.89` | `en-US` | `2` | `"1,234,567.89"` |
| 2 | `1234567.89` | `vi-VN` | `2` | `"1.234.567,89"` |
| 3 | `1234567.89` | `de-DE` | `2` | `"1.234.567,89"` |
| 4 | `0.1` | `en-US` | `3` | `"0.100"` |
| 5 | `-0.1` | `en-US` | `3` | `"-0.100"` |
| 6 | `1.23456` | `en-US` | `2` | `"1.23"` (half-even) |
| 7 | `2.5` | `en-US` | `0` | `"2"` or `"3"` (half-even → `"2"`; verify) |
| 8 | parse `"1,234.5"` | `en-US` | n/a | `1234.5` |
| 9 | parse `"1.234,5"` | `vi-VN` | n/a | `1234.5` |
| 10 | parse `""` | any | n/a | `null` |

Run via: `./gradlew :shared-components:iosSimulatorArm64Test` (or X64 for Intel macs).

### 8.3 `NumberInputFieldTests.swift` (XCTest, in the Swift Package)

Use SwiftUI's `ViewInspector` OR XCUITest. Minimum cases:

| # | Test | Asserts |
|---|---|---|
| 1 | `fieldDisplaysFormattedValueWhenIdle` | View shows `"1,234.50"` for `value: 1234.5`, `sigDigits: 2`, `en-US` |
| 2 | `tappingFieldShowsToolbar` | Toolbar with 3 buttons appears |
| 3 | `tappingClearEmptiesField` | `value` becomes `nil` after Clear tap |
| 4 | `tappingPlusMinusFlipsSign` | `value: 42 → tap ± → -42` |
| 5 | `tappingDoneDismissesKeyboard` | Field loses focus |
| 6 | `signButtonDisabledWhenAllowNegativeFalse` | `± isDisabled == true` |

### 8.4 Manual smoke

Per PRD AC-09: build a bare consumer iOS app, add the Swift Package via Add Local, drop a `NumberInputField` on a screen, exercise the three locales. Document the result in `docs/components/reports/numberinput-smoke-<date>.md`.

---

## 9. Step-by-Step Build Order

Build in **strict order**. Each step is verified by the listed gate before the next begins. If a gate fails, fix or roll back before proceeding.

### Step 1 — Common state types
- Files: `NumberInputUiState.kt`, `NumberInputConfig.kt`
- Gate: `./gradlew :shared-components:compileKotlinMetadata` (commonMain compiles)

### Step 2 — Common formatter contract
- Files: `LocaleNumberFormatter.kt` (commonMain — `interface LocaleNumberFormatter` + `expect fun newLocaleNumberFormatter()` per Validation Summary decision #1)
- Gate: `./gradlew :shared-components:compileKotlinMetadata` still green; `LocaleNumberFormatter` interface and `newLocaleNumberFormatter()` expect symbol both visible in commonMain

### Step 3 — iOS actual formatter + contract test
- Files: `LocaleNumberFormatter.ios.kt`, `LocaleNumberFormatterContractTest.kt`
- Gate: `./gradlew :shared-components:iosSimulatorArm64Test` (10/10 green)

### Step 4 — Shared ViewModel
- Files: `NumberInputViewModel.kt`, `NumberInputViewModelTest.kt`, `FakeLocaleNumberFormatter`
- Gate: `./gradlew :shared-components:allTests` (11 new VM tests green; existing tests untouched)

### Step 5 — XCFramework export verification
- File: `shared-components/build.gradle.kts` (only if exports need updating)
- Gate: `./gradlew :shared-components:assembleSharedComponentsReleaseXCFramework` produces an XCFramework that includes `NumberInputViewModel`, `NumberInputUiState`, `LocaleNumberFormatter` symbols. Inspect with `nm -gU SharedComponents.framework/SharedComponents | grep NumberInput`.

### Step 6 — iOS helper bridge
- Files: `NumberInputViewModelHelper.kt`
- Gate: XCFramework re-builds; `NumberInputViewModelHelperKt.createNumberInputViewModel` symbol visible.

### Step 7 — Swift Package scaffolding
- Files: `Package.swift`, package directory structure, empty Sources
- Gate: `swift package describe` reports the package; `xcodebuild -resolvePackageDependencies` succeeds when wired to `iosApp.xcodeproj`.

### Step 8 — SwiftUI view + toolbar + bridge
- Files: `NumberInputField.swift`, `KeyboardToolbar.swift`, `NumberInputCoordinator.swift`, `DesignTokenBridge.swift`
- Gate: package compiles standalone; Xcode preview renders the field.

### Step 9 — Showcase wiring + XCTest
- Files: `NumberInputShowcaseView.swift`, `NumberInputPreviews.swift`, `NumberInputFieldTests.swift`
- Gate: `xcodebuild test -scheme iosApp` green for the package tests; in-simulator showcase screen exercises all four PRD §10 scenarios.

### Step 10 — Manual smoke (consumer-side)
- Outside this repo: create a bare iOS app, add the Swift Package via Add Local, exercise three locales.
- Gate: smoke report committed to `docs/components/reports/numberinput-smoke-<YYYY-MM-DD>.md`.

---

## 10. Validation Cadence

Per CLAUDE.md §6:

> Edit → Targeted test → Module test → Cross-platform smoke only if you touched shared API surface.

| When | What |
|---|---|
| After every edit in `commonMain/numberinput/` | Compile-check via `./gradlew :shared-components:compileKotlinIosX64` |
| After completing each step in §9 | Run that step's gate |
| Before committing | `./gradlew :shared-components:allTests` + `./gradlew check` |
| Before declaring done | All 10 steps green + manual smoke report committed |

---

## 11. Definition of Done

Tick **every** box before handoff back to product:

- [ ] All 12 PRD Acceptance Criteria (PRD §8) pass.
- [ ] `./gradlew :shared-components:allTests` green.
- [ ] `./gradlew check` clean.
- [ ] `xcodebuild test -scheme iosApp` green (including new NumberInputTests).
- [ ] Showcase screen renders correctly on iPhone simulator (16 Pro recommended) + iPad simulator.
- [ ] Manual smoke against `en-US`, `vi-VN`, `de-DE` documented in `docs/components/reports/numberinput-smoke-<date>.md`.
- [ ] External SPM consumer test app builds and runs (bare project, just adds the Swift Package and renders one field).
- [ ] No `androidx.compose.ui.*` or `android.*` or `UIKit.*` imports in `:shared-components/commonMain` (grep verified).
- [ ] No hardcoded color/font/size literals in the SwiftUI views (grep verified — only `DesignTokens.*` references).
- [ ] `gradle/libs.versions.toml` has no new entries (sanity check: this feature needs none).
- [ ] PRD §14 decisions all resolved and documented inline (✓ or note divergence with rationale).

---

## 12. Risks & Mitigations (Implementation-side)

| Risk | Mitigation |
|---|---|
| ~~`expect class` with `actual class` cannot be subclassed in commonTest → `FakeLocaleNumberFormatter` fails~~ **RESOLVED 2026-05-19 (Validation Summary decision #1)** | `LocaleNumberFormatter` declared as `interface` + `expect fun newLocaleNumberFormatter()`. Test fake is a trivial implementation. Risk no longer applies. |
| `KotlinDouble` ↔ `Double?` interop friction | Confirmed working in Login feature; mirror that pattern exactly. |
| SKIE-off helper boilerplate balloons | Login's helper is ~30 LoC; ours mirrors. If it exceeds 60 LoC, refactor — likely a sign of over-engineering. |
| `ToolbarItemGroup(placement: .keyboard)` doesn't behave correctly inside a `Form` / `List` row | Document in the package README. If problematic, fall back to `UIViewRepresentable` wrapping `UITextField` with `inputAccessoryView`. |
| Swift Package's `.binaryTarget` path is fragile across CI / dev machine layouts | Document the prerequisite Gradle task in `Package.swift`'s top-of-file comment; pin to `../shared-components/build/...` relative path. Switch to remote URL + checksum when promoting to external publication. |
| Cursor-jump on the iOS field (typing `1.234` then editing causes cursor to leap) | Mitigated by design — format only on commit (FR-06). If a v2 wants live formatting, adopt the [swiftui-numberfield two-Decimal pattern](https://github.com/edw/swiftui-numberfield). |
| `value: Binding<Double?>` mutation feedback loop (SwiftUI re-rendering during update) | Use the `onReceive(bridge.$publishedValue)` pattern (§5.1) instead of writing to the binding directly inside the bridge's published callback. Verified to break cycles. |

---

## 13. Out of This Plan (Sonnet, DO NOT do)

- ❌ Do NOT build the Android Compose adapter (Android `actual` of `LocaleNumberFormatter`, Compose `NumberInputField`). That's a follow-up PRD per §13 of the PRD.
- ❌ Do NOT add a currency mode, percent mode, or scientific mode. Hard-coded `numberStyle = .decimal` per UI spec §5.
- ❌ Do NOT introduce new dependencies in `libs.versions.toml` without a separate review. This feature needs none.
- ❌ Do NOT change the `:shared-components/build.gradle.kts` SKIE configuration. Keep it off, mirror the Login helper pattern (PRD §12).
- ❌ Do NOT delete the existing `:shared-components` files (`SampleUiState.kt` etc.) even if they appear unused — that's a separate cleanup decision (CLAUDE.md §2: surgical changes).
- ❌ Do NOT publish the Swift Package externally yet — in-repo local package only for v1. Promotion to a public repo + tagged release is a separate workstream after AC-09 passes.

---

## 14. Handoff Notes

When this plan is ready for execution:

1. Confirm PRD §14 decisions are all resolved.
2. Open a new conversation with Sonnet and feed it this file + the PRD + UI spec.
3. Sonnet works step-by-step through §9, committing after each green gate.
4. Smoke report goes into `docs/components/reports/numberinput-smoke-<date>.md`.
5. PR title: `feat(components): NumberInput v1 — KMP shared state + iOS SwiftUI + SPM package`.
