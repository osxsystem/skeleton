package dev.viethung.skylog.ui.compose

import androidx.compose.runtime.Composable
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.remember
import dev.viethung.skylog.Skylog

/**
 * Logs a [Debug][dev.viethung.skylog.Severity.Debug] entry every [everyN] recompositions.
 *
 * Drop this at the top of any composable to watch its recomposition count in the log console.
 *
 * ### Why `intArrayOf(0)` instead of `mutableStateOf(0)`
 *
 * Using `mutableStateOf` as the counter would make Compose snapshot-track the variable.
 * Every increment would schedule another recomposition, which would increment again — a
 * positive-feedback loop that pollutes the very signal we're measuring (PRD R-05,
 * Eng Review P5). A plain `IntArray` holder is mutable but NOT a snapshot-state object,
 * so it participates in `SideEffect` (runs after every commit) without triggering a new
 * frame itself.
 *
 * @param label  A human-readable name for the composable being observed.
 * @param everyN Log every Nth recomposition (default 1 = every recomposition).
 */
@Composable
fun LogRecompositions(label: String, everyN: Int = 1) {
    val count = remember { intArrayOf(0) }
    SideEffect {
        count[0]++
        if (count[0] % everyN == 0) {
            Skylog.d(tag = "Recomp") { "$label recomposed (n=${count[0]})" }
        }
    }
}
