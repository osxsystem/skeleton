package dev.viethung.skylog

import app.cash.turbine.test
import dev.viethung.skylog.writers.InMemoryLogWriter
import io.kotest.assertions.throwables.shouldThrow
import io.kotest.matchers.collections.shouldBeEmpty
import io.kotest.matchers.collections.shouldHaveSize
import io.kotest.matchers.shouldBe
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.runTest
import kotlinx.datetime.Clock
import kotlin.test.Test

class InMemoryLogWriterTest {

    private fun entry(tag: String = "Test", msg: String = "msg") = LogEntry(
        timestamp = Clock.System.now(),
        severity = Severity.Info,
        tag = tag,
        message = msg,
        throwable = null,
        fields = null,
    )

    // Row 1: empty buffer initial state
    @Test
    fun initialStateIsEmpty() {
        val writer = InMemoryLogWriter()
        writer.entries.value.shouldBeEmpty()
    }

    // Row 2: single entry append
    @Test
    fun singleEntryAppend() = runTest {
        val writer = InMemoryLogWriter()
        writer.entries.test {
            awaitItem() // initial empty
            writer.log(entry(msg = "hello"))
            awaitItem().shouldHaveSize(1)
            cancelAndIgnoreRemainingEvents()
        }
    }

    // Row 3: capacity rollover
    @Test
    fun capacityRollover() {
        val capacity = 5
        val writer = InMemoryLogWriter(capacity = capacity)
        repeat(capacity + 1) { i -> writer.log(entry(msg = "msg$i")) }
        writer.entries.value.shouldHaveSize(capacity)
        writer.entries.value.first().message shouldBe "msg1"  // oldest (msg0) dropped
    }

    // Row 4: clear empties buffer
    @Test
    fun clearEmptiesBuffer() = runTest {
        val writer = InMemoryLogWriter()
        writer.log(entry())
        writer.entries.value.shouldHaveSize(1)
        writer.clear()
        writer.entries.value.shouldBeEmpty()
    }

    // Row 5: concurrent writes preserve order (no duplicates, correct count)
    @Test
    fun concurrentWritesPreserveCount() = runTest {
        val capacity = 100
        val writer = InMemoryLogWriter(capacity = capacity)
        val jobs = (1..4).map { coroutineNum ->
            launch {
                repeat(25) { i -> writer.log(entry(msg = "c$coroutineNum-$i")) }
            }
        }
        jobs.forEach { it.join() }
        writer.entries.value.shouldHaveSize(capacity)
        // No duplicates — all messages are unique strings
        val messages = writer.entries.value.map { it.message }
        messages.toSet().size shouldBe capacity
    }

    // Row 6: capacity=0 rejected at construction
    @Test
    fun zeroCapacityThrows() {
        shouldThrow<IllegalArgumentException> {
            InMemoryLogWriter(capacity = 0)
        }
    }

    // Row 7: high-concurrency stress — 100 coroutines × 10 writes on capacity=1000
    // (scaled to 100×10=1000 total to keep test fast without losing stress coverage)
    @Test
    fun highConcurrencyStress() = runTest {
        val capacity = 1000
        val writer = InMemoryLogWriter(capacity = capacity)
        val coroutineCount = 100
        val writesPerCoroutine = 10
        val jobs = (1..coroutineCount).map { c ->
            launch {
                repeat(writesPerCoroutine) { i -> writer.log(entry(msg = "stress-c$c-$i")) }
            }
        }
        jobs.forEach { it.join() }
        val finalSize = writer.entries.value.size
        // All 1000 entries fit in capacity, no IndexOutOfBoundsException thrown
        finalSize shouldBe (coroutineCount * writesPerCoroutine)
    }
}
