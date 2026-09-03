# NumberInputKit

NumberInputKit is a pure-Swift numeric input for SwiftUI and UIKit.
It provides live locale-aware grouping, fixed fractional digits, optional negative values, a system decimal keyboard, and an opt-in built-in keypad.

| | |
|---|---|
| **Platforms** | iOS 15+; macOS 12+ for platform-free logic and tests |
| **Package** | `NumberInputKit` through SwiftPM |
| **Distribution** | Git URL or local path |
| **License** | MIT |
| **Release process** | [`RELEASING.md`](./RELEASING.md) |
| **2.4.0 notes** | [`docs/release-notes-2.4.0.md`](./docs/release-notes-2.4.0.md) |

The package has no Kotlin, Kotlin/Native, or SkeletonKit dependency.
The Android counterpart ships separately as the [`:number-input`](../../number-input/) library.

## Install

### Git URL

NumberInputKit is published to a standalone repository through `git subtree split`.
Consumers use that repository because SwiftPM requires `Package.swift` at the dependency root.

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/osxsystem/NumberInputKit.git", from: "2.4.0")
],
targets: [
    .target(
        name: "MyApp",
        dependencies: [
            .product(name: "NumberInputKit", package: "NumberInputKit")
        ]
    )
]
```

In Xcode, select **File > Add Package Dependencies**, enter the repository URL, select the version range, and add `NumberInputKit` to the application target.

### Local path

The skeleton iOS application consumes the package from this monorepo:

```swift
.package(path: "../swift-package/NumberInputKit")
```

## Use the system keyboard

The system decimal keyboard is the default.
It retains native paste, dictation, and accessibility behavior.

```swift
import NumberInputKit
import SwiftUI

struct AmountEntry: View {
    @State private var amount: Double?

    var body: some View {
        NumberInputField(
            value: $amount,
            config: NumberInputConfig(
                significantDigits: 2,
                locale: "en-US",
                allowNegative: true,
                placeholder: "Amount"
            )
        )
    }
}
```

`value` changes after each accepted edit and again when Clear or the sign control changes the value.
The field applies fixed fractional digits when editing ends.
External binding changes update an idle field but do not replace an edit in progress.

## Opt in to the built-in keypad

Set `useBuiltInKeypad` to `true` for the package keypad.
The keypad replaces the system keyboard and shows the field locale's decimal separator.

```swift
NumberInputField(
    value: $amount,
    config: NumberInputConfig(
        significantDigits: 2,
        locale: "vi-VN",
        allowNegative: true,
        placeholder: "Số tiền",
        useBuiltInKeypad: true,
        keypadHaptics: true
    ),
    style: NumberInputStyle(
        textColor: .primary,
        textAlign: .right,
        borderColor: .clear,
        borderWidth: 0,
        toolbar: NumberInputToolbarStyle(doneLabel: "Xong"),
        keypad: NumberInputKeypadStyle()
    )
)
```

The built-in keypad provides:

- Locale-specific decimal labels and integer-only input when `significantDigits` is `0`.
- Clear, optional sign, and Done actions.
- Optional Previous and Next actions through `onPrevious` and `onNext`.
- A 400 ms held-backspace delay followed by an 80 ms repeat interval.
- Light haptics for accepted key presses when `keypadHaptics` is enabled.
- Stable accessibility identifiers through `NumberInputTags`.

`leadingAccessory` adds SwiftUI content to the built-in-keypad toolbar.
The system-keyboard toolbar stays native and ignores this content.

## Configure formatting and style

`NumberInputConfig` owns behavior:

- `significantDigits`: fixed fractional digits in `0...9`; `0` disables decimals.
- `locale`: BCP-47 locale identifier used for parsing and separators.
- `allowNegative`: controls negative input and sign-control visibility.
- `placeholder`: text shown for an empty value.
- `useBuiltInKeypad`: defaults to `false`.
- `keypadHaptics`: defaults to `true` and applies only to the built-in keypad.

VoiceOver copy is intentionally separate from the field-for-field Compose configuration.
Pass a localized `NumberInputAccessibilityStrings` value to `NumberInputField` to override the field label, hint, and empty-value announcement.
English defaults preserve existing call sites.

`NumberInputStyle` owns field, toolbar, and keypad appearance.
Use `NumberInputToolbarStyle`, `NumberInputToolbarActionStyle`, `NumberInputKeypadStyle`, and `NumberInputKeyStyle` for component-level overrides.
Unset keypad and toolbar colors resolve for light or dark appearance.

## Public types

- `NumberInputField` renders the iOS field.
- `NumberInputConfig` defines input behavior.
- `NumberInputAccessibilityStrings` defines localizable VoiceOver copy without changing the parity configuration.
- `NumberInputStyle` and its nested style types define appearance.
- `NumberInputState` exposes the synchronous input state machine for direct use and tests.
- `LocaleNumberFormatter`, `IosLocaleNumberFormatter`, and `newLocaleNumberFormatter()` provide locale formatting.
- `NumberInputTags` defines stable accessibility identifiers.

## Platform differences

| Capability | iOS 15+ | macOS 12+ |
|---|---|---|
| `NumberInputField` | SwiftUI field backed by `UITextField` | Unavailable |
| System decimal keyboard | Default | Unavailable |
| Built-in keypad and toolbar | Opt-in `UITextField.inputView` | Unavailable |
| UIKit keyboard animation and content avoidance | Native UIKit behavior | Unavailable |
| Formatting and `NumberInputState` tests | Supported | Supported |

The macOS declaration lets `swift test` build the platform-free formatter, state, style, and rule tests on a development Mac.
It does not provide a macOS input field.

## Test

Run platform-free tests on macOS:

```sh
cd swift-package/NumberInputKit
swift test
```

Run UIKit tests on an installed iOS simulator:

```sh
cd swift-package/NumberInputKit
xcodebuild test \
  -scheme NumberInputKit \
  -destination 'platform=iOS Simulator,name=14 Pro,OS=18.6'
```

Use `xcrun simctl list devices available` and replace the example name and OS when the local simulator differs.

See the [2.4.0 release notes](./docs/release-notes-2.4.0.md) for migration steps and the release boundary.
