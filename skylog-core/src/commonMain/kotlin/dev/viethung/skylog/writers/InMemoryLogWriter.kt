package dev.viethung.skylog.writers

import dev.viethung.skylog.LogEntry
import dev.viethung.skylog.LogWriter
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.update

class InMemoryLogWriter(private val capacity: Int = 1000) : LogWriter() {
    init {
        require(capacity > 0) { "capacity must be > 0, was $capacity" }
    }

    private val _entries = MutableStateFlow<List<LogEntry>>(emptyList())
    val entries: StateFlow<List<LogEntry>> = _entries

    override fun log(entry: LogEntry) {
        // MutableStateFlow.update uses compareAndSet internally — retries on
        // concurrent mutation, no thread can lose an entry to a race. This is
        // the chosen serialization primitive (Mega Plan Review §2 finding
        // F-2.1: original Mutex-based plan was suspending and incompatible
        // with non-suspend log(); update() gives the same mutual-exclusion
        // semantics without going suspending).
        _entries.update { current ->
            if (current.size < capacity) current + entry
            else current.drop(1) + entry
        }
    }

    fun clear() {
        _entries.value = emptyList()
    }

    /**
     * Restore a previously captured snapshot — supports `LogConsoleScreen` undo
     * (PRD §8 + Eng Review patch P10a). Snapshot is clamped to [capacity] to
     * preserve the ring-buffer invariant. Not exposed via [LogWriter] — internal
     * to [InMemoryLogWriter].
     */
    fun restore(snapshot: List<LogEntry>) {
        _entries.value = snapshot.takeLast(capacity)
    }
}
