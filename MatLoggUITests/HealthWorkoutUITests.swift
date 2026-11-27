import XCTest

final class HealthWorkoutUITests: XCTestCase {
    @MainActor
    func testWorkoutCardShowsSelectedPeriodAndClearsAfterDisconnect() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-demoModeActive", "YES", "--health-workouts-qa",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
        app.launch()
        app.openAppleHealthSettings()
        app.setAppleHealthToggle("apple-health-workouts-toggle", enabled: false)

        openHub(app)
        app.buttons["progress-hub-customize"].tap()
        let restore = app.buttons["Gjenopprett standard"]
        makeVisible(restore, in: app)
        restore.tap()
        let toggle = app.switches["progress-hub-toggle-workouts"]
        makeVisible(toggle, in: app)
        XCTAssertEqual(toggle.value as? String, "0")
        app.setToggle(toggle, enabled: true)
        app.buttons["progress-hub-save"].tap()

        let card = app.buttons["progress-hub-workouts-open"]
        makeVisible(card, in: app)
        XCTAssertGreaterThan(card.frame.width, app.frame.width * 0.8)
        card.tap()
        let back = app.navigationBars["Treningsøkter"].buttons.element(boundBy: 0)
        let shortcut = app.buttons["apple-health-settings-shortcut"]
        XCTAssertTrue(shortcut.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Slå på under Profil → Innstillinger → Apple Helse."].exists)
        shortcut.tap()
        app.setAppleHealthToggle("apple-health-workouts-toggle", enabled: true)
        app.buttons["apple-health-settings-done"].tap()

        XCTAssertTrue(app.staticTexts["Apple Helse"].waitForExistence(timeout: 5))
        let rows = app.descendants(matching: .any).matching(identifier: "workout-row")
        XCTAssertTrue(rows.containing(NSPredicate(format: "label CONTAINS 'Løping'")).firstMatch.waitForExistence(timeout: 5))
        let walk = rows.containing(NSPredicate(format: "label CONTAINS 'Gåtur'")).firstMatch
        XCTAssertTrue(walk.label.contains("1 t 8 min"))
        XCTAssertTrue(walk.label.contains(":"))
        capture("Treningsøkter – detaljer", app)
        back.tap()
        expectCard(card, contains: "3 økter")
        XCTAssertTrue(card.label.contains("Styrke"))
        XCTAssertTrue(card.label.contains("Gåtur"))
        XCTAssertTrue(card.label.contains("Løping"))
        capture("Treningsøkter – ukeoversikt", app)

        app.buttons["progress-period-day"].tap()
        expectCard(card, contains: "3 økter")
        let today = Date().formatted(.dateTime.day().month(.abbreviated).locale(Locale(identifier: "nb_NO")))
        XCTAssertTrue(card.label.contains(today))
        XCTAssertTrue(card.label.contains("45 min"))
        XCTAssertTrue(card.label.contains("1 t 8 min"))
        XCTAssertFalse(card.label.contains("Løping"))
        app.buttons["progress-period-month"].tap()
        expectCard(card, contains: "Styrke")
        app.buttons["progress-period-week"].tap()
        app.buttons["progress-period-previous"].tap()
        expectCard(card, contains: "Sykling")
        XCTAssertTrue(card.label.contains("1 økt"))
        app.buttons["progress-period-previous"].tap()
        expectCard(card, contains: "Ingen treningsøkter tilgjengelig i perioden")

        app.openAppleHealthSettings()
        app.setAppleHealthToggle("apple-health-workouts-toggle", enabled: false)
        openHub(app)
        expectCard(card, contains: "Slå på i innstillingene i Spor Mat")
        XCTAssertFalse(card.label.contains("Styrke"))
    }

    @MainActor private func capture(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor private func makeVisible(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<5 {
            if element.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable)
    }

    @MainActor private func expectCard(_ card: XCUIElement, contains text: String) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS %@", text), object: card)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 5), .completed)
    }

    @MainActor private func openHub(_ app: XCUIApplication) {
        XCTAssertTrue(app.buttons["Utvikling"].firstMatch.waitForExistence(timeout: 30))
        app.buttons["Utvikling"].firstMatch.tap()
        XCTAssertTrue(app.buttons["progress-hub-customize"].waitForExistence(timeout: 10))
    }
}
