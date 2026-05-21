package dev.viethung.skeleton.android.showcase

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import dev.viethung.skylog.Skylog
import dev.viethung.skylog.ui.LogConsoleScreen
import dev.viethung.skylog.writers.InMemoryLogWriter
import org.koin.compose.koinInject

@Composable
fun SkylogShowcaseScreen(onClose: () -> Unit) {
    val buffer: InMemoryLogWriter = koinInject()

    LaunchedEffect(Unit) {
        Skylog.v(tag = "Showcase") { "Verbose — app started" }
        Skylog.d(tag = "Showcase") { "Debug — configuration loaded" }
        Skylog.i(tag = "Showcase") { "Info — user signed in" }
        Skylog.w(tag = "Showcase") { "Warn — slow network detected" }
        Skylog.e(tag = "Showcase", throwable = RuntimeException("demo error")) { "Error — request failed" }
        Skylog.a(tag = "Showcase") { "Assert — invariant violated" }
        Skylog.i(
            tag = "Showcase",
            fields = mapOf("userId" to "42", "screen" to "dashboard"),
        ) { "Info with structured fields" }
    }

    LogConsoleScreen(buffer = buffer, onClose = onClose)
}
