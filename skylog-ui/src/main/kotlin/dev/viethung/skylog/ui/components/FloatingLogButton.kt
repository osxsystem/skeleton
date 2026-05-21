package dev.viethung.skylog.ui.components

import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Badge
import androidx.compose.material3.BadgedBox
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import kotlin.math.roundToInt

/**
 * A draggable floating action button that opens the log console when tapped.
 *
 * Position is stored in [remember] — intentionally not persisted across process death
 * (debug-only, per Plan §5.4).
 *
 * Viewport clamping (Eng Review F-4.4): on every drag delta, the new offset is clamped
 * to `(0..maxX, 0..maxY)` so the button can never be dragged offscreen.
 */
@Composable
fun FloatingLogButton(
    onOpen: () -> Unit,
    modifier: Modifier = Modifier,
    badge: Int = 0,
) {
    // Offset is in pixels (IntOffset for the `offset{}` modifier).
    var offset by remember { mutableStateOf(Offset.Zero) }
    val density = LocalDensity.current
    val fabSizePx = with(density) { 56.dp.toPx() }

    BoxWithConstraints(modifier = modifier.fillMaxSize()) {
        val maxXPx = with(density) { maxWidth.toPx() } - fabSizePx
        val maxYPx = with(density) { maxHeight.toPx() } - fabSizePx

        Box(
            contentAlignment = Alignment.BottomEnd,
            modifier = Modifier.fillMaxSize(),
        ) {
            BadgedBox(
                badge = {
                    if (badge > 0) {
                        Badge { Text(text = badge.coerceAtMost(99).toString()) }
                    }
                },
                modifier = Modifier
                    .offset {
                        IntOffset(
                            x = offset.x.roundToInt(),
                            y = offset.y.roundToInt(),
                        )
                    }
                    .pointerInput(Unit) {
                        detectDragGestures { change, dragAmount ->
                            change.consume()
                            val newX = (offset.x + dragAmount.x).coerceIn(0f, maxXPx.coerceAtLeast(0f))
                            val newY = (offset.y + dragAmount.y).coerceIn(0f, maxYPx.coerceAtLeast(0f))
                            offset = Offset(newX, newY)
                        }
                    }
                    .testTag("floatingLogButton"),
            ) {
                FloatingActionButton(
                    onClick = onOpen,
                    containerColor = MaterialTheme.colorScheme.primaryContainer,
                    modifier = Modifier.size(56.dp),
                ) {
                    Text(
                        text = "LOG",
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onPrimaryContainer,
                    )
                }
            }
        }
    }
}
