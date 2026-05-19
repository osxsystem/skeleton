package dev.viethung.components.numberinput

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

/**
 * Contract tests for [LocaleNumberFormatter] — exercises the platform `actual` via [newLocaleNumberFormatter].
 * Run via: ./gradlew :shared-components:iosSimulatorArm64Test
 * These tests are SKIPPED on commonTest/jvmTest; they run meaningfully only on iosTest targets.
 */
class LocaleNumberFormatterContractTest {

    private val formatter = newLocaleNumberFormatter()

    @Test
    fun `format 1234567_89 en-US sigDigits 2`() {
        val result = formatter.format(1234567.89, 2, "en-US")
        assertEquals("1,234,567.89", result)
    }

    @Test
    fun `format 1234567_89 vi-VN sigDigits 2`() {
        val result = formatter.format(1234567.89, 2, "vi-VN")
        assertEquals("1.234.567,89", result)
    }

    @Test
    fun `format 1234567_89 de-DE sigDigits 2`() {
        val result = formatter.format(1234567.89, 2, "de-DE")
        assertEquals("1.234.567,89", result)
    }

    @Test
    fun `format 0_1 en-US sigDigits 3 pads trailing zeros`() {
        val result = formatter.format(0.1, 3, "en-US")
        assertEquals("0.100", result)
    }

    @Test
    fun `format -0_1 en-US sigDigits 3`() {
        val result = formatter.format(-0.1, 3, "en-US")
        assertEquals("-0.100", result)
    }

    @Test
    fun `format 1_23456 en-US sigDigits 2 rounds half-even`() {
        val result = formatter.format(1.23456, 2, "en-US")
        assertEquals("1.23", result)
    }

    @Test
    fun `format 2_5 en-US sigDigits 0 rounds half-even to 2`() {
        val result = formatter.format(2.5, 0, "en-US")
        // half-even: 2.5 rounds to 2 (nearest even)
        assertEquals("2", result)
    }

    @Test
    fun `parse 1234_5 en-US`() {
        val result = formatter.parse("1,234.5", "en-US")
        assertEquals(1234.5, result)
    }

    @Test
    fun `parse 1234_5 vi-VN`() {
        val result = formatter.parse("1.234,5", "vi-VN")
        assertEquals(1234.5, result)
    }

    @Test
    fun `parse empty string returns null`() {
        val result = formatter.parse("", "en-US")
        assertNull(result)
    }

    @Test
    fun `formatLive 1000 en-US groups thousands`() {
        assertEquals("1,000", formatter.formatLive("1000", "en-US"))
    }

    @Test
    fun `formatLive 1234567 en-US groups millions`() {
        assertEquals("1,234,567", formatter.formatLive("1234567", "en-US"))
    }

    @Test
    fun `formatLive preserves decimal portion en-US`() {
        assertEquals("1,000.5", formatter.formatLive("1000.5", "en-US"))
        assertEquals("1,000.", formatter.formatLive("1000.", "en-US"))
    }

    @Test
    fun `formatLive idempotent for already-grouped en-US`() {
        assertEquals("1,000", formatter.formatLive("1,000", "en-US"))
        assertEquals("10,009", formatter.formatLive("1,0009", "en-US"))
    }

    @Test
    fun `formatLive minus alone preserved`() {
        assertEquals("-", formatter.formatLive("-", "en-US"))
    }

    @Test
    fun `formatLive empty returns empty`() {
        assertEquals("", formatter.formatLive("", "en-US"))
    }

    @Test
    fun `formatLive 1000 vi-VN uses dot grouping`() {
        assertEquals("1.000", formatter.formatLive("1000", "vi-VN"))
    }

    @Test
    fun `formatLive 1000 de-DE uses dot grouping`() {
        assertEquals("1.000", formatter.formatLive("1000", "de-DE"))
    }

    @Test
    fun `formatLive vi-VN preserves comma decimal`() {
        assertEquals("1.000,5", formatter.formatLive("1000,5", "vi-VN"))
    }
}
