#if canImport(UIKit)
import SwiftUI
import UIKit
import XCTest
@testable import NumberInputKit

@MainActor
final class NumberInputDynamicTypeTests: XCTestCase {

    func testDefaultAndConsumerSizesScaleThroughAccessibilityTwo() {
        let defaultRegular = NumberInputDynamicType.pointSize(
            baseSize: 22,
            relativeTo: .title2,
            dynamicTypeSize: .large
        )
        let defaultAccessible = NumberInputDynamicType.pointSize(
            baseSize: 22,
            relativeTo: .title2,
            dynamicTypeSize: .accessibility2
        )
        let consumerRegular = NumberInputDynamicType.pointSize(
            baseSize: 26,
            relativeTo: .title2,
            dynamicTypeSize: .large
        )
        let consumerAccessible = NumberInputDynamicType.pointSize(
            baseSize: 26,
            relativeTo: .title2,
            dynamicTypeSize: .accessibility2
        )

        XCTAssertGreaterThan(defaultAccessible, defaultRegular)
        XCTAssertGreaterThan(consumerAccessible, consumerRegular)
        XCTAssertEqual(defaultRegular, 22, accuracy: 0.01)
        XCTAssertEqual(consumerRegular, 26, accuracy: 0.01)
    }

    func testScalingCapsBeyondSupportedKeyboardGeometry() {
        let supportedMaximum = NumberInputDynamicType.pointSize(
            baseSize: 24,
            relativeTo: .title2,
            dynamicTypeSize: .accessibility2
        )
        let largerPreference = NumberInputDynamicType.pointSize(
            baseSize: 24,
            relativeTo: .title2,
            dynamicTypeSize: .accessibility5
        )

        XCTAssertEqual(largerPreference, supportedMaximum, accuracy: 0.01)
    }

    func testMountedConsumerKeyScalesWithoutClippingAndKeepsHitTarget() {
        let regular = renderKey(dynamicTypeSize: .large)
        let accessible = renderKey(dynamicTypeSize: .accessibility2)

        XCTAssertEqual(regular.viewSize.height, 52, accuracy: 0.5)
        XCTAssertEqual(accessible.viewSize.height, 52, accuracy: 0.5)
        XCTAssertGreaterThanOrEqual(accessible.viewSize.height, 44)
        XCTAssertGreaterThan(accessible.inkBounds.height, regular.inkBounds.height)
        XCTAssertGreaterThanOrEqual(accessible.inkBounds.minY, 0)
        XCTAssertLessThanOrEqual(accessible.inkBounds.maxY, accessible.viewSize.height)
    }

    func testMountedFiveActionToolbarFitsAtAccessibilityTwoWithoutOverlap() {
        let action = NumberInputToolbarActionStyle(
            height: 32,
            horizontalPadding: 12,
            verticalPadding: 0
        )
        let style = NumberInputStyle(
            toolbar: NumberInputToolbarStyle(
                height: 44,
                contentPadding: 8,
                itemSpacing: 6,
                labelTextSize: 13,
                action: action,
                done: NumberInputToolbarActionStyle(
                    height: 32,
                    horizontalPadding: 18,
                    verticalPadding: 0
                ),
                navigation: action
            )
        )
        let state = NumberInputState(
            formatter: FakeLocaleNumberFormatter(),
            initialValue: 12,
            config: NumberInputConfig(allowNegative: true, useBuiltInKeypad: true)
        )
        let toolbar = NumberInputToolbarRow(
            state: state,
            style: style,
            leadingAccessory: nil,
            onPrevious: {},
            onNext: {},
            availableWidth: 390,
            onDone: {}
        )
        .environment(\.dynamicTypeSize, .accessibility2)

        let host = UIHostingController(rootView: toolbar)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 100))
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.frame = window.bounds
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        waitUntil("five toolbar actions mount") {
            self.toolbarButtons(in: host.view).count == 5
        }

        let buttons = allButtons(in: host.view)
            .filter { $0.accessibilityIdentifier?.hasPrefix("numberInput.toolbar.") == true }
        let frames = buttons.map { $0.convert($0.bounds, to: host.view) }

        XCTAssertEqual(buttons.count, 5)
        for frame in frames {
            XCTAssertGreaterThan(frame.width, 0)
            XCTAssertGreaterThanOrEqual(frame.minX, host.view.bounds.minX)
            XCTAssertLessThanOrEqual(frame.maxX, host.view.bounds.maxX)
        }
        for first in frames.indices {
            for second in frames.indices where second > first {
                XCTAssertFalse(
                    frames[first].intersects(frames[second]),
                    "Toolbar frames overlap: \(frames[first]) and \(frames[second])"
                )
            }
        }

        window.isHidden = true
        window.rootViewController = nil
    }

    func testFiveActionToolbarWithLeadingAccessoryKeepsDoneLabelUnclippedAt390Points() throws {
        let action = NumberInputToolbarActionStyle(
            height: 32,
            horizontalPadding: 12,
            verticalPadding: 0
        )
        let style = NumberInputStyle(
            toolbar: NumberInputToolbarStyle(
                height: 44,
                contentPadding: 8,
                itemSpacing: 6,
                labelTextSize: 13,
                labelFontWeight: .semibold,
                action: action,
                done: NumberInputToolbarActionStyle(
                    height: 32,
                    horizontalPadding: 18,
                    verticalPadding: 0
                ),
                navigation: action
            )
        )
        let state = NumberInputState(
            formatter: FakeLocaleNumberFormatter(),
            initialValue: 12,
            config: NumberInputConfig(allowNegative: true, useBuiltInKeypad: true)
        )
        let toolbar = NumberInputToolbarRow(
            state: state,
            style: style,
            leadingAccessory: AnyView(Color.clear.frame(width: 38, height: 20)),
            onPrevious: {},
            onNext: {},
            availableWidth: 390,
            onDone: {}
        )

        let host = UIHostingController(rootView: toolbar)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 100))
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.frame = window.bounds
        host.view.layoutIfNeeded()
        waitUntil("five toolbar actions mount") {
            self.toolbarButtons(in: host.view).count == 5
        }

        let buttons = allButtons(in: host.view)
            .filter { $0.accessibilityIdentifier?.hasPrefix("numberInput.toolbar.") == true }
        let frames = buttons.map { $0.convert($0.bounds, to: host.view) }
        let done = try XCTUnwrap(
            buttons.first { $0.accessibilityIdentifier == NumberInputTags.toolbarDone }
        )
        let expectedDoneWidth = ceil(
            (style.toolbar.doneLabel as NSString).size(withAttributes: [
                .font: UIFont.systemFont(ofSize: style.toolbar.labelTextSize, weight: .semibold)
            ]).width + 2 * style.toolbar.done.horizontalPadding
        )

        XCTAssertEqual(buttons.count, 5)
        XCTAssertGreaterThanOrEqual(done.bounds.width, expectedDoneWidth)
        for frame in frames {
            XCTAssertGreaterThan(frame.width, 0)
            XCTAssertGreaterThanOrEqual(frame.minX, host.view.bounds.minX)
            XCTAssertLessThanOrEqual(frame.maxX, host.view.bounds.maxX)
        }
        for first in frames.indices {
            for second in frames.indices where second > first {
                XCTAssertFalse(
                    frames[first].intersects(frames[second]),
                    "Compact toolbar frames overlap: \(frames[first]) and \(frames[second])"
                )
            }
        }

        window.isHidden = true
        window.rootViewController = nil
    }

    func testFiveActionToolbarFitsAt320PointsAtAccessibilityTwo() {
        let action = NumberInputToolbarActionStyle(
            height: 32,
            horizontalPadding: 12,
            verticalPadding: 0
        )
        let style = NumberInputStyle(
            toolbar: NumberInputToolbarStyle(
                height: 44,
                contentPadding: 8,
                itemSpacing: 6,
                labelTextSize: 13,
                labelFontWeight: .semibold,
                action: action,
                done: NumberInputToolbarActionStyle(
                    height: 32,
                    horizontalPadding: 18,
                    verticalPadding: 0
                ),
                navigation: action
            )
        )
        let state = NumberInputState(
            formatter: FakeLocaleNumberFormatter(),
            initialValue: 12,
            config: NumberInputConfig(allowNegative: true, useBuiltInKeypad: true)
        )
        let toolbar = NumberInputToolbarRow(
            state: state,
            style: style,
            leadingAccessory: AnyView(Color.clear.frame(width: 38, height: 20)),
            onPrevious: {},
            onNext: {},
            availableWidth: 320,
            onDone: {}
        )
        .environment(\.dynamicTypeSize, .accessibility2)

        let host = UIHostingController(rootView: toolbar)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 100))
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.frame = window.bounds
        host.view.layoutIfNeeded()
        waitUntil("compact toolbar actions mount") {
            self.toolbarButtons(in: host.view).count == 5
        }

        let frames = toolbarButtons(in: host.view).map { $0.convert($0.bounds, to: host.view) }
        XCTAssertEqual(frames.count, 5)
        for frame in frames {
            XCTAssertGreaterThanOrEqual(frame.width, 44 - 0.001)
            XCTAssertGreaterThanOrEqual(frame.height, 44 - 0.001)
            XCTAssertGreaterThanOrEqual(frame.minX, host.view.bounds.minX)
            XCTAssertLessThanOrEqual(frame.maxX, host.view.bounds.maxX)
        }
        for first in frames.indices {
            for second in frames.indices where second > first {
                XCTAssertFalse(
                    frames[first].intersects(frames[second]),
                    "Compact toolbar frames overlap: \(frames[first]) and \(frames[second])"
                )
            }
        }

        window.isHidden = true
        window.rootViewController = nil
    }

    private func renderKey(dynamicTypeSize: DynamicTypeSize) -> RenderedKey {
        let keyStyle = NumberInputKeyStyle(
            backgroundColor: .white,
            contentColor: .black,
            textSize: 24,
            fontWeight: .medium
        )
        let style = NumberInputStyle(
            keypad: NumberInputKeypadStyle(
                keyHeight: 52,
                fontName: "AvenirNext-Regular",
                restKey: keyStyle
            )
        )
        let key = NumberInputKey(
            label: "8",
            enabled: true,
            role: keyStyle,
            style: style,
            hapticsEnabled: false,
            identifier: "dynamic-type-key",
            contentDescription: "8",
            action: {}
        )
        .environment(\.dynamicTypeSize, dynamicTypeSize)
        .frame(width: 120)

        let host = UIHostingController(rootView: key)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 120, height: 52))
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.frame = CGRect(x: 0, y: 0, width: 120, height: 52)
        host.view.backgroundColor = .white
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        waitForNextMainTurn()

        let result = RenderedKey(
            viewSize: host.view.bounds.size,
            inkBounds: darkPixelBounds(in: host.view)
        )
        window.isHidden = true
        window.rootViewController = nil
        return result
    }

    private func darkPixelBounds(in view: UIView) -> CGRect {
        let width = Int(view.bounds.width)
        let height = Int(view.bounds.height)
        var pixels = [UInt8](repeating: 255, count: width * height * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            XCTFail("Could not create rendered-key bitmap")
            return .zero
        }
        context.setFillColor(UIColor.white.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        view.layer.render(in: context)

        var minimumX = width
        var minimumY = height
        var maximumX = -1
        var maximumY = -1
        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * width + x) * 4
                let red = Int(pixels[offset])
                let green = Int(pixels[offset + 1])
                let blue = Int(pixels[offset + 2])
                if red < 180 || green < 180 || blue < 180 {
                    minimumX = min(minimumX, x)
                    minimumY = min(minimumY, y)
                    maximumX = max(maximumX, x)
                    maximumY = max(maximumY, y)
                }
            }
        }
        guard maximumX >= minimumX, maximumY >= minimumY else {
            XCTFail("Rendered key had no visible glyph")
            return .zero
        }
        return CGRect(
            x: minimumX,
            y: minimumY,
            width: maximumX - minimumX + 1,
            height: maximumY - minimumY + 1
        )
    }

    private func allButtons(in view: UIView) -> [UIButton] {
        var buttons = view.subviews.flatMap(allButtons(in:))
        if let button = view as? UIButton { buttons.append(button) }
        return buttons
    }

    private func toolbarButtons(in view: UIView) -> [UIButton] {
        allButtons(in: view).filter {
            $0.accessibilityIdentifier?.hasPrefix("numberInput.toolbar.") == true
        }
    }

    private func waitForNextMainTurn() {
        var completed = false
        DispatchQueue.main.async { completed = true }
        waitUntil("next main run-loop turn") { completed }
    }

    private func waitUntil(
        _ description: String,
        timeout: TimeInterval = 1,
        condition: () -> Bool
    ) {
        let deadline = Date(timeIntervalSinceNow: timeout)
        while !condition(), Date() < deadline {
            _ = RunLoop.main.run(mode: .default, before: Date(timeIntervalSinceNow: 0.01))
        }
        XCTAssertTrue(condition(), "Timed out waiting for \(description)")
    }
}

private struct RenderedKey {
    let viewSize: CGSize
    let inkBounds: CGRect
}
#endif
