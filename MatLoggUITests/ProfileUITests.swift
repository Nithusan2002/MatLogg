import XCTest

final class ProfileUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    func testMeasurementPickerValidatesInputAndCancelDiscardsDraft() {
        let app = XCUIApplication()
        app.launchArguments.append("--skip-auth")
        app.launch()
        app.buttons["Profil"].tap()
        let details = app.buttons["profile-personal-details"]
        XCTAssertTrue(details.waitForExistence(timeout: 3))
        details.tap()
        XCTAssertTrue(app.navigationBars["Personlige detaljer"].waitForExistence(timeout: 3))
        let weight = app.buttons["personal-details-weight"]
        let original = weight.label
        weight.tap()
        let value = app.textFields["measurement-picker-value"]
        XCTAssertTrue(value.waitForExistence(timeout: 3))
        value.tap()
        value.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: (value.value as? String ?? "").count) + "0")
        app.buttons["measurement-picker-apply"].tap()
        XCTAssertTrue(app.staticTexts["measurement-picker-error"].exists)
        value.tap()
        value.typeText(XCUIKeyboardKey.delete.rawValue + "72,25")
        app.buttons["measurement-picker-apply"].tap()
        XCTAssertTrue(weight.waitForExistence(timeout: 3))
        XCTAssertTrue(weight.label.contains("72,25"))
        app.navigationBars["Personlige detaljer"].buttons["Avbryt"].tap()
        details.tap()
        XCTAssertEqual(app.buttons["personal-details-weight"].label, original)
        app.navigationBars["Personlige detaljer"].buttons["Avbryt"].tap()
    }

    @MainActor
    func testMeasurementRulerAdjustsAndSheetCancelKeepsOriginalValue() {
        let app = XCUIApplication()
        app.launchArguments += ["--skip-auth", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        app.buttons["Profil"].tap()
        app.buttons["profile-personal-details"].tap()
        let height = app.buttons["personal-details-height"]
        for _ in 0..<6 {
            if height.isHittable { break }
            app.swipeUp()
        }
        let original = height.label
        height.tap()
        let ruler = app.otherElements["measurement-picker-ruler"]
        XCTAssertTrue(ruler.waitForExistence(timeout: 3))
        let value = app.textFields["measurement-picker-value"]
        let initialValue = value.value as? String
        ruler.swipeLeft()
        XCTAssertNotEqual(value.value as? String, initialValue)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Høydevelger med stor tekst"
        attachment.lifetime = .keepAlways
        add(attachment)
        app.scrollViews["measurement-picker-sheet"].buttons["Avbryt"].tap()
        XCTAssertTrue(height.waitForExistence(timeout: 3))
        XCTAssertEqual(height.label, original)
    }

    @MainActor
    func testProfileNavigationWithLargeText() {
        let app = XCUIApplication()
        app.launchArguments += ["--skip-auth", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        app.buttons["Profil"].tap()
        let settings = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Innstillinger'")).firstMatch
        for _ in 0..<8 {
            if settings.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(settings.isHittable)
        settings.tap()
        XCTAssertTrue(app.navigationBars["Innstillinger"].waitForExistence(timeout: 3))
        let privacy = app.buttons["Personvern og valg"]
        XCTAssertTrue(privacy.waitForExistence(timeout: 3))
        privacy.tap()
        XCTAssertTrue(app.navigationBars["Personvern og valg"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.navigationBars.buttons["Innstillinger"].exists)
    }
}
