# Changelog

All notable changes to NumberInputKit will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

While the major version is `0.x`, MINOR bumps may include breaking API changes.
Each entry will call them out under **Changed** or **Removed**.

## [Unreleased]

## [2.4.0] - 2026-09-03

### Added

- Opt-in built-in keypad with locale-aware decimal input, Clear, sign, Done,
  haptics, and held-backspace repeat.
- Configurable field, toolbar, keypad, and key-role styles.
- Stable accessibility identifiers for the field, toolbar, keypad, and keys.
- `NumberInputAccessibilityStrings` for localized VoiceOver copy.
- UIKit regression coverage for keypad presentation, binding updates, toolbar
  dispatch, Dynamic Type, and accessibility behavior.

### Changed

- `NumberInputField` now receives behavior through `NumberInputConfig` and
  appearance through `NumberInputStyle`.
- Bound values are optional; `nil` represents an empty field.
- Accepted edits publish live, while commit applies fixed-width fractional
  formatting with half-even rounding.
- The deployment target is iOS 15. The platform-free logic also builds on
  macOS 12 for package tests.

### Fixed

- Integer-only inputs reject decimal separators and commit without a fraction.
- Live grouping no longer contaminates the internal editing buffer.
- External binding changes resynchronize idle fields without replacing an edit
  in progress.
- Held backspace performs its first repeated deletion after 400 ms, then every
  80 ms.
- Disabled keypad keys keep their button accessibility identity.

### Removed

- `NumberInputViewModel`, `NumberInputUiState`, and `NumberInputTheme`.
  Use `NumberInputState`, `NumberInputPhase`, and `NumberInputStyle` instead.

## [0.1.0] - 2026-05-21

Initial public release. Pure-Swift port of the Number Input component, extracted
from the KMP skeleton repo. No dependency on Kotlin/Native or `SkeletonKit.xcframework`.

### Added

- `NumberInputField`: SwiftUI view backed by `UIViewRepresentable` over a custom
  `UITextField`. Drives the editing experience and renders the toolbar.
- `NumberInputViewModel`: `ObservableObject` owning the `NumberInputUiState`
  machine (`idle` → `editing` → `committed` → `idle`).
- `LocaleNumberFormatter` protocol + `newLocaleNumberFormatter()` factory,
  backed by Foundation `NumberFormatter`.
- `NumberInputConfig`: significant digits + `allowNegative` toggle.
- `NumberInputTheme.defaultTheme(isDark:)`: in-package theming primitives.
- Live integer grouping while typing: `1000` → `1,000` (en-US), `1.000` (vi-VN, de-DE).
- Locale-aware decimal-separator substitution: typing `.` on an en-US `.decimalPad`
  is accepted as `,` in a vi-VN/de-DE field.
- Negative-value clamping when `allowNegative = false`: initial negative values
  clamp to `0.0`, subsequent `-` keystrokes are rejected.
- Toolbar actions: Clear, ± (sign toggle), Done. Stable accessibility identifiers
  (`numberInput.field`, `numberInput.toolbar.clear`, `numberInput.toolbar.sign`,
  `numberInput.toolbar.done`) for UI test wiring.

### Platforms

- iOS 16+

[Unreleased]: https://github.com/osxsystem/NumberInputKit/compare/2.4.0...HEAD
[2.4.0]: https://github.com/osxsystem/NumberInputKit/compare/0.1.0...2.4.0
[0.1.0]: https://github.com/osxsystem/NumberInputKit/releases/tag/0.1.0
