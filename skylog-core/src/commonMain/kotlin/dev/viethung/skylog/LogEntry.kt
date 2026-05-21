package dev.viethung.skylog

import kotlinx.datetime.Instant

data class LogEntry(
    val timestamp: Instant,
    val severity: Severity,
    val tag: String,
    val message: String,
    val throwable: Throwable?,
    val fields: Map<String, String>?,
)
