import XCTest

@MainActor
final class RepeatFoodUITests: XCTestCase {
    func testRepeatPortionAndUndoKeepsOriginalLog() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--portion-qa", "-ml_local_profile", "", "-ml_local_mode_active", "NO",
                               "-demoModeActive", "NO", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        let skip = app.buttons["first-log-skip"]
        XCTAssertTrue(skip.waitForExistence(timeout: 10))
        skip.tap()
        let breakfast = app.buttons["home-meal-open-frokost"]
        reveal(breakfast, in: app)
        breakfast.tap()
        openSearch(app)
        let field = app.textFields["food-search-field"]
        field.tap()
        field.typeText("Porsjonstestbrød")
        field.typeText("\n")
        let result = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'food-search-result-' AND label CONTAINS 'Porsjonstestbrød'")).firstMatch
        reveal(result, in: app)
        result.tap()
        let save = app.buttons["product-log-save"]
        reveal(save, in: app)
        save.tap()
        let rows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'meal-room-row-' AND label CONTAINS 'Porsjonstestbrød'"))
        let original = rows.firstMatch
        reveal(original, in: app)
        let originalID = original.identifier
        XCTAssertTrue(original.label.contains("1 Polarbrød"))
        openSearch(app)
        // This search presentation focuses the field; submit the empty query to dismiss the keyboard.
        app.textFields["food-search-field"].typeText("\n")
        let recent = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'food-search-recent-' AND label CONTAINS 'Porsjonstestbrød'")).firstMatch
        reveal(recent, in: app)
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'food-search-repeat-'")).firstMatch.exists)
        XCTAssertFalse(app.staticTexts["food-search-repeat-destination"].exists)
        app.buttons["food-search-close"].tap()
        let repeatButton = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'quick-log-repeat-' AND label CONTAINS 'Porsjonstestbrød'")).firstMatch
        reveal(repeatButton, in: app)
        XCTAssertTrue(repeatButton.label.contains("37,5 g"))
        let destination = app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH 'quick-log-repeat-destination-'")).firstMatch
        XCTAssertTrue(destination.exists)
        XCTAssertTrue(destination.label.contains("Frokost"))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Loggfør igjen – hurtigmeny med stor tekst"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        repeatButton.tap()
        let undo = app.buttons["Angre"]
        XCTAssertTrue(undo.waitForExistence(timeout: 5))
        XCTAssertTrue(repeatButton.exists, "Hurtiglogging skal beholde arket åpent.")
        XCTAssertTrue(repeatButton.isHittable)
        repeatButton.tap()
        XCTAssertTrue(undo.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["product-log-save"].exists)
        undo.tap()
        app.buttons["Lukk"].tap()
        reveal(app.buttons[originalID], in: app)
        XCTAssertTrue(app.buttons[originalID].label.contains("1 Polarbrød"))
        XCTAssertEqual(rows.count, 2, "Angre skal bare fjerne siste hurtiglogging og bevare de to tidligere registreringene.")
    }

    private func openSearch(_ app: XCUIApplication) {
        let add = app.buttons["meal-room-add"]
        reveal(add, in: app)
        add.tap()
        app.buttons["Søk etter mat"].tap()
        XCTAssertTrue(app.textFields["food-search-field"].waitForExistence(timeout: 8))
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        _ = element.waitForExistence(timeout: 8)
        for _ in 0..<12 {
            if element.exists && element.isHittable { return }
            app.swipeUp()
        }
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Gjenlogging – utilgjengelig kontroll"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        print(app.debugDescription)
        XCTAssertTrue(element.exists && element.isHittable, "Kontrollen skal kunne nås med stor tekst.")
    }
}
