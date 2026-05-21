package dev.viethung.skylog.platform

import android.os.Build
import android.util.Log
import dev.viethung.skylog.LogEntry
import dev.viethung.skylog.LogWriter
import dev.viethung.skylog.Severity

class LogcatWriter : LogWriter() {
    override fun log(entry: LogEntry) {
        // PRD D6: truncate to 23 chars on API <26 (Logcat throws IllegalArgumentException
        // there); full tag on API >=26. Eng Review §2 finding A-9 — previously truncated
        // unconditionally.
        val tag = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) entry.tag
                  else entry.tag.take(MAX_TAG_LEN)
        val msg = entry.message + (entry.fields?.let { " " + it.entries.joinToString(" ") { (k, v) -> "$k=$v" } } ?: "")
        when (entry.severity) {
            Severity.Verbose -> Log.v(tag, msg, entry.throwable)
            Severity.Debug   -> Log.d(tag, msg, entry.throwable)
            Severity.Info    -> Log.i(tag, msg, entry.throwable)
            Severity.Warn    -> Log.w(tag, msg, entry.throwable)
            Severity.Error   -> Log.e(tag, msg, entry.throwable)
            Severity.Assert  -> Log.wtf(tag, msg, entry.throwable)
        }
    }

    companion object {
        const val MAX_TAG_LEN = 23  // PRD D6
    }
}

actual fun platformDefaultWriter(): LogWriter = LogcatWriter()
