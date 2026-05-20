# NumberInputKit (iOS)

Pure-Swift SwiftUI / UIKit numeric input field with live integer grouping, locale-aware
formatting, configurable significant digits, optional sign-toggle, and a clear button.

| | |
|---|---|
| **Platforms** | iOS 16+ |
| **Package** | `NumberInputKit` (SwiftPM) |
| **Distribution** | SPM source target, or `NumberInputKit.xcframework` via `scripts/build-numberinput-xcframework.sh` |
| **License** | MIT |

This package is the **independent, pure-Swift** port of the Number Input component. It has
**no dependency** on Kotlin/Native, on `SkeletonKit.xcframework`, or on the rest of the
skeleton repo. The Android counterpart ships separately as the
[`:number-input`](../../number-input/) Gradle library.

## Install

### Swift Package Manager (source)

```swift
.package(path: "../swift-package/NumberInputKit"),
```

### Binary distribution (XCFramework)

```sh
./scripts/build-numberinput-xcframework.sh
# output: swift-package/NumberInputKit/build/NumberInputKit.xcframework
```

Then reference it via a `.binaryTarget` in your `Package.swift`.

## Usage

```swift
import NumberInputKit
import SwiftUI

struct AmountEntry: View {
    @State private var amount: Double? = nil
    var body: some View {
        NumberInputField(
            value: $amount,
            significantDigits: 2,
            locale: Locale(identifier: "en-US"),
            allowNegative: true,
            placeholder: "Amount"
        )
    }
}
```

## Behavior

- **Live grouping** while typing: `1000` → `1,000` (en-US), `1.000` (vi-VN / de-DE).
- **Decimal-separator substitution**: on an en-US device the `.decimalPad` keyboard offers
  only `.`, but a vi-VN/de-DE field accepts the keystroke as its own `,`.
- **Locale-aware** parsing + formatting via Foundation `NumberFormatter`.
- **`allowNegative = false`** clamps negative initial values to `0.0` and rejects negative input.
- **Toolbar** with Clear, ±, Done — accessibility identifiers preserved from the original component.

## Public API

```swift
public final class NumberInputViewModel: ObservableObject { ... }
public enum NumberInputUiState: Equatable { case idle, editing, committed }
public struct NumberInputConfig { ... }
public protocol LocaleNumberFormatter { ... }
public func newLocaleNumberFormatter() -> LocaleNumberFormatter

public struct NumberInputField: View { public init(value: Binding<Double?>, ...) }
public struct NumberInputTheme { public static func defaultTheme(isDark: Bool) -> NumberInputTheme }
```

## Testing

```
swift test
# or for iOS Simulator-only APIs:
xcodebuild test -scheme NumberInputKit \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -sdk iphonesimulator
```
