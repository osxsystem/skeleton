package dev.viethung.skylog

import kotlinx.atomicfu.atomic
import kotlinx.atomicfu.locks.SynchronizedObject
import kotlinx.atomicfu.locks.synchronized
import kotlinx.datetime.Clock

class Logger internal constructor(initialConfig: SkylogConfig) {
    private val lock = SynchronizedObject()
    private val _config = atomic(initialConfig)

    // Exposed internal for tests that read config snapshot
    internal val config: SkylogConfig get() = _config.value

    fun v(tag: String? = null, throwable: Throwable? = null, message: () -> String) =
        log(Severity.Verbose, tag, throwable, null, message)

    fun d(tag: String? = null, throwable: Throwable? = null, message: () -> String) =
        log(Severity.Debug, tag, throwable, null, message)

    fun i(tag: String? = null, throwable: Throwable? = null, message: () -> String) =
        log(Severity.Info, tag, throwable, null, message)

    fun w(tag: String? = null, throwable: Throwable? = null, message: () -> String) =
        log(Severity.Warn, tag, throwable, null, message)

    fun e(tag: String? = null, throwable: Throwable? = null, message: () -> String) =
        log(Severity.Error, tag, throwable, null, message)

    fun a(tag: String? = null, throwable: Throwable? = null, message: () -> String) =
        log(Severity.Assert, tag, throwable, null, message)

    fun i(
        tag: String? = null,
        fields: Map<String, String>,
        throwable: Throwable? = null,
        message: () -> String,
    ) = log(Severity.Info, tag, throwable, fields, message)

    fun v(
        tag: String? = null,
        fields: Map<String, String>,
        throwable: Throwable? = null,
        message: () -> String,
    ) = log(Severity.Verbose, tag, throwable, fields, message)

    fun d(
        tag: String? = null,
        fields: Map<String, String>,
        throwable: Throwable? = null,
        message: () -> String,
    ) = log(Severity.Debug, tag, throwable, fields, message)

    fun w(
        tag: String? = null,
        fields: Map<String, String>,
        throwable: Throwable? = null,
        message: () -> String,
    ) = log(Severity.Warn, tag, throwable, fields, message)

    fun e(
        tag: String? = null,
        fields: Map<String, String>,
        throwable: Throwable? = null,
        message: () -> String,
    ) = log(Severity.Error, tag, throwable, fields, message)

    fun a(
        tag: String? = null,
        fields: Map<String, String>,
        throwable: Throwable? = null,
        message: () -> String,
    ) = log(Severity.Assert, tag, throwable, fields, message)

    fun configure(block: SkylogConfig.() -> Unit) {
        synchronized(lock) { _config.value = _config.value.copy().apply(block) }
    }

    private inline fun log(
        severity: Severity,
        tag: String?,
        throwable: Throwable?,
        fields: Map<String, String>?,
        message: () -> String,
    ) {
        val snapshot = _config.value  // single read of the atomic reference
        if (severity < snapshot.minSeverity) return
        val resolvedTag = tag ?: DEFAULT_TAG
        val writers = snapshot.writers
        // Fan-out safety: a buggy lambda OR a buggy writer (log() OR isLoggable())
        // must NOT kill logging for the rest. isLoggable wrap added per Eng Review
        // §1 finding T-1 (symmetric with the log() catch below).
        val anyLoggable = writers.any { w ->
            try { w.isLoggable(resolvedTag, severity) } catch (_: Throwable) { false }
        }
        if (!anyLoggable) return

        val msg = try {
            message()
        } catch (t: Throwable) {
            "<lazy message failed: ${t::class.simpleName}: ${t.message}>"
        }
        val entry = LogEntry(
            timestamp = Clock.System.now(),
            severity = severity,
            tag = resolvedTag,
            message = msg,
            throwable = throwable,
            fields = fields,
        )
        for (w in writers) {
            val loggable = try { w.isLoggable(resolvedTag, severity) } catch (_: Throwable) { false }
            if (!loggable) continue
            try { w.log(entry) } catch (_: Throwable) { /* isolated; never propagate */ }
        }
    }
}

internal const val DEFAULT_TAG = "Skylog"
