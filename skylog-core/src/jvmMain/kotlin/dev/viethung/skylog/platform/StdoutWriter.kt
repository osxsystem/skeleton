package dev.viethung.skylog.platform

import dev.viethung.skylog.LogEntry
import dev.viethung.skylog.LogWriter
import dev.viethung.skylog.Severity

class StdoutWriter(private val ansiColor: Boolean = System.console() != null) : LogWriter() {
    override fun log(entry: LogEntry) {
        val color = if (ansiColor) colorFor(entry.severity) else ""
        val reset = if (ansiColor) ANSI_RESET else ""
        val fields = entry.fields?.let { " " + it.entries.joinToString(" ") { (k, v) -> "$k=$v" } } ?: ""
        println("$color${entry.timestamp} [${entry.severity.name.first()}] ${entry.tag}: ${entry.message}$fields$reset")
        entry.throwable?.let { it.printStackTrace(System.out) }
    }

    private fun colorFor(s: Severity) = when (s) {
        Severity.Verbose -> ANSI_GRAY
        Severity.Debug   -> ANSI_BLUE
        Severity.Info    -> ANSI_GREEN
        Severity.Warn    -> ANSI_YELLOW
        Severity.Error   -> ANSI_RED
        Severity.Assert  -> ANSI_MAGENTA
    }

    companion object {
        private const val ANSI_RESET   = "[0m"
        private const val ANSI_GRAY    = "[90m"
        private const val ANSI_BLUE    = "[34m"
        private const val ANSI_GREEN   = "[32m"
        private const val ANSI_YELLOW  = "[33m"
        private const val ANSI_RED     = "[31m"
        private const val ANSI_MAGENTA = "[35m"
    }
}

actual fun platformDefaultWriter(): LogWriter = StdoutWriter()
