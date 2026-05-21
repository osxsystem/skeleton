package dev.viethung.skylog.platform

import dev.viethung.skylog.LogEntry
import dev.viethung.skylog.LogWriter
import dev.viethung.skylog.Severity

// v0.1 uses NSLog only (simpler, public API). v0.2 may switch to os_log via cinterop
// for log-archive integration (PRD RP-06).
class OsLogWriter : LogWriter() {
    override fun log(entry: LogEntry) {
        val prefix = "[${entry.severity.name.first()}] ${entry.tag}"
        val msg = entry.message + (entry.fields?.let { " " + it.entries.joinToString(" ") { (k, v) -> "$k=$v" } } ?: "")
        platform.Foundation.NSLog("$prefix: $msg")
        entry.throwable?.let { t ->
            // Mega Plan Review §2 finding F-2.4: stackTraceToString() on K/N can throw on
            // pathological stacks; isolate so logging never fails.
            val trace = try {
                t.stackTraceToString()
            } catch (_: Throwable) {
                "<stack trace unavailable: ${t::class.simpleName}>"
            }
            platform.Foundation.NSLog("    $trace")
        }
    }
}

actual fun platformDefaultWriter(): LogWriter = OsLogWriter()
