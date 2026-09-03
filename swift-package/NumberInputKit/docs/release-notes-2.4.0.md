# NumberInputKit 2.4.0 release notes

Version 2.4.0 aligns the Swift package with the Compose number-input component's configuration, state, formatting, styling, and optional keypad behavior.
This document describes the planned release.
No 2.4.0 commit or tag exists yet.

## Behavior changes

- `NumberInputField` publishes every genuine value change through its `Binding<Double?>` while the user edits.
- Live grouping affects display text without adding grouping separators to the state buffer.
- The field applies `significantDigits` as a fixed fractional width when editing ends.
- A `significantDigits` value of `0` rejects decimal input and formats whole numbers without a fraction.
- The default input remains the system decimal keyboard.
- `useBuiltInKeypad: true` replaces the system keyboard with the package keypad.
- The built-in keypad displays the field locale's decimal separator, supports optional haptics, and repeats held backspace after 400 ms at 80 ms intervals.
- Disabled keypad keys retain button identity for assistive technologies and expose a disabled state.
- Clear, sign, Done, Previous, Next, keypad, and digit controls have stable identifiers in `NumberInputTags`.

## Breaking API changes from 0.1.0

| 0.1.0 | 2.4.0 migration |
|---|---|
| Flat `NumberInputField(value:significantDigits:locale:allowNegative:placeholder:...)` arguments | Pass behavior through `NumberInputConfig` and appearance through `NumberInputStyle`. |
| `Locale` value in the field initializer | Pass a BCP-47 `String`, such as `"en-US"`, to `NumberInputConfig.locale`. |
| `NumberInputViewModel` | Use `NumberInputState`. |
| `NumberInputUiState` | Use `NumberInputPhase` plus `NumberInputState` properties. |
| `NumberInputTheme.defaultTheme(isDark:)` | Use `NumberInputStyle` and `resolveThemedColors(_:dark:)`. |
| `numberInput.toolbar.sign` identifier | Use `NumberInputTags.toolbarSign`, whose value is `numberInput.toolbar.toggleSign`. |

Before:

```swift
NumberInputField(
    value: $amount,
    significantDigits: 2,
    locale: Locale(identifier: "en-US"),
    allowNegative: true,
    placeholder: "Amount"
)
```

After, retaining the system keyboard:

```swift
NumberInputField(
    value: $amount,
    config: NumberInputConfig(
        significantDigits: 2,
        locale: "en-US",
        allowNegative: true,
        placeholder: "Amount"
    )
)
```

Add `useBuiltInKeypad: true` only to fields that require the package keypad.
Leaving it out preserves the system keyboard for existing consumers.

## Supported platforms

The package manifest declares iOS 15+ and macOS 12+.

- iOS provides `NumberInputField`, the `UITextField` bridge, the system-keyboard toolbar, the built-in keypad, UIKit keyboard animation and content avoidance, haptics, and accessibility elements.
- macOS builds only the platform-free formatting, state, style, and rule layer used by `swift test`.
- NumberInputKit does not provide a macOS input field or keypad.
- The Swift built-in keypad is installed as `UITextField.inputView`.
  The Compose counterpart requires `NumberInputHost` to place its keypad and toolbar at the bottom of the window.

## Validation required before release

Run from the skeleton repository root:

```sh
cd swift-package/NumberInputKit
swift test
xcodebuild test \
  -scheme NumberInputKit \
  -destination 'platform=iOS Simulator,name=14 Pro,OS=18.6'
```

Use `xcrun simctl list devices available` and replace the example name and OS when the local simulator differs.

Then validate the consuming OpenFreightOne application:

```sh
cd /Users/hugues_mini/Codes/Mobiles/openfreightone/.worktrees/fix/sm-request-approve-bugs
./gradlew :shared:linkPodDebugFrameworkIosSimulatorArm64
xcodebuild \
  -workspace iosOpenFreightOne/iosOpenFreightOne.xcworkspace \
  -scheme iosOpenFreightOne \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Simulator verification must cover:

- System-keyboard consumers still display the native keyboard.
- SM Request Amount, Selling Amount, and VAT Rate display the built-in keypad.
- VND fields reject decimals; other currencies and VAT retain two fractional digits.
- Clear, sign visibility, Done, haptics, held backspace, grouping, keyboard avoidance, and accessibility identifiers behave as specified.

## Dirty-file ownership inventory

This inventory records the two worktrees on 2026-08-30.
Do not stage either repository broadly.
Use the release boundaries below after all implementation and validation work finishes.

### Skeleton repository: NumberInputKit package release

The 2.4.0 package commit owns these paths:

```text
swift-package/NumberInputKit/Package.swift
swift-package/NumberInputKit/README.md
swift-package/NumberInputKit/docs/release-notes-2.4.0.md
swift-package/NumberInputKit/Sources/NumberInputKit/**
swift-package/NumberInputKit/Tests/NumberInputKitTests/**
```

The source and test globs include the tracked removals of `NumberInputTheme.swift`, `NumberInputUIState.swift`, `NumberInputViewModel.swift`, and `NumberInputViewModelTests.swift`.
`swift-package/NumberInputKit/CHANGELOG.md` and `RELEASING.md` are currently clean and are not part of the agent-authored change set.
Repository policy requires a maintainer, not an agent, to update `CHANGELOG.md` before release.

### Skeleton repository: related but separate Number Input work

These dirty paths belong to the Android counterpart, sample applications, or their dependency wiring.
Keep them out of the Swift package release commit:

```text
androidApp/build.gradle.kts
androidApp/src/main/kotlin/dev/viethung/skeleton/android/showcase/NumberInputKitShowcaseScreen.kt
gradle/libs.versions.toml
iosApp/iosApp/Showcase/NumberInputKitShowcaseView.swift
number-input/README.md
number-input/src/androidTest/kotlin/dev/viethung/numberinput/NumberInputFieldComposeTest.kt
number-input/src/main/kotlin/dev/viethung/numberinput/AndroidLocaleNumberFormatter.kt
number-input/src/main/kotlin/dev/viethung/numberinput/LocaleNumberFormatter.kt
number-input/src/main/kotlin/dev/viethung/numberinput/NumberGroupingVisualTransformation.kt
number-input/src/main/kotlin/dev/viethung/numberinput/NumberInputConfig.kt
number-input/src/main/kotlin/dev/viethung/numberinput/NumberInputField.kt
number-input/src/main/kotlin/dev/viethung/numberinput/NumberInputUiState.kt
number-input/src/main/kotlin/dev/viethung/numberinput/NumberInputViewModel.kt
number-input/src/test/kotlin/dev/viethung/numberinput/FakeLocaleNumberFormatter.kt
number-input/src/test/kotlin/dev/viethung/numberinput/NumberGroupingVisualTransformationTest.kt
number-input/src/test/kotlin/dev/viethung/numberinput/NumberInputEdgeCaseTest.kt
number-input/src/test/kotlin/dev/viethung/numberinput/NumberInputViewModelTest.kt
settings.gradle.kts
```

These temporary test-routing files bypass authentication or open the Number Input sample directly:

```text
androidApp/src/main/kotlin/dev/viethung/skeleton/android/MainActivity.kt
androidApp/src/main/kotlin/dev/viethung/skeleton/android/dashboard/DashboardPlaceholder.kt
iosApp/iosApp/Auth/LoginScreen.swift
iosApp/iosAppUITests/LoginBypassUITests.swift
```

Revert or exclude all four paths before committing sample application work.

### Skeleton repository: unrelated dirty paths

Do not include these paths in a Number Input commit:

```text
.beads/interactions.jsonl
.beads/issues.jsonl
.codex/agents/**
.codex/config.toml
.kotlin/**
.planning/PROJECT.md
.planning/config.json
AGENTS.md
CLAUDE.md
CONTEXT.md
CONTRIBUTING.md
gradle/gradle-daemon-jvm.properties
```

### OpenFreightOne repository: NumberInputKit integration

The application integration change owns these files:

```text
iosOpenFreightOne/iosOpenFreightOne/Presentation/CourierCDs/CDs/CDsRequestApprove/EditRequestApproveView.swift
iosOpenFreightOne/iosOpenFreightOne/Presentation/SellingDebit/Suggest/SuggestSellingList.swift
iosOpenFreightOne/iosOpenFreightOne/Presentation/SmRequestApprove/SmRequestApproveDetailView.swift
iosOpenFreightOne/iosOpenFreightOne/Presentation/SmRequestApprove/SmRequestApproveViewModel.swift
iosOpenFreightOne/iosOpenFreightOne/uikits/OFCurrencyTextField.swift
iosOpenFreightOne/iosOpenFreightOne.xcodeproj/project.pbxproj
iosOpenFreightOne/iosOpenFreightOne/en.lproj/Localizable.strings
Documents/sm-number-input-keypad-spec.md
```

The Courier CDS, Selling Debit, and `OFCurrencyTextField` migrations intentionally retain the system keyboard.
Only the SM Request fields opt in to the built-in keypad.

### OpenFreightOne repository: unrelated dirty paths

Do not include these files in the NumberInputKit integration commit:

```text
AGENTS.md
CLAUDE.md
androidOpenFreightOne/build.gradle.kts
androidOpenFreightOne/src/main/java/com/beelogictics/openfreightone/android/presentation/smrequestapprove/data/dto/SmReqApprDto.kt
androidOpenFreightOne/src/main/java/com/beelogictics/openfreightone/android/presentation/smrequestapprove/data/mappers/SmReqApprMappers.kt
androidOpenFreightOne/src/main/java/com/beelogictics/openfreightone/android/presentation/smrequestapprove/domain/model/SmReqAppr.kt
androidOpenFreightOne/src/main/java/com/beelogictics/openfreightone/android/presentation/smrequestapprove/presentation/SmRequestApproveListDetailUIView.kt
androidOpenFreightOne/src/main/java/com/beelogictics/openfreightone/android/presentation/smrequestapprove/presentation/components/ItemCardSmRequestApproveView.kt
androidOpenFreightOne/src/test/java/com/beelogictics/openfreightone/android/presentation/smrequestapprove/SmRequestApproveMappingTest.kt
docs/agents/domain.md
docs/agents/issue-tracker.md
docs/agents/triage-labels.md
```

## Future commit and tag sequence

Do not execute these steps until the package tests, application build, and simulator scenarios pass.

1. In the skeleton repository, review and stage only `swift-package/NumberInputKit/` package source, tests, manifest, README, release notes, and the maintainer-updated changelog.
2. Commit the isolated 2.4.0 package change on `feat/numberinputkit-2.4.0`.
3. Commit Android parity, sample application, and dependency-wiring work separately after removing both authentication bypasses.
4. In OpenFreightOne, stage and commit only the eight integration paths listed above after full build and simulator verification.
5. Merge the reviewed skeleton package commit into the branch used to publish the monorepo.
6. Run `git subtree split --prefix=swift-package/NumberInputKit -b numberinputkit-release` from the skeleton repository root.
7. Inspect the split branch and push it as `numberinputkit-public/main` only after human approval.
8. Fetch `numberinputkit-public/main`, create annotated tag `2.4.0` on that exact commit, and push the tag only after human approval.
9. Confirm a clean standalone checkout resolves `.package(..., from: "2.4.0")` and passes both test commands.

No commit, tag, merge, push, reset, clean, or branch deletion was performed while preparing this document.
