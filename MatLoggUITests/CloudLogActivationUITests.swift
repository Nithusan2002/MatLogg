import XCTest

@MainActor
final class CloudLogActivationUITests: XCTestCase {
    func testSignedInActivationOrdinaryEditAndDeactivation() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--cloud-log-ui-qa", "--enable-cloud-log-sync"]
        app.launch()
        XCTAssertTrue(app.buttons["Profil"].waitForExistence(timeout: 10))
        app.buttons["Profil"].tap()
        reveal(app.buttons["profile-cloud-logs"], in: app)
        app.buttons["profile-cloud-logs"].tap()
        let activate = app.buttons["Aktiver med lokal historikk"]
        reveal(activate, in: app)
        activate.tap()
        XCTAssertTrue(app.alerts["Aktiver matloggsynk?"].waitForExistence(timeout: 3))
        app.alerts.buttons["Avbryt"].tap()
        XCTAssertFalse(app.buttons["Slå av matloggsynk"].exists)
        activate.tap()
        app.alerts.buttons["Bekreft"].tap()
        let deactivate = app.buttons["Slå av matloggsynk"]
        XCTAssertTrue(deactivate.waitForExistence(timeout: 8))
        app.buttons["Hjem"].tap()
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'home-log-row-' AND label CONTAINS 'Synktest eple'")).firstMatch
        reveal(row, in: app)
        row.tap()
        XCTAssertTrue(app.scrollViews["log-editor-scroll"].waitForExistence(timeout: 5))
        let amount = app.textFields["Mengde"]
        XCTAssertTrue(amount.waitForExistence(timeout: 3))
        amount.tap()
        amount.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 10) + "150")
        app.buttons["Lagre endringer"].tap()
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(row.label.contains("150"))
        app.buttons["tab-log-food"].tap()
        app.buttons["Søk etter mat"].tap()
        let search = app.textFields["food-search-field"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("Synktest eple")
        app.buttons["food-search-submit"].tap()
        let result = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'food-search-' AND label CONTAINS 'Synktest eple'")).firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 8))
        result.tap()
        XCTAssertTrue(app.buttons["product-log-save"].waitForExistence(timeout: 5))
        app.buttons["product-log-save"].tap()
        if app.buttons["logging-done"].waitForExistence(timeout: 3) { app.buttons["logging-done"].tap() }
        if app.buttons["log-receipt-close"].exists { app.buttons["log-receipt-close"].tap() }
        reveal(row, in: app)
        row.swipeLeft()
        XCTAssertTrue(app.buttons["Slett"].waitForExistence(timeout: 3))
        app.buttons["Slett"].tap()
        app.buttons["Profil"].tap()
        if !app.staticTexts["Utviklingstest"].exists {
            reveal(app.buttons["profile-cloud-logs"], in: app)
            app.buttons["profile-cloud-logs"].tap()
        }
        reveal(deactivate, in: app)
        deactivate.tap()
        XCTAssertTrue(app.alerts["Slå av matloggsynk?"].waitForExistence(timeout: 3))
        app.alerts.buttons["Bekreft"].tap()
        XCTAssertTrue(activate.waitForExistence(timeout: 5))
        XCTAssertFalse(deactivate.exists)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Kontobundet matloggsynk avslått"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<10 {
            if element.exists && element.isHittable { return }
            app.swipeUp()
        }
        XCTAssertTrue(element.exists && element.isHittable)
    }
}
