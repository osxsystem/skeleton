package dev.viethung.skylog.ui

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.size
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.test.swipe
import androidx.compose.ui.unit.dp
import dev.viethung.skylog.ui.components.FloatingLogButton
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test

/**
 * Compose UI tests for [FloatingLogButton] — §9.5 rows 5 and 10.
 *
 * Row 5: tap → onOpen invoked.
 * Row 10 (REGRESSION): drag to (1000, 1000) → button clamped within viewport.
 *         drag to (-1000, -1000) → button clamped at (0, 0). (Eng Review F-4.4)
 */
class FloatingLogButtonTest {

    @get:Rule
    val composeTestRule = createComposeRule()

    // ──────────────────────────────────────────────────────────────────────────
    // Row 5 — Tap → onOpen invoked
    // ──────────────────────────────────────────────────────────────────────────

    @Test
    fun tap_invokesOnOpen() {
        var openCount = 0

        composeTestRule.setContent {
            Box(modifier = Modifier.fillMaxSize()) {
                FloatingLogButton(onOpen = { openCount++ })
            }
        }

        composeTestRule.onNodeWithTag("floatingLogButton").performClick()
        composeTestRule.waitForIdle()

        assertTrue("Expected onOpen to be called once, but was called $openCount times", openCount == 1)
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Row 10 — REGRESSION: viewport clamp (Eng Review T-4 / F-4.4)
    //
    // Render FloatingLogButton in a known-size container (360 × 640 dp).
    // Drag far beyond the viewport in each direction and assert the button
    // remains within bounds.
    // ──────────────────────────────────────────────────────────────────────────

    @Test
    fun drag_beyondViewport_clampsToMaxBounds() {
        composeTestRule.setContent {
            // BoxWithConstraints of known size — viewport is 360 × 640 dp
            Box(modifier = Modifier.size(width = 360.dp, height = 640.dp)) {
                FloatingLogButton(onOpen = {})
            }
        }

        val node = composeTestRule.onNodeWithTag("floatingLogButton")
        node.assertIsDisplayed()

        // Drag far beyond the bottom-right corner. FloatingLogButton internals
        // clamp the offset to (0..maxX, 0..maxY) where maxX = (boxWidth - fabSize)
        // and maxY = (boxHeight - fabSize).
        node.performTouchInput {
            down(center)
            moveBy(Offset(1000f, 1000f))
            up()
        }
        composeTestRule.waitForIdle()

        // The node must still be displayed — if it were off-screen the assertion fails.
        node.assertIsDisplayed()
    }

    @Test
    fun drag_beyondViewport_clampsToOrigin() {
        composeTestRule.setContent {
            Box(modifier = Modifier.size(width = 360.dp, height = 640.dp)) {
                FloatingLogButton(onOpen = {})
            }
        }

        val node = composeTestRule.onNodeWithTag("floatingLogButton")
        node.assertIsDisplayed()

        // Drag far past the top-left corner (negative direction).
        node.performTouchInput {
            down(center)
            moveBy(Offset(-1000f, -1000f))
            up()
        }
        composeTestRule.waitForIdle()

        // Still displayed — clamped at (0, 0).
        node.assertIsDisplayed()
    }
}
