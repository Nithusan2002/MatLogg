import XCTest

final class FoodGroupUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    @MainActor
    func testManualFoodGroupPickerAndLoggedThumbnail() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--skip-auth", "-demoModeActive", "NO", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
        app.launch()
        XCTAssertTrue(app.buttons["tab-log-food"].waitForExistence(timeout: 12))
        app.buttons["tab-log-food"].tap()
        let manual = app.buttons["quick-log-manual"]
        XCTAssertTrue(manual.waitForExistence(timeout: 6))
        reveal(manual, in: app)
        manual.tap()
        let picker = app.buttons["food-group-picker"]
        if !picker.waitForExistence(timeout: 2),
           let resume = app.buttons.matching(NSPredicate(format: "label == 'Fortsett'"))
            .allElementsBoundByIndex.first(where: { $0.isHittable }) {
            resume.tap()
        }
        XCTAssertTrue(picker.waitForExistence(timeout: 6))
        picker.tap()
        app.buttons["Brød og bakst"].tap()
        capture(app, "food-group-manual-bread")
        let name = "Ikontest " + UUID().uuidString.prefix(6)
        for (label, value) in [("Produktnavn", name), ("Energi", "100"),
                               ("Protein", "2"), ("Karbohydrat", "20"), ("Fett", "1")] {
            let field = app.textFields[label]
            reveal(field, in: app)
            field.tap()
            if let existing = field.value as? String, !existing.isEmpty, !existing.hasPrefix("For eksempel") {
                field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: existing.count))
            }
            field.typeText(value)
        }
        let save = app.buttons["Lagre og velg mengde"]
        reveal(save, in: app)
        save.tap()
        let log = app.buttons["logging-draft-save"]
        XCTAssertTrue(log.waitForExistence(timeout: 8))
        log.tap()
        let receipt = app.buttons["log-receipt-close"]
        if receipt.waitForExistence(timeout: 3) {
            receipt.tap()
            XCTAssertTrue(receipt.waitForNonExistence(timeout: 3))
        }
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'home-log-row-' AND label CONTAINS %@", name)).firstMatch
        reveal(row, in: app)
        XCTAssertTrue(row.exists)
        capture(app, "food-group-home-bread")
    }

    @MainActor
    func testPickerAtAccessibilitySize() {
        let app = XCUIApplication()
        app.launchArguments = ["--skip-auth", "-demoModeActive", "NO", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.buttons["tab-log-food"].waitForExistence(timeout: 12))
        app.buttons["tab-log-food"].tap()
        let manual = app.buttons["quick-log-manual"]
        XCTAssertTrue(manual.waitForExistence(timeout: 6))
        reveal(manual, in: app)
        manual.tap()
        let picker = app.buttons["food-group-picker"]
        if !picker.waitForExistence(timeout: 2),
           let resume = app.buttons.matching(NSPredicate(format: "label == 'Fortsett'"))
            .allElementsBoundByIndex.first(where: { $0.isHittable }) {
            resume.tap()
        }
        XCTAssertTrue(picker.waitForExistence(timeout: 6))
        reveal(picker, in: app)
        XCTAssertTrue(picker.isHittable)
        capture(app, "food-group-accessibility")
        let navigation = app.navigationBars["Opprett produkt"]
        let close = navigation.buttons["Lukk"].exists ? navigation.buttons["Lukk"] : navigation.buttons["Avbryt"]
        close.tap()
    }

    @MainActor private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        // isHittable alone also reports fields behind the navigation bar as visible.
        for _ in 0..<18 {
            let midY = element.frame.midY
            if element.isHittable && midY > 170 && midY < app.frame.height * 0.60 { return }
            let down = midY < 170
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: down ? 0.36 : 0.53))
            let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: down ? 0.53 : 0.36))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        XCTAssertTrue(element.isHittable)
    }

    @MainActor private func capture(_ app: XCUIApplication, _ name: String) {
        let image = XCTAttachment(screenshot: app.screenshot())
        image.name = name
        image.lifetime = .keepAlways
        add(image)
    }
}
