package dev.viethung.showcase.numberinput

import androidx.lifecycle.ViewModel
import dev.viethung.components.numberinput.NumberInputConfig
import dev.viethung.components.numberinput.NumberInputViewModel
import dev.viethung.components.numberinput.newLocaleNumberFormatter

/**
 * Showcase ViewModel that constructs three [NumberInputViewModel] instances for en-US, vi-VN, and de-DE.
 * Required by PRD §10.C C3 — see Validation Summary decision #4.
 */
class NumberInputShowcaseViewModel : ViewModel() {

    val formatter = newLocaleNumberFormatter()

    val enUs = NumberInputViewModel(
        formatter = formatter,
        initialValue = 1234.5,
        significantDigits = 2,
        locale = "en-US",
        allowNegative = true,
    )

    val viVn = NumberInputViewModel(
        formatter = formatter,
        initialValue = 1234.5,
        significantDigits = 2,
        locale = "vi-VN",
        allowNegative = true,
    )

    val deDe = NumberInputViewModel(
        formatter = formatter,
        initialValue = 1234.5,
        significantDigits = 3,
        locale = "de-DE",
        allowNegative = true,
    )

    val unsigned = NumberInputViewModel(
        formatter = formatter,
        initialValue = 42.0,
        significantDigits = 0,
        locale = "en-US",
        allowNegative = false,
    )

}
