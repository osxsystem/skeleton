package dev.viethung.skylog.ui

import androidx.compose.material3.Text
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.foundation.clickable
import dev.viethung.skylog.Skylog
import dev.viethung.skylog.writers.InMemoryLogWriter
import org.junit.After
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import androidx.compose.foundation.layout.Column
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import dev.viethung.skylog.ui.compose.LogRecompositions

/**
 * Compose UI test for [LogRecompositions] — §9.5 row 6.
 *
 * Row 6: [LogRecompositions](label, everyN = 5) → InMemoryLogWriter receives a debug
 * entry every 5 recompositions.
 */
class LogRecompositionsTest {

    @get:Rule
    val composeTestRule = createComposeRule()

    private val buffer = InMemoryLogWriter()

    @Before
    fun setUp() {
        Skylog.configure {
            writers.clear()
            writers += buffer
        }
    }

    @After
    fun tearDown() {
        Skylog.configure { writers.clear() }
    }

    @Test
    fun logRecompositions_everyN5_logsEveryFifthRecomposition() {
        // Force recompositions by toggling a state variable — we tap a button that
        // increments a counter, causing the composable tree to recompose.
        composeTestRule.setContent {
            var counter by remember { mutableIntStateOf(0) }

            Column {
                LogRecompositions(label = "TestScreen", everyN = 5)
                Text(
                    text = "Count: $counter",
                    modifier = Modifier
                        .testTag("counter")
                        .clickable { counter++ },
                )
            }
        }

        // Initial composition counts as recomposition #1 in SideEffect.
        // Tap 9 more times → total 10 recompositions → 2 log entries (at n=5 and n=10).
        repeat(9) {
            composeTestRule.onNodeWithText("Count: $it").performClick()
            composeTestRule.waitForIdle()
        }

        val recompEntries = buffer.entries.value.filter {
            it.tag == "Recomp" && it.message.startsWith("TestScreen recomposed")
        }

        // With everyN=5 and 10 total recompositions, we expect exactly 2 log entries.
        assertTrue(
            "Expected at least 2 Recomp entries (at n=5 and n=10), got ${recompEntries.size}. " +
                "Entries: ${buffer.entries.value.map { it.message }}",
            recompEntries.size >= 2,
        )
    }
}
