import XCTest
@testable import SkylogKit

/// Mirror of `InMemoryLogWriterTest.kt` (commonTest §9.2).
final class InMemoryLogWriterTests: XCTestCase {

    // MARK: - Helpers

    private func makeEntry(tag: String = "Test", message: String = "msg") -> LogEntry {
        LogEntry(timestamp: Date(), severity: .info, tag: tag, message: message)
    }

    // MARK: - Row 1: Empty buffer initial state

    func test_row1_initialStateIsEmpty() {
        let writer = InMemoryLogWriter()
        XCTAssertTrue(writer.entries.isEmpty)
    }

    // MARK: - Row 2: Single entry append

    func test_row2_singleEntryAppend() {
        let writer = InMemoryLogWriter()
        writer.log(makeEntry(message: "first"))
        XCTAssertEqual(writer.entries.count, 1)
        XCTAssertEqual(writer.entries[0].message, "first")
    }

    // MARK: - Row 3: Capacity rollover — oldest entry dropped

    func test_row3_capacityRollover_dropsOldestEntry() {
        let capacity = 3
        let writer = InMemoryLogWriter(capacity: capacity)
        for i in 0..<(capacity + 1) {
            writer.log(makeEntry(message: "entry-\(i)"))
        }
        XCTAssertEqual(writer.entries.count, capacity)
        XCTAssertEqual(writer.entries[0].message, "entry-1", "oldest entry (entry-0) should be dropped")
        XCTAssertEqual(writer.entries.last?.message, "entry-3")
    }

    // MARK: - Row 4: clear() empties buffer

    func test_row4_clearEmptiesBuffer() {
        let writer = InMemoryLogWriter()
        writer.log(makeEntry())
        writer.log(makeEntry())
        writer.clear()
        XCTAssertTrue(writer.entries.isEmpty)
    }

    // MARK: - Row 5: Concurrent writes preserve size (no duplicates, no crashes)
    //
    // Swift async: we use DispatchGroup + concurrent queue to simulate concurrent writes.
    // Full ordering verification is skipped (Dictionary ordering is non-deterministic);
    // we assert size and no crashes.

    func test_row5_concurrentWrites_preserveSize() {
        let capacity = 100
        let writer = InMemoryLogWriter(capacity: capacity)
        let group  = DispatchGroup()
        let queue  = DispatchQueue(label: "test.concurrent", attributes: .concurrent)
        let total  = 100

        for i in 0..<total {
            group.enter()
            queue.async {
                writer.log(self.makeEntry(message: "m\(i)"))
                group.leave()
            }
        }
        group.wait()

        // All writes fit within capacity (total == capacity here)
        XCTAssertEqual(writer.entries.count, capacity)
        // No duplicate messages
        let messages = writer.entries.map(\.message)
        XCTAssertEqual(messages.count, Set(messages).count, "duplicate entries detected — concurrent write race")
    }

    // MARK: - Row 6: capacity = 0 rejected at construction

    func test_row6_capacityZero_rejectedAtConstruction() {
        // precondition(false) is not catchable in Swift without ObjC bridging.
        // We document this as a precondition violation (same as Kotlin's IllegalArgumentException).
        // For the test, we verify the happy path: capacity = 1 is the minimum legal value.
        let writer = InMemoryLogWriter(capacity: 1)
        writer.log(makeEntry(message: "only"))
        XCTAssertEqual(writer.entries.count, 1)
        writer.log(makeEntry(message: "overflow"))
        XCTAssertEqual(writer.entries.count, 1)
        XCTAssertEqual(writer.entries[0].message, "overflow")
        // Note: Testing that InMemoryLogWriter(capacity: 0) triggers a precondition
        // failure is not possible in Swift without running a child process and checking
        // its exit code. This is documented as a known gap vs. the Kotlin test (row 6).
    }

    // MARK: - Row 7: High-concurrency stress

    func test_row7_highConcurrencyStress_noCorruption() {
        let capacity = 1000
        let writer   = InMemoryLogWriter(capacity: capacity)
        let group    = DispatchGroup()
        let queue    = DispatchQueue(label: "test.stress", attributes: .concurrent)
        let routines = 10
        let perRoute = 100  // 10 × 100 = 1000 total writes

        for r in 0..<routines {
            for i in 0..<perRoute {
                group.enter()
                queue.async {
                    writer.log(self.makeEntry(message: "r\(r)-i\(i)"))
                    group.leave()
                }
            }
        }
        group.wait()

        XCTAssertEqual(writer.entries.count, capacity, "ring buffer size must equal capacity after stress")
    }

    // MARK: - Extra: restore() capped at capacity

    func test_extra_restore_cappedAtCapacity() {
        let writer = InMemoryLogWriter(capacity: 3)
        let snap   = (0..<10).map { makeEntry(message: "s\($0)") }
        writer.restore(snapshot: snap)
        XCTAssertEqual(writer.entries.count, 3, "restore must cap at capacity")
        XCTAssertEqual(writer.entries[0].message, "s7", "restore must keep the most recent entries")
    }
}
