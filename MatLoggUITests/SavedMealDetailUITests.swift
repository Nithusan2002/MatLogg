import XCTest

final class SavedMealDetailUITests: XCTestCase {
    @MainActor
    func testEditingAndDiscardStayInSameDetail() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-demoModeActive", "YES"]
        app.launch()
        let searchTab = app.buttons["Søk"].firstMatch
        XCTAssertTrue(searchTab.waitForExistence(timeout: 20))
        searchTab.tap()
        let library = app.buttons["food-search-saved-meals"]
        XCTAssertTrue(library.waitForExistence(timeout: 8))
        library.tap()
        let meal = app.staticTexts["Yoghurt med havre og bær"].firstMatch
        XCTAssertTrue(meal.waitForExistence(timeout: 8))
        meal.tap()
        let toggle = app.buttons["saved-meal-edit-toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 8))
        XCTAssertEqual(toggle.label, "Rediger")
        toggle.tap()
        let name = app.textFields["saved-meal-edit-name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText(" test")
        app.buttons["Ferdig"].firstMatch.tap()
        toggle.tap()
        XCTAssertTrue(app.alerts["Forkaste endringene?"].waitForExistence(timeout: 5))
        app.alerts.buttons["Forkast"].tap()
        XCTAssertEqual(toggle.label, "Rediger")
        XCTAssertFalse(name.exists)
        XCTAssertTrue(app.staticTexts["Loggfør lagret måltid"].exists)
        XCTAssertTrue(app.buttons["saved-meal-log"].exists)
        toggle.tap()
        XCTAssertEqual(name.value as? String, "Yoghurt med havre og bær")
    }
}
