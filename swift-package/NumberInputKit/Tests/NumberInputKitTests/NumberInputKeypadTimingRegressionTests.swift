#if canImport(UIKit)
import XCTest
@testable import NumberInputKit

@MainActor
final class NumberInputKeypadTimingRegressionTests: XCTestCase {

    func testHeldBackspaceRepeatsAtThresholdThenAtInterval() {
        let scheduler = ManualRepeatScheduler()
        var deletions: [TimeInterval] = []
        let repeater = NumberInputBackspaceRepeater(scheduler: scheduler)

        repeater.begin(isEnabled: { true }) {
            deletions.append(scheduler.now)
        }

        scheduler.advance(by: backspaceRepeatDelay - 0.001)
        XCTAssertEqual(deletions, [])

        scheduler.advance(by: 0.001)
        XCTAssertEqual(deletions.count, 1)
        XCTAssertEqual(deletions[0], 0.400, accuracy: 0.000_001)

        scheduler.advance(by: backspaceRepeatInterval)
        XCTAssertEqual(deletions.count, 2)
        XCTAssertEqual(deletions[1], 0.480, accuracy: 0.000_001)
    }

    func testEndingAHeldBackspaceCancelsRepeatsAndSuppressesTheReleasePress() {
        let scheduler = ManualRepeatScheduler()
        var deletionCount = 0
        let repeater = NumberInputBackspaceRepeater(scheduler: scheduler)

        repeater.begin(isEnabled: { true }) { deletionCount += 1 }
        scheduler.advance(by: backspaceRepeatDelay)

        XCTAssertTrue(repeater.end(), "the key must suppress the ordinary release action")
        scheduler.advance(by: backspaceRepeatInterval * 2)
        XCTAssertEqual(deletionCount, 1)
    }

    func testDisabledBackspaceNeverStartsRepeating() {
        let scheduler = ManualRepeatScheduler()
        var deletionCount = 0
        let repeater = NumberInputBackspaceRepeater(scheduler: scheduler)

        repeater.begin(isEnabled: { false }) { deletionCount += 1 }
        scheduler.advance(by: backspaceRepeatDelay + backspaceRepeatInterval)

        XCTAssertFalse(repeater.end())
        XCTAssertEqual(deletionCount, 0)
    }
}

@MainActor
private final class ManualRepeatScheduler: NumberInputRepeatScheduling {
    private struct Event {
        let id: UUID
        var fireTime: TimeInterval
        let interval: TimeInterval?
        let action: () -> Void
    }

    private(set) var now: TimeInterval = 0
    private var events: [Event] = []

    func schedule(
        after delay: TimeInterval,
        repeatingEvery interval: TimeInterval?,
        action: @escaping () -> Void
    ) -> NumberInputRepeatCancellation {
        let id = UUID()
        events.append(Event(id: id, fireTime: now + delay, interval: interval, action: action))
        return ManualCancellation { [weak self] in
            self?.events.removeAll { $0.id == id }
        }
    }

    func advance(by interval: TimeInterval) {
        let target = now + interval
        while let index = events.indices.min(by: { events[$0].fireTime < events[$1].fireTime }),
              events[index].fireTime <= target {
            var event = events.remove(at: index)
            now = event.fireTime
            event.action()
            if let repeatInterval = event.interval {
                event.fireTime += repeatInterval
                events.append(event)
            }
        }
        now = target
    }
}

private final class ManualCancellation: NumberInputRepeatCancellation {
    private let onCancel: () -> Void

    init(onCancel: @escaping () -> Void) {
        self.onCancel = onCancel
    }

    func cancel() {
        onCancel()
    }
}
#endif
