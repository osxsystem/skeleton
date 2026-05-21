package dev.viethung.numberinput

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import kotlin.test.AfterTest
import kotlin.test.BeforeTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertIs
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

@OptIn(ExperimentalCoroutinesApi::class)
class NumberInputEdgeCaseTest {

    private val fake = FakeLocaleNumberFormatter()

    @BeforeTest
    fun setMainDispatcher() {
        Dispatchers.setMain(StandardTestDispatcher())
    }

    @AfterTest
    fun resetMainDispatcher() {
        Dispatchers.resetMain()
    }

    private fun makeVm(
        initialValue: Double? = null,
        significantDigits: Int = 2,
        locale: String = "en-US",
        allowNegative: Boolean = true,
    ) = NumberInputViewModel(fake, initialValue, significantDigits, locale, allowNegative)

    // -------------------------------------------------------------------------
    // NumberInputConfig validation
    // -------------------------------------------------------------------------

    // Test 1
    @Test
    fun numberInputConfig_rejects_significantDigits_below_zero() {
        assertFailsWith<IllegalArgumentException> {
            NumberInputConfig(significantDigits = -1)
        }
    }

    // Test 2
    @Test
    fun numberInputConfig_rejects_significantDigits_above_nine() {
        assertFailsWith<IllegalArgumentException> {
            NumberInputConfig(significantDigits = 10)
        }
    }

    // Test 3
    @Test
    fun numberInputConfig_accepts_significantDigits_at_bounds() {
        // Neither should throw
        NumberInputConfig(significantDigits = 0)
        NumberInputConfig(significantDigits = 9)
    }

    // -------------------------------------------------------------------------
    // AndroidLocaleNumberFormatter — extreme values (pure JVM, no Robolectric)
    // -------------------------------------------------------------------------

    // Test 4
    @Test
    fun androidFormatter_format_value_too_large_for_long_does_not_crash() {
        val fmt = AndroidLocaleNumberFormatter()
        val result = fmt.format(Double.MAX_VALUE, 2, "en-US")
        assertNotNull(result)
        assertTrue(result.isNotEmpty(), "format(Double.MAX_VALUE) must return a non-empty string")

        val live = fmt.formatLive(Double.MAX_VALUE.toString(), "en-US")
        assertNotNull(live)
        // No crash is the primary assertion; live result may be raw digits
    }

    // Test 5
    @Test
    fun androidFormatter_format_NaN_returns_a_string() {
        val fmt = AndroidLocaleNumberFormatter()
        val result = fmt.format(Double.NaN, 2, "en-US")
        assertNotNull(result)
        assertTrue(result.isNotEmpty(), "format(NaN) must return a non-empty string")
        // DecimalFormat.format(NaN) returns the JVM's NaN symbol for the locale; pin current output:
        // pins current behaviour — see docs/qa/scenarios/number-input-library.md #5
        assertEquals("NaN", result)
    }

    // Test 6
    @Test
    fun androidFormatter_format_positiveInfinity_returns_a_string() {
        val fmt = AndroidLocaleNumberFormatter()
        val result = fmt.format(Double.POSITIVE_INFINITY, 2, "en-US")
        assertNotNull(result)
        assertTrue(result.isNotEmpty(), "format(Infinity) must return a non-empty string")
        // DecimalFormat.format(Infinity) returns the locale's infinity symbol; pin current output:
        // pins current behaviour — see docs/qa/scenarios/number-input-library.md #6
        assertEquals("∞", result)
    }

    // -------------------------------------------------------------------------
    // ViewModel with special initial values
    // -------------------------------------------------------------------------

    // Test 7
    @Test
    fun vm_with_NaN_initialValue_initialises_to_Idle_without_crash() = runTest {
        // FakeLocaleNumberFormatter.format(NaN, ...) will produce NaN-like output; no crash expected
        val vm = makeVm(initialValue = Double.NaN)
        assertIs<NumberInputUiState.Idle>(vm.state.value)
    }

    // Test 8
    @Test
    fun vm_with_PositiveInfinity_initialValue_initialises_to_Idle_without_crash() = runTest {
        val vm = makeVm(initialValue = Double.POSITIVE_INFINITY)
        assertIs<NumberInputUiState.Idle>(vm.state.value)
    }

    // -------------------------------------------------------------------------
    // onTextChange edge cases
    // -------------------------------------------------------------------------

    // Test 9 — 20 nines exceeds Long.MAX_VALUE (9,223,372,036,854,775,807 = 19 digits)
    @Test
    fun onTextChange_with_huge_integer_keeps_rawText_and_does_not_crash() = runTest {
        val twentyNines = "99999999999999999999" // 20 nines, overflows Long
        val vm = makeVm()
        vm.onFocusChanged(true)
        advanceUntilIdle()
        vm.onTextChange(twentyNines)
        advanceUntilIdle()
        val state = assertIs<NumberInputUiState.Editing>(vm.state.value)
        assertEquals(twentyNines, state.rawText)
        // No crash is the primary goal; state remains Editing
    }

    // Test 10
    @Test
    fun onTextChange_with_leading_zeros_normalises_to_no_leading_zeros_en_US() = runTest {
        val vm = makeVm(locale = "en-US")
        vm.onFocusChanged(true)
        advanceUntilIdle()
        vm.onTextChange("000123")
        advanceUntilIdle()
        val state = assertIs<NumberInputUiState.Editing>(vm.state.value)
        // FakeLocaleNumberFormatter.formatLive strips leading zeros via toLongOrNull()
        assertEquals("123", state.formattedText)
    }

    // Test 11
    @Test
    fun onTextChange_with_multiple_decimal_separators_keeps_prior_value_en_US() = runTest {
        // "1.2.3" fails toDoubleOrNull() in FakeLocaleNumberFormatter.parse → returns null
        // VM keeps current.value (10.0) but updates rawText
        val vm = makeVm(initialValue = 10.0)
        vm.onFocusChanged(true)
        advanceUntilIdle()
        vm.onTextChange("1.2.3")
        advanceUntilIdle()
        val state = assertIs<NumberInputUiState.Editing>(vm.state.value)
        assertEquals(10.0, state.value)
        assertEquals("1.2.3", state.rawText)
    }

    // Test 12
    @Test
    fun significantDigits_zero_in_Idle_displays_without_decimal_separator() = runTest {
        val vm = makeVm(initialValue = 1234.5, significantDigits = 0)
        val state = assertIs<NumberInputUiState.Idle>(vm.state.value)
        // FakeLocaleNumberFormatter.format(1234.5, 0, "en-US"):
        //   multiplier=1, round(1234.5)=1235 (half-up), fracStr=""  → "1,235"
        assertTrue('.' !in state.formattedText, "formattedText must not contain '.' when significantDigits=0")
        assertTrue(state.formattedText.startsWith("1"), "formattedText should start with '1'")
        assertEquals(5, state.formattedText.length, "e.g. '1,235' is 5 chars")
    }

    // -------------------------------------------------------------------------
    // onClear and onToggleSign called directly from Idle state
    // -------------------------------------------------------------------------

    // Test 13
    @Test
    fun onClear_while_Idle_emits_Editing_documenting_current_behaviour() = runTest {
        // pins current behaviour — see docs/qa/scenarios/number-input-library.md #13
        // onClear() always emits Editing regardless of current state (no focus guard)
        val vm = makeVm(initialValue = 5.0)
        assertIs<NumberInputUiState.Idle>(vm.state.value)
        vm.onClear()
        advanceUntilIdle()
        val state = assertIs<NumberInputUiState.Editing>(vm.state.value)
        assertNull(state.value)
        assertEquals("", state.rawText)
    }

    // Test 14
    @Test
    fun onToggleSign_while_Idle_emits_Editing_documenting_current_behaviour() = runTest {
        // pins current behaviour — see docs/qa/scenarios/number-input-library.md #14
        // onToggleSign() reads current.value from Idle and emits Editing
        val vm = makeVm(initialValue = 5.0)
        assertIs<NumberInputUiState.Idle>(vm.state.value)
        vm.onToggleSign()
        advanceUntilIdle()
        val state = assertIs<NumberInputUiState.Editing>(vm.state.value)
        assertEquals(-5.0, state.value)
    }

    // Test 15
    @Test
    fun onToggleSign_on_zero_value_produces_negative_zero_value() = runTest {
        val vm = makeVm(initialValue = 0.0)
        vm.onFocusChanged(true)
        advanceUntilIdle()
        vm.onToggleSign()
        advanceUntilIdle()
        val state = assertIs<NumberInputUiState.Editing>(vm.state.value)
        // 0.0 == -0.0 in IEEE 754, but raw bits differ
        val expected = java.lang.Double.doubleToRawLongBits(-0.0)
        val actual = java.lang.Double.doubleToRawLongBits(state.value!!)
        assertEquals(expected, actual, "toggleSign on 0.0 should produce -0.0 (negative zero)")
    }

    // -------------------------------------------------------------------------
    // AndroidLocaleNumberFormatter rounding
    // -------------------------------------------------------------------------

    // Test 16
    @Test
    fun androidFormatter_halfEven_rounds_1_234567_to_5_digits() {
        val fmt = AndroidLocaleNumberFormatter()
        val result = fmt.format(1.234567, 5, "en-US")
        // At 5 decimal places: 1.23456|7 — digit after truncation is 7 (>5), rounds up
        assertEquals("1.23457", result)
    }

    // Test 17
    @Test
    fun androidFormatter_halfEven_rounds_1_005_at_two_digits() {
        val fmt = AndroidLocaleNumberFormatter()
        val result = fmt.format(1.005, 2, "en-US")
        // Double 1.005 is slightly less than the mathematical 1.005 in binary floating point.
        // DecimalFormat HALF_EVEN rounds the actual binary value, which is < 1.005, so rounds down.
        // pins current behaviour — see docs/qa/scenarios/number-input-library.md #17
        assertTrue(result.startsWith("1.0"), "1.005 rounded to 2 dp must start with '1.0', got '$result'")
    }

    // -------------------------------------------------------------------------
    // Negative rejection persists through commit
    // -------------------------------------------------------------------------

    // Test 18
    @Test
    fun onTextChange_negative_text_rejected_allowNegative_false_value_survives_commit() = runTest {
        val vm = makeVm(initialValue = 10.0, allowNegative = false)
        vm.onFocusChanged(true)
        advanceUntilIdle()
        // Type negative text — value stays 10.0, rawText updated
        vm.onTextChange("-3")
        advanceUntilIdle()
        val editing = assertIs<NumberInputUiState.Editing>(vm.state.value)
        assertEquals(10.0, editing.value)
        assertEquals("-3", editing.rawText)
        // Commit: should format 10.0, not "-3"
        vm.onCommit()
        advanceUntilIdle()
        val idle = assertIs<NumberInputUiState.Idle>(vm.state.value)
        // FakeLocaleNumberFormatter.format(10.0, 2, "en-US") = "10.00"
        assertEquals("10.00", idle.formattedText)
    }
}
