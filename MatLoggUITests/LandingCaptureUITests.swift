import XCTest

/// Explicitly selected presentation capture; never touches the normal profile.
final class LandingCaptureUITests: XCTestCase {
    @MainActor
    func testCaptureLandingScreens() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["MATLOGG_LANDING_CAPTURE"] == "1",
                          "Presentation capture must be explicitly enabled on a dedicated simulator.")
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-demoModeActive", "YES", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
        app.launch()
        XCTAssertTrue(app.buttons["Hjem"].firstMatch.waitForExistence(timeout: 30))
        app.buttons["Profil"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Tilbakestill demodata"].waitForExistence(timeout: 10))
        app.buttons["Tilbakestill demodata"].tap()
        app.buttons["Tilbakestill"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Hjem"].firstMatch.waitForExistence(timeout: 20))
        app.buttons["Hjem"].firstMatch.tap()
        capture("home", app)

        app.buttons["Søk"].firstMatch.tap()
        XCTAssertTrue(app.buttons["food-search-saved-meals"].waitForExistence(timeout: 10))
        capture("search", app)
        app.buttons["food-search-saved-meals"].tap()
        XCTAssertTrue(app.staticTexts["Yoghurt med havre og bær"].firstMatch.waitForExistence(timeout: 10))
        capture("meals", app)
        app.buttons["Lukk"].firstMatch.tap()
        app.buttons["Hjem"].firstMatch.tap()
        app.buttons["Utvikling"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Kalorier gjennom uka"].waitForExistence(timeout: 10))
        capture("overview", app)

        app.buttons["Hjem"].firstMatch.tap()
        let breakfast = app.buttons["home-meal-open-frokost"]
        XCTAssertTrue(breakfast.waitForExistence(timeout: 10))
        for _ in 0..<5 {
            if breakfast.isHittable { break }
            app.swipeUp()
        }
        breakfast.tap()
        XCTAssertTrue(app.staticTexts["meal-room-heading-frokost"].waitForExistence(timeout: 10))
        app.buttons["tab-log-food"].tap()
        app.buttons["Søk etter mat"].tap()
        let search = app.textFields["food-search-field"]
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        search.tap()
        search.typeText("lettkokte havregryn")
        if app.buttons["Continue"].waitForExistence(timeout: 2) { app.buttons["Continue"].tap() }
        let oats = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'havregryn' AND label CONTAINS 'Open Food Facts'")).firstMatch
        XCTAssertTrue(oats.waitForExistence(timeout: 10))
        let searchResults = app.collectionViews.firstMatch
        searchResults.swipeUp()
        searchResults.swipeDown()
        XCTAssertFalse(app.keyboards.firstMatch.exists)
        capture("flow-search", app)
        oats.tap()
        XCTAssertTrue(app.buttons["product-log-save"].waitForExistence(timeout: 10))
        let amount = app.textFields["Mengde"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        amount.tap()
        amount.typeText("60")
        app.buttons["product-log-save"].tap()
        let loggedOats = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'meal-room-row-' AND label CONTAINS[c] 'Lettkokte havregryn'")).firstMatch
        XCTAssertTrue(loggedOats.waitForExistence(timeout: 10))
        capture("flow-log", app)
        let closeReceipt = app.buttons["Lukk bekreftelse"]
        XCTAssertTrue(closeReceipt.waitForExistence(timeout: 5))
        closeReceipt.tap()
        XCTAssertFalse(closeReceipt.exists)
        capture("diary", app)

        // Reopen the remembered 60 g amount without focusing the input field.
        // This captures the same selection with no keyboard and adds no second log.
        app.buttons["tab-log-food"].tap()
        app.buttons["Søk etter mat"].tap()
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        search.tap()
        search.typeText("lettkokte havregryn")
        XCTAssertTrue(oats.waitForExistence(timeout: 10))
        oats.tap()
        XCTAssertTrue(app.buttons["product-log-save"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["product-log-save"].label.contains("60 g"))
        XCTAssertFalse(app.keyboards.firstMatch.exists)
        capture("flow-amount", app)

    }

    @MainActor
    private func capture(_ name: String, _ app: XCUIApplication) {
        XCTAssertFalse(app.keyboards.firstMatch.exists, "Presentation screenshots must not include the keyboard.")
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "landing-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
