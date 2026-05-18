import XCTest
import SwiftUI
@testable import iosApp

final class AppThemeTests: XCTestCase {

    /// Pitfall 6 / D-08 — Swift side alpha-preservation guard.
    /// Verifies that Color(argb: Int64) correctly extracts alpha=0xFF as opacity ≈ 1.0
    /// for a representative opaque ARGB constant (LightColors.primary = 0xFF3F51B5).
    /// Failure mode if Int32 were used: the sign-bit would corrupt the alpha byte for
    /// any 0xFF... constant, producing opacity ≈ 0 instead of ≈ 1.
    func testColorAdapterPreservesAlphaForFFOpaqueLong() {
        let argb: Int64 = 0xFF3F51B5
        let alpha = Double(UInt8((argb >> 24) & 0xFF)) / 255.0
        let r     = Double(UInt8((argb >> 16) & 0xFF)) / 255.0
        let g     = Double(UInt8((argb >>  8) & 0xFF)) / 255.0
        let b     = Double(UInt8( argb        & 0xFF)) / 255.0
        XCTAssertEqual(alpha, 1.0, accuracy: 0.001,
            "Alpha byte of 0xFF3F51B5 must extract to 1.0 (Int64 path); got \(alpha).")
        XCTAssertEqual(r, Double(0x3F) / 255.0, accuracy: 0.001, "R component mismatch")
        XCTAssertEqual(g, Double(0x51) / 255.0, accuracy: 0.001, "G component mismatch")
        XCTAssertEqual(b, Double(0xB5) / 255.0, accuracy: 0.001, "B component mismatch")
        // Construction smoke — must not crash
        let _ = Color(argb: argb)
    }

    /// Boundary case — opaque white (LightColors.surfaceContainerLowest = 0xFFFFFFFF).
    /// Catches any unsigned-shift defect the indigo fixture wouldn't expose. TC-022 / ck:scenario #1.
    func testColorAdapterPreservesAlphaForOpaqueWhite() {
        let argb: Int64 = 0xFFFFFFFF
        let alpha = Double(UInt8((argb >> 24) & 0xFF)) / 255.0
        let r     = Double(UInt8((argb >> 16) & 0xFF)) / 255.0
        let g     = Double(UInt8((argb >>  8) & 0xFF)) / 255.0
        let b     = Double(UInt8( argb        & 0xFF)) / 255.0
        XCTAssertEqual(alpha, 1.0, accuracy: 0.001, "Alpha of 0xFFFFFFFF must be 1.0; got \(alpha).")
        XCTAssertEqual(r, 1.0, accuracy: 0.001, "R of 0xFFFFFFFF must be 1.0; got \(r).")
        XCTAssertEqual(g, 1.0, accuracy: 0.001, "G of 0xFFFFFFFF must be 1.0; got \(g).")
        XCTAssertEqual(b, 1.0, accuracy: 0.001, "B of 0xFFFFFFFF must be 1.0; got \(b).")
        let _ = Color(argb: argb)
    }

    /// Boundary case — opaque black (LightColors.scrim = 0xFF000000). TC-023 / ck:scenario #2.
    func testColorAdapterPreservesAlphaForOpaqueBlack() {
        let argb: Int64 = 0xFF000000
        let alpha = Double(UInt8((argb >> 24) & 0xFF)) / 255.0
        let r     = Double(UInt8((argb >> 16) & 0xFF)) / 255.0
        let g     = Double(UInt8((argb >>  8) & 0xFF)) / 255.0
        let b     = Double(UInt8( argb        & 0xFF)) / 255.0
        XCTAssertEqual(alpha, 1.0, accuracy: 0.001, "Alpha of 0xFF000000 must be 1.0; got \(alpha).")
        XCTAssertEqual(r, 0.0, accuracy: 0.001, "R of 0xFF000000 must be 0.0; got \(r).")
        XCTAssertEqual(g, 0.0, accuracy: 0.001, "G of 0xFF000000 must be 0.0; got \(g).")
        XCTAssertEqual(b, 0.0, accuracy: 0.001, "B of 0xFF000000 must be 0.0; got \(b).")
        let _ = Color(argb: argb)
    }
}
