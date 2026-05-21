package dev.viethung.skylog

import io.kotest.matchers.shouldBe
import kotlin.test.Test
import kotlin.test.assertFalse

class LogWriterCompositionTest {

    private fun captureWriter(accept: Boolean = true): Pair<LogWriter, () -> Int> {
        var count = 0
        val writer = object : LogWriter() {
            override fun log(entry: LogEntry) { count++ }
            override fun isLoggable(tag: String, severity: Severity) = accept
        }
        return writer to { count }
    }

    // Row 1: Two writers, both loggable → both receive entry
    @Test
    fun bothLoggableWritersBothReceiveEntry() {
        val (w1, count1) = captureWriter()
        val (w2, count2) = captureWriter()
        val logger = Logger(SkylogConfig().apply { writers.addAll(listOf(w1, w2)) })
        logger.i { "msg" }
        count1() shouldBe 1
        count2() shouldBe 1
    }

    // Row 2: Two writers, one vetoes via isLoggable=false → only one receives
    @Test
    fun vetoingWriterDoesNotReceiveEntry() {
        val (w1, count1) = captureWriter(accept = true)
        val (w2, count2) = captureWriter(accept = false)
        val logger = Logger(SkylogConfig().apply { writers.addAll(listOf(w1, w2)) })
        logger.i { "msg" }
        count1() shouldBe 1
        count2() shouldBe 0
    }

    // Row 3: All writers veto → message lambda not evaluated
    @Test
    fun allVetoingWritersPreventLambdaEval() {
        var called = false
        val (w1, _) = captureWriter(accept = false)
        val (w2, _) = captureWriter(accept = false)
        val logger = Logger(SkylogConfig().apply { writers.addAll(listOf(w1, w2)) })
        logger.i { called = true; "msg" }
        assertFalse(called, "lambda must not be evaluated when all writers veto")
    }
}
