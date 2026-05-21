package dev.viethung.skylog

import kotlin.test.Test
import kotlin.test.assertTrue

/**
 * NFR-01 micro-benchmark (§9.1 row 10).
 *
 * 1M `Logger.d { "msg" }` calls with `minSeverity = Info` (lambda is never evaluated).
 * Target: < 100 ms total, i.e., ~100 ns/call on a modern dev machine.
 *
 * Run selectively: `./gradlew :skylog-core:jvmTest --tests "*Benchmark*"`
 */
class SkylogBenchmarkTest {

    @Test
    fun nfrLazyEvalOneMillionCallsUnder100ms() {
        val logger = Logger(SkylogConfig(minSeverity = Severity.Info))
        val iterations = 1_000_000
        val start = System.nanoTime()
        repeat(iterations) {
            logger.d { "msg" }
        }
        val elapsed = System.nanoTime() - start
        val elapsedMs = elapsed / 1_000_000L
        assertTrue(
            elapsedMs < 100,
            "NFR-01: 1M filtered log calls took ${elapsedMs}ms, expected < 100ms",
        )
    }
}
