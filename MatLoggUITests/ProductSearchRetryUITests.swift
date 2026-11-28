import XCTest

final class ProductSearchRetryUITests: XCTestCase {
    private let slowMessage = "Søket tar litt tid. Vi prøver fortsatt …"
    private let failureMessage = "Kunne ikke hente nye treff akkurat nå. Du kan fortsatt bruke lagrede matvarer."

    @MainActor
    func testTemporaryServerFailuresRecoverWithoutManualRetry() {
        verifyRecovery(largeText: false)
    }

    @MainActor
    func testRecoveryWithLargestText() {
        verifyRecovery(largeText: true)
    }

    @MainActor
    func testPersistentFailureKeepsLocalMatchesAndOffersRetry() {
        let app = launch(mode: "unavailable")
        submit(app)
        XCTAssertTrue(app.staticTexts[slowMessage].waitForExistence(timeout: 5))
        screenshot(app, name: "Søk QA – automatisk retry")
        XCTAssertTrue(app.staticTexts[failureMessage].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["Prøv igjen"].isHittable)
        XCTAssertTrue(localRow(app).exists)
        screenshot(app, name: "Søk QA – feil med lokale treff")
        app.buttons["Prøv igjen"].tap()
        XCTAssertTrue(app.staticTexts[slowMessage].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts[failureMessage].waitForExistence(timeout: 8))
    }

    @MainActor
    func testDeadlineStopsHangingSearch() {
        let app = launch(mode: "timeout")
        let start = Date()
        submit(app)
        XCTAssertTrue(app.staticTexts[slowMessage].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Prøv igjen"].waitForExistence(timeout: 16))
        XCTAssertLessThan(Date().timeIntervalSince(start), 20, "15s network budget plus UI observation overhead")
        XCTAssertTrue(localRow(app).exists)
        screenshot(app, name: "Søk QA – tidsgrense")
    }

    @MainActor
    func testChangingQueryDiscardsPendingSearch() {
        let app = launch(mode: "unavailable")
        submit(app)
        XCTAssertTrue(app.staticTexts[slowMessage].waitForExistence(timeout: 5))
        app.buttons["Tøm søket"].tap()
        let field = app.textFields["food-search-field"]
        field.tap()
        field.typeText("banan")
        hideKeyboard(app)
        let banana = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'food-search-' AND label CONTAINS[c] 'Banan'")).firstMatch
        XCTAssertTrue(banana.waitForExistence(timeout: 5))
        let unexpected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true"), object: app.buttons["Prøv igjen"])
        unexpected.isInverted = true
        wait(for: [unexpected], timeout: 5)
        XCTAssertFalse(app.staticTexts[slowMessage].exists)
        screenshot(app, name: "Søk QA – nytt søkeord")
    }

    @MainActor
    func testLeavingSearchCancelsPendingRetry() {
        let app = launch(mode: "unavailable")
        submit(app)
        XCTAssertTrue(app.staticTexts[slowMessage].waitForExistence(timeout: 5))
        app.buttons["Hjem"].tap()
        let unexpected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true"), object: app.staticTexts[failureMessage])
        unexpected.isInverted = true
        wait(for: [unexpected], timeout: 5)
        app.buttons["Søk"].tap()
        XCTAssertTrue(app.textFields["food-search-field"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts[failureMessage].exists)
        XCTAssertFalse(app.staticTexts[slowMessage].exists)
    }

    @MainActor
    private func verifyRecovery(largeText: Bool) {
        let app = launch(mode: "recover", largeText: largeText)
        submit(app)
        XCTAssertTrue(app.staticTexts[slowMessage].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["food-search-submit"].isEnabled)
        screenshot(app, name: largeText ? "Søk QA – retry største tekst" : "Søk QA – retry normal tekst")
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: app.buttons["food-search-submit"])
        wait(for: [ready], timeout: 8)
        let remote = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'food-search-' AND label CONTAINS 'Havregryn nettvare QA'")).firstMatch
        for _ in 0..<5 {
            if remote.waitForExistence(timeout: 2) { break }
            app.swipeUp()
        }
        XCTAssertTrue(remote.exists)
        XCTAssertFalse(app.buttons["Prøv igjen"].exists)
        XCTAssertFalse(app.staticTexts[slowMessage].exists)
        screenshot(app, name: largeText ? "Søk QA – treff største tekst" : "Søk QA – treff etter retry")
    }

    @MainActor
    private func launch(mode: String, largeText: Bool = false) -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["--skip-auth", "--product-search-retry-qa", "-demoModeActive", "NO"]
        if largeText {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launchEnvironment["MATLOGG_SEARCH_RETRY_QA"] = mode
        app.launch()
        XCTAssertTrue(app.buttons["Søk"].waitForExistence(timeout: 10))
        app.buttons["Søk"].tap()
        let field = app.textFields["food-search-field"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        if app.buttons["Tøm søket"].exists { app.buttons["Tøm søket"].tap() }
        field.tap()
        field.typeText("havregryn")
        hideKeyboard(app)
        return app
    }

    @MainActor
    private func submit(_ app: XCUIApplication) {
        let button = app.buttons["food-search-submit"]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        XCTAssertTrue(button.isEnabled)
        button.tap()
    }

    @MainActor
    private func localRow(_ app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'food-search-' AND label CONTAINS[c] 'Havregryn' AND label CONTAINS 'Matvaretabellen'")).firstMatch
    }

    @MainActor
    private func hideKeyboard(_ app: XCUIApplication) {
        if app.buttons["Skjul tastatur"].exists { app.buttons["Skjul tastatur"].tap() }
        else if app.buttons["Ferdig"].exists { app.buttons["Ferdig"].tap() }
    }

    @MainActor
    private func screenshot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
