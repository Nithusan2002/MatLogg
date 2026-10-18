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
    func testSelectCardFormats() {
        let app = openMealShare(largeText: false)
        let formats = app.segmentedControls["meal-share-format"]
        XCTAssertTrue(formats.waitForExistence(timeout: 5))
        for format in ["3:4", "9:16"] {
            formats.buttons[format].tap()
            XCTAssertTrue(formats.buttons[format].isSelected)
            XCTAssertLessThanOrEqual(app.buttons["meal-share-customize"].frame.maxY,
                                     app.buttons["meal-share-export"].frame.minY - 12)
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = "meal-share-format-\(format.replacingOccurrences(of: ":", with: "x"))"
            screenshot.lifetime = .keepAlways
            add(screenshot)
        }
        app.buttons["meal-share-close"].tap()
        app.buttons["saved-meal-share"].tap()
        XCTAssertTrue(app.segmentedControls["meal-share-format"].buttons["9:16"].isSelected)
        app.buttons["meal-share-close"].tap()
    }

    @MainActor
    func testSaveMealCardToPhotos() {
        // Dedicated QA simulator: grant photos-add before this integration test.
        // The first system permission dialog is a separate physical-device check.
        let app = openMealShare(largeText: false)
        let save = app.buttons["meal-share-save"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        XCTAssertTrue(save.isEnabled)
        XCTAssertTrue(app.buttons["meal-share-export"].isEnabled)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "meal-share-save-and-share"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        save.tap()
        XCTAssertTrue(app.alerts.staticTexts["Bildet er lagret i Bilder."].waitForExistence(timeout: 10))
        app.alerts.buttons["OK"].tap()
        XCTAssertTrue(save.isEnabled)
        XCTAssertTrue(app.buttons["meal-share-export"].isEnabled)
        app.buttons["meal-share-close"].tap()
        XCTAssertTrue(app.buttons["saved-meal-log"].exists)
    }

    @MainActor
    private func openMealShare(largeText: Bool) -> XCUIApplication {
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
        return app
    }

    @MainActor
    private func checkSharing(largeText: Bool) throws {
        let app = openMealShare(largeText: largeText)
        let share = app.buttons["saved-meal-share"]
        if !largeText {
            let firstStyle = app.buttons["meal-share-style-light"]
            XCTAssertTrue(firstStyle.waitForExistence(timeout: 5))
            for style in ["light", "dark", "photo"] {
                XCTAssertLessThanOrEqual(app.buttons["meal-share-style-" + style].frame.maxY,
                                         app.buttons["meal-share-export"].frame.minY - 12)
            }
            XCTAssertLessThanOrEqual(app.buttons["meal-share-customize"].frame.maxY,
                                     app.buttons["meal-share-export"].frame.minY - 12)
        }
        for style in ["light", "dark", "photo"] {
            let button = app.buttons["meal-share-style-" + style]
            XCTAssertTrue(button.waitForExistence(timeout: 5))
            for _ in 0..<8 {
                let top = app.navigationBars["Del måltid"].frame.maxY
                let bottom = app.buttons["meal-share-export"].frame.minY - 12
                if button.isHittable && button.frame.minY >= top && button.frame.maxY <= bottom { break }
                let scroll = app.scrollViews["meal-share-scroll"]
                let startY: CGFloat = button.frame.minY < top ? 0.35 : 0.75
                let endY: CGFloat = 0.55
                scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: startY))
                    .press(forDuration: 0.05, thenDragTo: scroll.coordinate(
                        withNormalizedOffset: CGVector(dx: 0.5, dy: endY)))
            }
            XCTAssertGreaterThanOrEqual(button.frame.minY, app.navigationBars["Del måltid"].frame.maxY)
            XCTAssertLessThanOrEqual(button.frame.maxY, app.buttons["meal-share-export"].frame.minY - 12)
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
            let customize = app.buttons["meal-share-customize"]
            makeVisible(customize, in: app)
            customize.tap()
            for nutrient in ["calories", "protein", "carbs", "fat", "logo"] {
                let toggle = app.switches["meal-share-include-" + nutrient]
                XCTAssertTrue(toggle.waitForExistence(timeout: 3))
                makeVisible(toggle, in: app)
                if toggle.value as? String == "1" { toggle.tap() }
                XCTAssertEqual(toggle.value as? String, "0")
            }
            makeVisible(customize, in: app)
            customize.tap()
            let customized = XCTAttachment(screenshot: app.screenshot())
            customized.name = "meal-share-no-nutrition"
            customized.lifetime = .keepAlways
            add(customized)
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
            app.buttons["meal-share-close"].tap()
            share.tap()
            makeVisible(customize, in: app)
            customize.tap()
            for nutrient in ["calories", "protein", "carbs", "fat", "logo"] {
                let toggle = app.switches["meal-share-include-" + nutrient]
                makeVisible(toggle, in: app)
                XCTAssertEqual(toggle.value as? String, "0")
                toggle.tap()
            }
        }
        app.buttons["meal-share-close"].tap()
        XCTAssertTrue(share.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["saved-meal-log"].exists)
    }

    @MainActor
    private func makeVisible(_ element: XCUIElement, in app: XCUIApplication) {
        XCTAssertTrue(element.waitForExistence(timeout: 5))
        for _ in 0..<10 {
            let top = app.navigationBars["Del måltid"].frame.maxY
            let bottom = app.buttons["meal-share-export"].frame.minY - 12
            if element.isHittable && element.frame.minY >= top && element.frame.maxY <= bottom { return }
            let scroll = app.scrollViews["meal-share-scroll"]
            let startY: CGFloat = element.frame.minY < top ? 0.35 : 0.75
            scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: startY))
                .press(forDuration: 0.05, thenDragTo: scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55)))
        }
        XCTFail("Control is obscured: \(element.identifier)")
    }
}
