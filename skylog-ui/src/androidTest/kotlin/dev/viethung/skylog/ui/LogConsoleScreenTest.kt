package dev.viethung.skylog.ui

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTextInput
import dev.viethung.skylog.LogEntry
import dev.viethung.skylog.Severity
import dev.viethung.skylog.writers.InMemoryLogWriter
import kotlinx.datetime.Clock
import org.junit.Rule
import org.junit.Test

/**
 * Compose UI tests for [LogConsoleScreen] — §9.5 rows 1–4, 7–9.
 * Rows 5 and 10 are in [FloatingLogButtonTest]; row 6 is in [LogRecompositionsTest].
 */
class LogConsoleScreenTest {

    @get:Rule
    val composeTestRule = createComposeRule()

    // ──────────────────────────────────────────────────────────────────────────
    // Row 1 — Empty buffer → empty-state visible
    // ──────────────────────────────────────────────────────────────────────────

    @Test
    fun emptyBuffer_showsEmptyState() {
        val buffer = InMemoryLogWriter()
        composeTestRule.setContent {
            LogConsoleScreen(buffer = buffer)
        }
        composeTestRule.onNodeWithText("No logs yet").assertIsDisplayed()
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Row 2 — Filter Warn → only Warn+ visible
    // ──────────────────────────────────────────────────────────────────────────

    @Test
    fun severityFilter_warn_hidesLowerSeverities() {
        val buffer = InMemoryLogWriter()
        buffer.log(makeEntry(Severity.Debug, "debug message"))
        buffer.log(makeEntry(Severity.Info, "info message"))
        buffer.log(makeEntry(Severity.Warn, "warn message"))
        buffer.log(makeEntry(Severity.Error, "error message"))

        composeTestRule.setContent {
            LogConsoleScreen(buffer = buffer)
        }

        // Select the Warn chip
        composeTestRule.onNodeWithTag("severityChip.Warn").performClick()
        composeTestRule.waitForIdle()

        // Warn and Error rows visible
        composeTestRule.onNodeWithText("warn message").assertIsDisplayed()
        composeTestRule.onNodeWithText("error message").assertIsDisplayed()

        // Debug and Info rows not displayed
        composeTestRule.onNodeWithText("debug message").assertDoesNotExist()
        composeTestRule.onNodeWithText("info message").assertDoesNotExist()
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Row 3 — Search "auth" → only auth entries visible
    // ──────────────────────────────────────────────────────────────────────────

    @Test
    fun search_auth_filtersCorrectly() {
        val buffer = InMemoryLogWriter()
        buffer.log(makeEntry(Severity.Info, "User auth succeeded", tag = "Auth"))
        buffer.log(makeEntry(Severity.Info, "Cart loaded", tag = "Cart"))
        buffer.log(makeEntry(Severity.Debug, "auth token refreshed", tag = "Net"))

        composeTestRule.setContent {
            LogConsoleScreen(buffer = buffer)
        }

        // Type into the search field — mainClock.autoAdvance must be off for debounce test
        composeTestRule.onNodeWithTag("searchField").performTextInput("auth")
        // Advance past the 200 ms debounce
        composeTestRule.mainClock.advanceTimeBy(300L)
        composeTestRule.waitForIdle()

        composeTestRule.onNodeWithText("User auth succeeded").assertIsDisplayed()
        composeTestRule.onNodeWithText("auth token refreshed").assertIsDisplayed()
        composeTestRule.onNodeWithText("Cart loaded").assertDoesNotExist()
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Row 4 — Tap row Copy → clipboard tap does not crash
    // (Full clipboard content inspection requires a real device context; we verify
    //  the copy node is tappable and does not throw.)
    // ──────────────────────────────────────────────────────────────────────────

    @Test
    fun tapRowCopy_doesNotCrash() {
        val buffer = InMemoryLogWriter()
        val entry = makeEntry(Severity.Info, "clipboard test message", tag = "Test")
        buffer.log(entry)

        composeTestRule.setContent {
            LogConsoleScreen(buffer = buffer)
        }

        composeTestRule
            .onNodeWithTag("logRow.copy.${entry.timestamp.toEpochMilliseconds()}")
            .performClick()
        composeTestRule.waitForIdle()

        // Verify the copy node still exists (tap did not remove or crash the composable)
        composeTestRule
            .onNodeWithTag("logRow.copy.${entry.timestamp.toEpochMilliseconds()}")
            .assertExists()
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Row 7 — Tag dropdown filter (Eng Review T-2, FR-11)
    // ──────────────────────────────────────────────────────────────────────────

    @Test
    fun tagDropdown_filtersToSelectedTag() {
        val buffer = InMemoryLogWriter()
        buffer.log(makeEntry(Severity.Info, "auth event", tag = "Auth"))
        buffer.log(makeEntry(Severity.Info, "cart event", tag = "Cart"))
        buffer.log(makeEntry(Severity.Info, "net event", tag = "Net"))

        composeTestRule.setContent {
            LogConsoleScreen(buffer = buffer)
        }

        // Open tag dropdown and select "Cart"
        composeTestRule.onNodeWithTag("tagDropdown.chip").performClick()
        composeTestRule.onNodeWithTag("tagDropdown.Cart").performClick()
        composeTestRule.waitForIdle()

        composeTestRule.onNodeWithText("cart event").assertIsDisplayed()
        composeTestRule.onNodeWithText("auth event").assertDoesNotExist()
        composeTestRule.onNodeWithText("net event").assertDoesNotExist()

        // Clear the tag filter — select "All tags"
        composeTestRule.onNodeWithTag("tagDropdown.chip").performClick()
        composeTestRule.onNodeWithTag("tagDropdown.all").performClick()
        composeTestRule.waitForIdle()

        composeTestRule.onNodeWithText("auth event").assertIsDisplayed()
        composeTestRule.onNodeWithText("cart event").assertIsDisplayed()
        composeTestRule.onNodeWithText("net event").assertIsDisplayed()
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Row 8 — Multi-filter AND composition (Eng Review T-5, FR-11)
    // ──────────────────────────────────────────────────────────────────────────

    @Test
    fun multiFilter_andComposition() {
        val buffer = InMemoryLogWriter()
        buffer.log(makeEntry(Severity.Warn, "signed in", tag = "Auth"))
        buffer.log(makeEntry(Severity.Info, "signed in", tag = "Auth"))   // filtered by severity
        buffer.log(makeEntry(Severity.Warn, "signed in", tag = "Cart"))   // filtered by tag
        buffer.log(makeEntry(Severity.Warn, "page loaded", tag = "Auth")) // filtered by search

        composeTestRule.setContent {
            LogConsoleScreen(buffer = buffer)
        }

        // Set severity chip to Warn
        composeTestRule.onNodeWithTag("severityChip.Warn").performClick()
        composeTestRule.waitForIdle()

        // Set tag dropdown to "Auth"
        composeTestRule.onNodeWithTag("tagDropdown.chip").performClick()
        composeTestRule.onNodeWithTag("tagDropdown.Auth").performClick()
        composeTestRule.waitForIdle()

        // Type "signed" in search and wait for debounce
        composeTestRule.onNodeWithTag("searchField").performTextInput("signed")
        composeTestRule.mainClock.advanceTimeBy(300L)
        composeTestRule.waitForIdle()

        // Only the Warn + Auth + "signed" entry should survive
        composeTestRule.onNodeWithText("signed in").assertIsDisplayed()
        composeTestRule.onNodeWithText("page loaded").assertDoesNotExist()
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Row 9 — Clear with undo snackbar (Eng Review T-3 / P10a, PRD §8)
    // ──────────────────────────────────────────────────────────────────────────

    @Test
    fun clearWithUndo_restoresEntries() {
        val buffer = InMemoryLogWriter()
        buffer.log(makeEntry(Severity.Info, "first log"))
        buffer.log(makeEntry(Severity.Info, "second log"))
        buffer.log(makeEntry(Severity.Info, "third log"))

        composeTestRule.setContent {
            LogConsoleScreen(buffer = buffer)
        }

        // Confirm rows are present initially
        composeTestRule.onNodeWithText("first log").assertIsDisplayed()

        // Tap Clear
        composeTestRule.onNodeWithTag("clearButton").performClick()
        composeTestRule.waitForIdle()

        // Snackbar with "Undo" should appear
        composeTestRule.onNodeWithText("Undo").assertIsDisplayed()

        // Empty state should now be visible
        composeTestRule.onNodeWithText("No logs yet").assertIsDisplayed()

        // Tap "Undo"
        composeTestRule.onNodeWithText("Undo").performClick()
        composeTestRule.waitForIdle()

        // Rows should be restored
        composeTestRule.onNodeWithText("first log").assertIsDisplayed()
        composeTestRule.onNodeWithText("second log").assertIsDisplayed()
        composeTestRule.onNodeWithText("third log").assertIsDisplayed()
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Helpers
    // ──────────────────────────────────────────────────────────────────────────

    private fun makeEntry(
        severity: Severity,
        message: String,
        tag: String = "Test",
    ) = LogEntry(
        timestamp = Clock.System.now(),
        severity = severity,
        tag = tag,
        message = message,
        throwable = null,
        fields = null,
    )
}
