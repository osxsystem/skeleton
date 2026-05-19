package dev.viethung.components.numberinput

import app.cash.turbine.test
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
import kotlin.test.assertIs
import kotlin.test.assertNull

@OptIn(ExperimentalCoroutinesApi::class)
class NumberInputViewModelTest {

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

    // Test 1
    @Test
    fun initial_state_is_Idle_with_formatted_initialValue() = runTest {
        val vm = makeVm(initialValue = 1234.5, significantDigits = 2)
        val state = assertIs<NumberInputUiState.Idle>(vm.state.value)
        assertEquals("1,234.50", state.formattedText)
        assertEquals(1234.5, state.value)
    }

    // Test 2
    @Test
    fun onFocusChanged_true_transitions_Idle_to_Editing() = runTest {
        val vm = makeVm(initialValue = 1.0)
        vm.state.test {
            skipItems(1) // initial Idle
            vm.onFocusChanged(true)
            advanceUntilIdle()
            assertIs<NumberInputUiState.Editing>(awaitItem())
            cancelAndIgnoreRemainingEvents()
        }
    }

    // Test 3
    @Test
    fun onTextChange_parses_to_value_and_stays_Editing() = runTest {
        val vm = makeVm()
        vm.onFocusChanged(true)
        advanceUntilIdle()
        vm.onTextChange("42.5")
        advanceUntilIdle()
        val state = assertIs<NumberInputUiState.Editing>(vm.state.value)
        assertEquals(42.5, state.value)
        assertEquals("42.5", state.rawText)
    }

    // Test 4
    @Test
    fun onTextChange_with_invalid_text_keeps_last_value() = runTest {
        val vm = makeVm(initialValue = 10.0)
        vm.onFocusChanged(true)
        advanceUntilIdle()
        vm.onTextChange("abc")
        advanceUntilIdle()
        val state = assertIs<NumberInputUiState.Editing>(vm.state.value)
        assertEquals(10.0, state.value)
        assertEquals("abc", state.rawText)
    }

    // Test 5
    @Test
    fun onToggleSign_flips_value() = runTest {
        val vm = makeVm(initialValue = 42.5)
        vm.onFocusChanged(true)
        advanceUntilIdle()
        vm.onToggleSign()
        advanceUntilIdle()
        val state = assertIs<NumberInputUiState.Editing>(vm.state.value)
        assertEquals(-42.5, state.value)
    }

    // Test 6
    @Test
    fun onToggleSign_on_null_value_is_no_op() = runTest {
        val vm = makeVm(initialValue = null)
        vm.onFocusChanged(true)
        advanceUntilIdle()
        vm.onToggleSign()
        advanceUntilIdle()
        val state = assertIs<NumberInputUiState.Editing>(vm.state.value)
        assertNull(state.value)
    }

    // Test 7
    @Test
    fun onToggleSign_with_allowNegative_false_is_no_op() = runTest {
        val vm = makeVm(initialValue = 42.5, allowNegative = false)
        vm.onFocusChanged(true)
        advanceUntilIdle()
        vm.onToggleSign()
        advanceUntilIdle()
        val state = assertIs<NumberInputUiState.Editing>(vm.state.value)
        assertEquals(42.5, state.value) // unchanged
    }

    // Test 8
    @Test
    fun onClear_sets_value_to_null_and_stays_Editing() = runTest {
        val vm = makeVm(initialValue = 42.5)
        vm.onFocusChanged(true)
        advanceUntilIdle()
        vm.onClear()
        advanceUntilIdle()
        val state = assertIs<NumberInputUiState.Editing>(vm.state.value)
        assertNull(state.value)
        assertEquals("", state.rawText)
    }

    // Test 9
    @Test
    fun onCommit_emits_Committed_then_Idle() = runTest {
        val vm = makeVm(initialValue = 5.0)
        vm.onFocusChanged(true)
        advanceUntilIdle()

        vm.state.test {
            skipItems(1) // current Editing
            vm.onCommit()
            advanceUntilIdle()
            assertIs<NumberInputUiState.Committed>(awaitItem())
            assertIs<NumberInputUiState.Idle>(awaitItem())
            cancelAndIgnoreRemainingEvents()
        }
    }

    // Test 10
    @Test
    fun onFocusChanged_false_acts_as_commit() = runTest {
        val vm = makeVm(initialValue = 5.0)
        vm.onFocusChanged(true)
        advanceUntilIdle()

        vm.state.test {
            skipItems(1) // current Editing
            vm.onFocusChanged(false)
            advanceUntilIdle()
            assertIs<NumberInputUiState.Committed>(awaitItem())
            assertIs<NumberInputUiState.Idle>(awaitItem())
            cancelAndIgnoreRemainingEvents()
        }
    }

    // Test 11
    @Test
    fun significantDigits_is_reflected_in_Idle_formattedText() = runTest {
        val vm = makeVm(initialValue = 0.1, significantDigits = 3)
        val state = assertIs<NumberInputUiState.Idle>(vm.state.value)
        assertEquals("0.100", state.formattedText)
    }

    // Test 12 — allowNegative=false clamps negative initialValue to 0.0
    @Test
    fun allowNegative_false_clamps_negative_initialValue_to_zero() = runTest {
        val vm = makeVm(initialValue = -5.0, allowNegative = false)
        val state = assertIs<NumberInputUiState.Idle>(vm.state.value)
        assertEquals(0.0, state.value)
        assertEquals("0.00", state.rawText.let { fake.format(0.0, 2, "en-US") })
    }

    // Test 13 — onTextChange with negative parsed value rejected when allowNegative=false
    @Test
    fun onTextChange_with_negative_value_is_rejected_when_allowNegative_false() = runTest {
        val vm = makeVm(initialValue = 10.0, allowNegative = false)
        vm.onFocusChanged(true)
        advanceUntilIdle()
        vm.onTextChange("-3")
        advanceUntilIdle()
        val state = assertIs<NumberInputUiState.Editing>(vm.state.value)
        assertEquals(10.0, state.value) // value unchanged
        assertEquals("-3", state.rawText) // rawText updated
    }

    // Test 14 — live integer grouping while typing en-US
    @Test
    fun onTextChange_live_groups_integer_en_US() = runTest {
        val vm = makeVm(locale = "en-US")
        vm.onFocusChanged(true)
        advanceUntilIdle()
        listOf("1" to "1", "10" to "10", "100" to "100", "1000" to "1,000").forEach { (typed, expected) ->
            vm.onTextChange(typed)
            advanceUntilIdle()
            val state = assertIs<NumberInputUiState.Editing>(vm.state.value)
            assertEquals(expected, state.formattedText, "input \"$typed\" should show \"$expected\"")
        }
    }

    // Test 15 — re-grouping an already-grouped input (user typed at end of "1,000")
    @Test
    fun onTextChange_regroups_already_grouped_input_en_US() = runTest {
        val vm = makeVm(locale = "en-US")
        vm.onFocusChanged(true)
        advanceUntilIdle()
        vm.onTextChange("1,0009")
        advanceUntilIdle()
        val state = assertIs<NumberInputUiState.Editing>(vm.state.value)
        assertEquals("10,009", state.formattedText)
        assertEquals(10009.0, state.value)
    }

    // Test 16 — backspace re-collapses grouping
    @Test
    fun onTextChange_backspace_recollapses_grouping_en_US() = runTest {
        val vm = makeVm(locale = "en-US")
        vm.onFocusChanged(true)
        advanceUntilIdle()
        vm.onTextChange("1000")
        advanceUntilIdle()
        assertEquals("1,000", (vm.state.value as NumberInputUiState.Editing).formattedText)
        vm.onTextChange("1,00")
        advanceUntilIdle()
        assertEquals("100", (vm.state.value as NumberInputUiState.Editing).formattedText)
    }

    // Test 17 — vi-VN uses "." for grouping
    @Test
    fun onTextChange_live_groups_integer_vi_VN() = runTest {
        val vm = makeVm(locale = "vi-VN")
        vm.onFocusChanged(true)
        advanceUntilIdle()
        vm.onTextChange("1000")
        advanceUntilIdle()
        assertEquals("1.000", (vm.state.value as NumberInputUiState.Editing).formattedText)
        vm.onTextChange("1000000")
        advanceUntilIdle()
        assertEquals("1.000.000", (vm.state.value as NumberInputUiState.Editing).formattedText)
    }

    // Test 18 — decimal portion is preserved verbatim during edit
    @Test
    fun onTextChange_preserves_decimal_portion_en_US() = runTest {
        val vm = makeVm(locale = "en-US")
        vm.onFocusChanged(true)
        advanceUntilIdle()
        vm.onTextChange("1000.5")
        advanceUntilIdle()
        assertEquals("1,000.5", (vm.state.value as NumberInputUiState.Editing).formattedText)
        vm.onTextChange("1000.")
        advanceUntilIdle()
        assertEquals("1,000.", (vm.state.value as NumberInputUiState.Editing).formattedText)
    }

    // Test 19 — typing just "-" displays "-" (allows building a negative number)
    @Test
    fun onTextChange_minus_alone_displays_minus() = runTest {
        val vm = makeVm(locale = "en-US")
        vm.onFocusChanged(true)
        advanceUntilIdle()
        vm.onTextChange("-")
        advanceUntilIdle()
        assertEquals("-", (vm.state.value as NumberInputUiState.Editing).formattedText)
    }

    // Test 20 — empty input clears formattedText
    @Test
    fun onTextChange_empty_clears_formattedText() = runTest {
        val vm = makeVm(initialValue = 1234.5, locale = "en-US")
        vm.onFocusChanged(true)
        advanceUntilIdle()
        vm.onTextChange("")
        advanceUntilIdle()
        val state = assertIs<NumberInputUiState.Editing>(vm.state.value)
        assertEquals("", state.formattedText)
        assertNull(state.value)
    }

    // Test 21 — onFocusChanged(true) carries Idle.formattedText into Editing as starting display
    @Test
    fun onFocusChanged_true_carries_formattedText_into_Editing() = runTest {
        val vm = makeVm(initialValue = 1234.5, locale = "en-US")
        // Idle.formattedText = "1,234.50" via Fake
        val idle = assertIs<NumberInputUiState.Idle>(vm.state.value)
        assertEquals("1,234.50", idle.formattedText)
        vm.onFocusChanged(true)
        advanceUntilIdle()
        val editing = assertIs<NumberInputUiState.Editing>(vm.state.value)
        assertEquals("1,234.50", editing.formattedText)
        assertEquals("1,234.50", editing.rawText)
    }

    // Test 22 — onToggleSign produces locale-aware formatted rawText (vi-VN uses "," decimal)
    @Test
    fun onToggleSign_produces_locale_aware_rawText_vi_VN() = runTest {
        val vm = makeVm(initialValue = 42.5, locale = "vi-VN")
        vm.onFocusChanged(true)
        advanceUntilIdle()
        vm.onToggleSign()
        advanceUntilIdle()
        val state = assertIs<NumberInputUiState.Editing>(vm.state.value)
        assertEquals(-42.5, state.value)
        assertEquals("-42,50", state.formattedText)
    }
}
