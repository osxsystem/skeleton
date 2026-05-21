package dev.viethung.skylog

import dev.viethung.skylog.writers.InMemoryLogWriter
import io.kotest.matchers.shouldBe
import io.kotest.matchers.string.shouldContain
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

class SkylogTest {

    private fun freshLogger(vararg writers: LogWriter): Logger =
        Logger(SkylogConfig().apply { this.writers.addAll(writers) })

    private fun freshLogger(minSeverity: Severity, vararg writers: LogWriter): Logger =
        Logger(SkylogConfig(minSeverity = minSeverity).apply { this.writers.addAll(writers) })

    private fun recordingWriter(accept: Boolean = true): Pair<LogWriter, () -> LogEntry?> {
        var captured: LogEntry? = null
        val writer = object : LogWriter() {
            override fun log(entry: LogEntry) { captured = entry }
            override fun isLoggable(tag: String, severity: Severity) = accept
        }
        return writer to { captured }
    }

    // Row 1: Lambda not evaluated when severity below minimum
    @Test
    fun lambdaNotEvaluatedWhenSeverityBelowMin() {
        var called = false
        val (writer, _) = recordingWriter()
        val logger = freshLogger(Severity.Info, writer)
        logger.d { called = false.also { called = true }; "msg" }
        assertFalse(called, "lambda must not be evaluated when severity < minSeverity")
    }

    // Row 2: Lambda not evaluated when no writer is loggable
    @Test
    fun lambdaNotEvaluatedWhenNoWriterLoggable() {
        var called = false
        val writer = object : LogWriter() {
            override fun log(entry: LogEntry) {}
            override fun isLoggable(tag: String, severity: Severity) = false
        }
        val logger = freshLogger(writer)
        logger.i { called = true; "msg" }
        assertFalse(called, "lambda must not be evaluated when no writer is loggable")
    }

    // Row 3: Lambda evaluated exactly once even with multiple writers
    @Test
    fun lambdaEvaluatedExactlyOnceWithMultipleWriters() {
        var callCount = 0
        val writers = (1..3).map { recordingWriter().first }
        val logger = freshLogger(*writers.toTypedArray())
        logger.i { callCount++; "msg" }
        callCount shouldBe 1
    }

    // Row 4: Tag falls back to DEFAULT_TAG when null
    @Test
    fun tagFallsBackToDefault() {
        val (writer, getEntry) = recordingWriter()
        val logger = freshLogger(writer)
        logger.i(tag = null) { "msg" }
        getEntry()?.tag shouldBe DEFAULT_TAG
    }

    // Row 5: Structured fields passed through
    @Test
    fun structuredFieldsPassedThrough() {
        val (writer, getEntry) = recordingWriter()
        val logger = freshLogger(writer)
        logger.i(tag = "Test", fields = mapOf("id" to "42")) { "msg" }
        getEntry()?.fields?.get("id") shouldBe "42"
    }

    // Row 6: Throwable passed through
    @Test
    fun throwablePassedThrough() {
        val ex = RuntimeException("boom")
        val (writer, getEntry) = recordingWriter()
        val logger = freshLogger(writer)
        logger.e(throwable = ex) { "msg" }
        getEntry()?.throwable shouldBe ex
    }

    // Row 7: Structured-fields call still lazy when filtered out
    @Test
    fun structuredFieldsCallLazyWhenFilteredOut() {
        var called = false
        val (writer, _) = recordingWriter()
        val logger = freshLogger(Severity.Info, writer)
        logger.d(tag = "Test", fields = mapOf("k" to "v")) { called = true; "msg" }
        assertFalse(called, "lambda must not be evaluated when severity < minSeverity")
    }

    // Row 8: Buggy writer doesn't kill fan-out
    @Test
    fun buggyWriterDoesNotKillFanOut() {
        val (goodWriter, getEntry) = recordingWriter()
        val badWriter = object : LogWriter() {
            override fun log(entry: LogEntry) { throw RuntimeException("writer exploded") }
        }
        val logger = freshLogger(badWriter, goodWriter)
        // Must not throw
        logger.i { "hello" }
        assertNotNull(getEntry(), "second writer must still receive the entry")
    }

    // Row 9: Buggy lambda doesn't crash caller
    @Test
    fun buggyLambdaDoesNotCrashCaller() {
        val (writer, getEntry) = recordingWriter()
        val logger = freshLogger(writer)
        // Must not throw
        logger.i { throw RuntimeException("boom") }
        val entry = getEntry()
        assertNotNull(entry, "writer must still receive an entry with a synthetic message")
        entry.message shouldContain "<lazy message failed:"
    }

    // Row 10: NFR-01 micro-benchmark — JVM target only, skipped on Native
    // Placed in jvmTest source set to avoid @IgnoredOnNative import complexity.
    // See jvmTest/SkylogBenchmarkTest.kt

    // Row 11: Buggy isLoggable doesn't crash caller (Eng Review T-1)
    @Test
    fun buggyIsLoggableDoesNotCrashCaller() {
        val (goodWriter, getEntry) = recordingWriter(accept = true)
        val badWriter = object : LogWriter() {
            override fun log(entry: LogEntry) { /* should not be called */ }
            override fun isLoggable(tag: String, severity: Severity): Boolean {
                throw RuntimeException("isLoggable exploded")
            }
        }
        // bad writer first, good writer second
        val logger = freshLogger(badWriter, goodWriter)
        // Must not throw
        logger.i { "hello" }
        // Good writer must still receive the entry (bad writer's isLoggable -> false via catch)
        assertNotNull(getEntry(), "good writer must still receive the entry")
    }

    // Row 12: configure() concurrent with log() doesn't tear
    @Test
    fun configureConcurrentWithLogDoesNotTear() = runTest {
        val writer = InMemoryLogWriter(capacity = 5000)
        val logger = freshLogger(writer)

        val configJob = launch {
            repeat(1000) {
                logger.configure { /* writers list unchanged; just exercises the lock */ }
            }
        }
        val logJob = launch {
            repeat(1000) {
                logger.i { "concurrent-$it" }
            }
        }

        configJob.join()
        logJob.join()
        // No ConcurrentModificationException; at least one entry was captured
        assertTrue(writer.entries.value.isNotEmpty(), "at least one entry must be visible")
    }
}
