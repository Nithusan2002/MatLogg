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
        toggle.tap()
        XCTAssertEqual(toggle.value as? String, "1")
        let moveUp = app.buttons["Flytt Treningsøkter opp"]
        for _ in 0..<3 {
            makeVisible(moveUp, in: app)
            moveUp.tap()
        }
        app.buttons["progress-hub-save"].tap()

        let card = app.buttons["progress-hub-workouts-open"]
        makeVisible(card, in: app)
        XCTAssertGreaterThan(card.frame.width, app.frame.width * 0.8)
        card.tap()
        let back = app.navigationBars["Treningsøkter"].buttons.element(boundBy: 0)
        let shortcut = app.buttons["apple-health-settings-shortcut"]
        XCTAssertTrue(shortcut.waitForExistence(timeout: 5))
        shortcut.tap()
        app.setAppleHealthToggle("apple-health-workouts-toggle", enabled: true)
        app.buttons["apple-health-settings-done"].tap()

        XCTAssertTrue(app.staticTexts["Apple Helse"].waitForExistence(timeout: 5))
        let rows = app.descendants(matching: .any).matching(identifier: "workout-row")
        XCTAssertTrue(rows.containing(NSPredicate(format: "label CONTAINS 'Løping'")).firstMatch.waitForExistence(timeout: 5))
        back.tap()
        XCTAssertTrue(card.label.contains("3 økter"))
        XCTAssertTrue(card.label.contains("Styrke"))
        XCTAssertTrue(card.label.contains("Gåtur"))
        XCTAssertFalse(card.label.contains("Løping"))

        app.buttons["progress-period-day"].tap()
        expectCard(card, contains: "3 økter")
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
        expectCard(card, contains: "Koble til i Innstillinger")
        XCTAssertFalse(card.label.contains("Styrke"))
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
