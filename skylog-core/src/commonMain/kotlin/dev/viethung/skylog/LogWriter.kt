package dev.viethung.skylog

abstract class LogWriter {
    abstract fun log(entry: LogEntry)
    open fun isLoggable(tag: String, severity: Severity): Boolean = true
}
