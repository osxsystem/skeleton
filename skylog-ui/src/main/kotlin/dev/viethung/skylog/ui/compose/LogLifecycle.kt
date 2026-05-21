package dev.viethung.skylog.ui.compose

import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import dev.viethung.skylog.Skylog

/**
 * Logs a [Debug][dev.viethung.skylog.Severity.Debug] entry when [label] enters and
 * leaves the composition.
 *
 * Drop this at the top of any composable to trace its attach/detach lifecycle in the
 * log console (FR-15).
 *
 * @param label  A human-readable name for the composable being observed.
 */
@Composable
fun LogLifecycle(label: String) {
    DisposableEffect(Unit) {
        Skylog.d(tag = "Lifecycle") { "$label entered composition" }
        onDispose {
            Skylog.d(tag = "Lifecycle") { "$label left composition" }
        }
    }
}
