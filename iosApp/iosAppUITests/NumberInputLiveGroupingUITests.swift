import XCTest

/// Drives the iosApp through Login → Dashboard → NumberInput Showcase, then types
/// digits into each locale field and asserts the displayed text is live-grouped.
/// Also exercises the device-locale-vs-field-locale decimal-separator substitution:
/// on an en-US device the .decimalPad keyboard only offers ".", but vi-VN/de-DE fields
/// must still accept it as their "," decimal.
final class NumberInputLiveGroupingUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLiveGroupingAllLocales() throws {
        let app = XCUIApplication()
        app.launch()

        // 1. Login.
        let email = app.textFields["Email"]
        XCTAssertTrue(email.waitForExistence(timeout: 5), "Email field not visible")
        email.tap()
        email.typeText("test@example.com")

        let password = app.secureTextFields["Password"]
        password.tap()
        password.typeText("password")

        app.buttons["Sign in"].tap()

        // 2. Dashboard → Number Input Showcase.
        let showcaseLink = app.buttons["Number Input Showcase"]
        XCTAssertTrue(showcaseLink.waitForExistence(timeout: 5), "Dashboard nav link missing")
        showcaseLink.tap()

        let fields = app.textFields.matching(identifier: "numberInput.field")
        XCTAssertEqual(fields.count, 4, "Expected 4 NumberInput fields in showcase")

        // 3a. en-US integer progression + decimal.
        try driveField(field: fields.element(boundBy: 0), label: "en-US",
                       groupSep: ",", decSep: ".")

        // 3b. vi-VN: user types "." on en-US keyboard, field substitutes it to ",".
        // Need to dismiss the keyboard between fields to switch focus.
        app.buttons["numberInput.toolbar.done"].firstMatch.tap()
        try driveField(field: fields.element(boundBy: 1), label: "vi-VN",
                       groupSep: ".", decSep: ",")

        // 3c. de-DE: same rules as vi-VN.
        app.buttons["numberInput.toolbar.done"].firstMatch.tap()
        try driveField(field: fields.element(boundBy: 2), label: "de-DE",
                       groupSep: ".", decSep: ",")

        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "all-locales-final"
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func driveField(field: XCUIElement, label: String, groupSep: String, decSep: String) throws {
        let app = XCUIApplication()
        XCTAssertTrue(field.waitForExistence(timeout: 3), "\(label): field not visible")
        field.tap()

        // Clear any pre-filled value via deletes.
        let backspace = XCUIKeyboardKey.delete.rawValue
        for _ in 0..<14 { field.typeText(backspace) }

        // Integer progression: 1, 10, 100, 1<groupSep>000, 10<groupSep>009, ...
        let progression: [(typed: String, expected: String)] = [
            ("1", "1"),
            ("0", "10"),
            ("0", "100"),
            ("0", "1\(groupSep)000"),
            ("9", "10\(groupSep)009"),
            ("0", "100\(groupSep)090"),
            ("0", "1\(groupSep)000\(groupSep)900"),
        ]
        for step in progression {
            field.typeText(step.typed)
            let actual = field.value as? String ?? ""
            XCTAssertEqual(actual, step.expected,
                           "\(label): after typing \"\(step.typed)\" expected \"\(step.expected)\" got \"\(actual)\"")
        }

        // Decimal: type "." on the en-US device keyboard. The field MUST substitute to its
        // own decimal separator (",") for vi-VN/de-DE. For en-US, no substitution needed.
        field.typeText(".")
        let afterDot = field.value as? String ?? ""
        XCTAssertEqual(afterDot, "1\(groupSep)000\(groupSep)900\(decSep)",
                       "\(label): after typing \".\" expected \"1\(groupSep)000\(groupSep)900\(decSep)\" got \"\(afterDot)\"")

        field.typeText("5")
        let afterFraction = field.value as? String ?? ""
        XCTAssertEqual(afterFraction, "1\(groupSep)000\(groupSep)900\(decSep)5",
                       "\(label): after typing \"5\" expected \"1\(groupSep)000\(groupSep)900\(decSep)5\" got \"\(afterFraction)\"")

        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "\(label)-after-decimal"
        shot.lifetime = .keepAlways
        add(shot)
    }
}
