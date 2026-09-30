import XCTest

final class ProfileUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    func testPersonalDetailsInvalidInputStaysOnScreenAndCancelDiscardsDraft() {
        let app = XCUIApplication()
        app.launchArguments.append("--skip-auth")
        app.launch()
        app.buttons["Profil"].tap()
        let details = app.buttons["profile-personal-details"]
        XCTAssertTrue(details.waitForExistence(timeout: 3))
        details.tap()
        XCTAssertTrue(app.navigationBars["Personlige detaljer"].waitForExistence(timeout: 3))
        let weight = app.textFields["personal-details-weight"]
        let original = weight.value as? String ?? ""
        weight.tap()
        // A placeholder is not text to erase.
        let count = original == "Valgfritt" ? 0 : original.count
        weight.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: count) + "0")
        app.buttons["personal-details-save"].tap()
        XCTAssertTrue(app.navigationBars["Personlige detaljer"].exists)
        XCTAssertTrue(app.staticTexts["Skriv et gyldig tall over 0 kg, eller la feltet stå tomt."].exists)
        app.navigationBars["Personlige detaljer"].buttons["Avbryt"].tap()
        details.tap()
        XCTAssertEqual(app.textFields["personal-details-weight"].value as? String, original)
        app.navigationBars["Personlige detaljer"].buttons["Avbryt"].tap()
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
