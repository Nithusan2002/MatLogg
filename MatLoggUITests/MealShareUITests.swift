import XCTest

final class MealShareUITests: XCTestCase {
    @MainActor
    func testSelectAllStylesAndCancelWithoutLogging() throws {
        try checkSharing(largeText: false)
    }

    @MainActor
    func testStyleControlsWithLargestText() throws {
        try checkSharing(largeText: true)
    }

    @MainActor
    private func checkSharing(largeText: Bool) throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["--skip-auth", "-demoModeActive", "YES", "-UIPreferredContentSizeCategoryName",
                               largeText ? "UICTContentSizeCategoryAccessibilityXXXL" : "UICTContentSizeCategoryL"]
        app.launch()
        XCTAssertTrue(app.buttons["Søk"].waitForExistence(timeout: 15))
        app.buttons["Søk"].tap()
        let library = app.buttons["food-search-saved-meals"]
        XCTAssertTrue(library.waitForExistence(timeout: 8))
        for _ in 0..<5 {
            if library.isHittable && library.frame.maxY < app.buttons["tab-log-food"].frame.minY { break }
            app.collectionViews.firstMatch.swipeUp()
        }
        library.tap()
        let meal = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'saved-meal-open-'")).firstMatch
        XCTAssertTrue(meal.waitForExistence(timeout: 8))
        meal.tap()
        let share = app.buttons["saved-meal-share"]
        XCTAssertTrue(share.waitForExistence(timeout: 5))
        share.tap()
        for style in ["light", "dark", "photo"] {
            let button = app.buttons["meal-share-style-" + style]
            XCTAssertTrue(button.waitForExistence(timeout: 5))
            for _ in 0..<8 {
                let top = app.navigationBars["Del måltid"].frame.maxY
                let bottom = app.buttons["meal-share-export"].frame.minY
                if button.isHittable && button.frame.minY >= top && button.frame.maxY <= bottom { break }
                let scroll = app.scrollViews["meal-share-scroll"]
                let startY: CGFloat = button.frame.minY < top ? 0.35 : 0.75
                let endY: CGFloat = 0.55
                scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: startY))
                    .press(forDuration: 0.05, thenDragTo: scroll.coordinate(
                        withNormalizedOffset: CGVector(dx: 0.5, dy: endY)))
            }
            XCTAssertGreaterThanOrEqual(button.frame.minY, app.navigationBars["Del måltid"].frame.maxY)
            XCTAssertLessThanOrEqual(button.frame.maxY, app.buttons["meal-share-export"].frame.minY)
            button.tap()
            let selected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isSelected == true"), object: button)
            XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: 3), .completed)
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = "meal-share-\(style)-\(largeText ? "large" : "normal")"
            screenshot.lifetime = .keepAlways
            add(screenshot)
        }
        XCTAssertTrue(app.buttons["meal-share-export"].isEnabled)
        if !largeText {
            app.buttons["meal-share-export"].tap()
            let systemSheet = app.otherElements["meal-share-system-sheet"]
            XCTAssertTrue(systemSheet.waitForExistence(timeout: 8))
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = "meal-share-system-sheet"
            screenshot.lifetime = .keepAlways
            add(screenshot)
            app.buttons["header.closeButton"].tap()
            XCTAssertTrue(systemSheet.waitForNonExistence(timeout: 5))
            XCTAssertTrue(app.buttons["meal-share-close"].waitForExistence(timeout: 5))
        }
        app.buttons["meal-share-close"].tap()
        XCTAssertTrue(share.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["saved-meal-log"].exists)
    }
}
