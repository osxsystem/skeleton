# NumberInputKit (iOS)

Pure-Swift SwiftUI / UIKit numeric input field with live integer grouping, locale-aware
formatting, configurable significant digits, optional sign-toggle, and a clear button.

| | |
|---|---|
| **Platforms** | iOS 16+ |
| **Package** | `NumberInputKit` (SwiftPM) |
| **Distribution** | SwiftPM (git URL or local path) |
| **License** | MIT |
| **Release process** | [`RELEASING.md`](./RELEASING.md) · [`CHANGELOG.md`](./CHANGELOG.md) |

This package is the **independent, pure-Swift** port of the Number Input component. It has
**no dependency** on Kotlin/Native, on `SkeletonKit.xcframework`, or on the rest of the
skeleton repo. The Android counterpart ships separately as the
[`:number-input`](../../number-input/) Gradle library.

## Install

### Git URL (production)

NumberInputKit is published to a dedicated standalone repo via `git subtree split`
from this monorepo (see [`RELEASING.md`](./RELEASING.md)). Consumers depend on
that repo's git URL, not the skeleton monorepo.

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/osxsystem/NumberInputKit.git", from: "0.1.0")
],
targets: [
    .target(name: "MyApp", dependencies: [
        .product(name: "NumberInputKit", package: "NumberInputKit")
    ])
]
```

Or in Xcode: **File → Add Package Dependencies** → paste the repo URL → pick
version range → add the `NumberInputKit` library to your target.

### Local path (in-repo dev)

When developing inside the skeleton monorepo (the `iosApp` showcase uses this
mode), reference the package directly:

```swift
.package(path: "../swift-package/NumberInputKit")
```

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
