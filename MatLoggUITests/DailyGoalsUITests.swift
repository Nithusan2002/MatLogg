import XCTest

final class DailyGoalsUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    private func openGoals(_ app: XCUIApplication) {
        let profile = app.buttons.matching(NSPredicate(format: "label == 'Profil' AND identifier != 'person.crop.circle'")).firstMatch
        XCTAssertTrue(profile.waitForExistence(timeout: 5))
        profile.tap()
        let goals = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Daglige mål'")).firstMatch
        for _ in 0..<8 {
            if goals.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(goals.waitForExistence(timeout: 3))
        goals.tap()
        XCTAssertTrue(app.navigationBars["Daglige mål"].waitForExistence(timeout: 3))
    }

    @MainActor
    private func replace(_ field: XCUIElement, with value: String) {
        field.tap()
        let old = field.value as? String ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: old.count) + value)
    }

    @MainActor
    private func save(_ app: XCUIApplication) {
        if app.buttons["Ferdig"].exists { app.buttons["Ferdig"].tap() }
        let save = app.buttons["daily-goals-save"]
        if !save.isHittable { app.swipeUp() }
        save.tap()
        XCTAssertTrue(app.alerts["Målene er lagret på enheten"].waitForExistence(timeout: 3))
        app.alerts.buttons["Ferdig"].tap()
    }

    @MainActor
    func testEditSaveAndRelaunchPreservesCustomMacros() {
        let app = XCUIApplication()
        app.launch()
        openGoals(app)
        let protein = app.textFields["daily-goals-protein"]
        XCTAssertTrue(protein.waitForExistence(timeout: 3))
        let originalProtein = protein.value as! String
        let originalCarbs = app.textFields["daily-goals-carbs"].value as! String
        let originalCalories = app.textFields["daily-goals-calories"].value as! String
        replace(protein, with: "137,25")
        save(app)
        app.terminate()
        app.launch()
        openGoals(app)
        XCTAssertEqual(app.textFields["daily-goals-protein"].value as? String, "137,25")
        XCTAssertEqual(app.textFields["daily-goals-carbs"].value as? String, originalCarbs)
        XCTAssertEqual(app.textFields["daily-goals-calories"].value as? String, originalCalories)
        replace(app.textFields["daily-goals-protein"], with: originalProtein)
        save(app)
    }

    @MainActor
    func testInvalidInputAndCancelDoNotChangeSavedGoal() {
        let app = XCUIApplication()
        app.launch()
        openGoals(app)
        let calories = app.textFields["daily-goals-calories"]
        let original = calories.value as! String
        replace(calories, with: "9999")
        app.buttons["Ferdig"].tap()
        app.swipeUp()
        app.buttons["daily-goals-save"].tap()
        app.swipeDown()
        XCTAssertTrue(app.staticTexts["Skriv et heltall mellom 1200 og 4500 kcal."].exists)
        app.navigationBars["Daglige mål"].buttons["Avbryt"].tap()
        openGoals(app)
        XCTAssertEqual(app.textFields["daily-goals-calories"].value as? String, original)
        app.navigationBars["Daglige mål"].buttons["Avbryt"].tap()
    }

    @MainActor
    func testSuggestionMustBeAppliedAndSavedExplicitly() {
        let app = XCUIApplication()
        app.launch()
        openGoals(app)
        let original = app.textFields["daily-goals-calories"].value as! String
        app.swipeUp()
        app.buttons["daily-goals-suggest"].tap()
        app.buttons["Se forslag"].tap()
        XCTAssertTrue(app.buttons["daily-goals-apply-suggestion"].waitForExistence(timeout: 3))
        app.navigationBars["Beregn nytt forslag"].buttons["Avbryt"].tap()
        app.swipeDown()
        XCTAssertEqual(app.textFields["daily-goals-calories"].value as? String, original)
        app.swipeUp()
        app.buttons["daily-goals-suggest"].tap()
        app.buttons["Se forslag"].tap()
        app.buttons["daily-goals-apply-suggestion"].tap()
        app.navigationBars["Daglige mål"].buttons["Avbryt"].tap()
        openGoals(app)
        XCTAssertEqual(app.textFields["daily-goals-calories"].value as? String, original)
        app.navigationBars["Daglige mål"].buttons["Avbryt"].tap()
    }

    @MainActor
    func testLargeTextKeepsFieldsAndSaveReachable() {
        let app = XCUIApplication()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        openGoals(app)
        XCTAssertTrue(app.textFields["daily-goals-calories"].exists)
        let top = XCTAttachment(screenshot: app.screenshot())
        top.name = "Daglige mål – stor tekst"
        top.lifetime = .keepAlways
        add(top)
        let saveButton = app.buttons["daily-goals-save"]
        for _ in 0..<8 {
            if saveButton.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(saveButton.isHittable)
        let bottom = XCTAttachment(screenshot: app.screenshot())
        bottom.name = "Daglige mål – lagring med stor tekst"
        bottom.lifetime = .keepAlways
        add(bottom)
        save(app)
    }

    @MainActor
    func testSafeModeRemovesGoalFieldsAndActions() {
        let app = XCUIApplication()
        app.launchArguments += ["-safeModeEnabled", "YES", "-safeModeHideGoals", "YES", "-safeModeHideCalories", "YES"]
        app.launch()
        openGoals(app)
        XCTAssertTrue(app.staticTexts["Du har valgt en visning uten mål. Du kan endre visningen i Profil → Innstillinger."].exists)
        XCTAssertFalse(app.textFields["daily-goals-calories"].exists)
        XCTAssertFalse(app.textFields["daily-goals-protein"].exists)
        XCTAssertFalse(app.buttons["daily-goals-save"].exists)
        XCTAssertFalse(app.buttons["daily-goals-suggest"].exists)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Daglige mål – Trygg modus"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.navigationBars["Daglige mål"].buttons["Lukk"].tap()
    }

    @MainActor
    func testHiddenCaloriesLeaveOnlyMacrosEditable() {
        let app = XCUIApplication()
        app.launchArguments += ["-safeModeEnabled", "NO", "-safeModeHideGoals", "NO", "-safeModeHideCalories", "YES"]
        app.launch()
        openGoals(app)
        XCTAssertFalse(app.textFields["daily-goals-calories"].exists)
        XCTAssertTrue(app.textFields["daily-goals-protein"].exists)
        XCTAssertTrue(app.textFields["daily-goals-carbs"].exists)
        XCTAssertTrue(app.textFields["daily-goals-fat"].exists)
        XCTAssertFalse(app.buttons["daily-goals-suggest"].exists)
        XCTAssertTrue(app.buttons["daily-goals-save"].exists)
        app.navigationBars["Daglige mål"].buttons["Avbryt"].tap()
    }
}
