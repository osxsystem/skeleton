# Number Input (Android)

Locale-aware numeric input field for Jetpack Compose with live integer grouping, configurable
significant digits, locale-correct decimal separator, optional sign-toggle, and a clear button.

| | |
|---|---|
| **Artifact** | `dev.viethung:number-input:0.1.0-SNAPSHOT` |
| **Min SDK** | 23 |
| **Compose BOM** | matches the repo's `gradle/libs.versions.toml` |
| **License** | MIT |

This is the standalone Android library version of the Number Input. It has **no dependency**
on the rest of the skeleton (no `:shared-core`, no KMP, no XCFramework). The iOS counterpart
ships separately as the pure-Swift [NumberInputKit](../swift-package/NumberInputKit/) package.

## Usage

```kotlin
@Composable
fun MyScreen() {
    var amount by remember { mutableStateOf<Double?>(null) }
    NumberInputField(
        value = amount,
        onValueChange = { amount = it },
        significantDigits = 2,
        locale = "en-US",
        allowNegative = true,
        placeholder = "Amount",
    )
}
```

## Behavior

- **Live grouping** while typing: `1000` → `1,000` (en-US), `1.000` (vi-VN / de-DE).
- **Decimal preservation** mid-edit: the part after the decimal separator is kept verbatim.
- **Locale-aware** parsing + formatting via `java.text.DecimalFormat`.
- **`allowNegative = false`** clamps negative initial values to `0.0` and rejects negative input.
- **State machine** Idle → Editing → Committed → Idle (commit-on-focus-loss).

## Public API

```kotlin
class NumberInputViewModel(formatter, initialValue, significantDigits, locale, allowNegative)
sealed interface NumberInputUiState { Idle ; Editing ; Committed }
data class NumberInputConfig(significantDigits, locale, allowNegative, placeholder)
interface LocaleNumberFormatter { format ; parse ; formatLive }
fun newLocaleNumberFormatter(): LocaleNumberFormatter

@Composable fun NumberInputField(value, onValueChange, ...)
```

## Testing

```
./gradlew :number-input:testDebugUnitTest        # 22 unit tests
./gradlew :number-input:connectedDebugAndroidTest # Compose UI tests (requires emulator)
```
