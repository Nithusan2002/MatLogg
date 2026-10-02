import XCTest

final class MorningCheckInUITests: XCTestCase {
    @MainActor
    func testOptionalCheckInAndWeightEditing() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments.append("--skip-auth")
        app.launch()
        let open = app.buttons["morning-check-in-open"]
        XCTAssertTrue(open.waitForExistence(timeout: 10))
        open.tap()
        let field = app.buttons["morning-check-in-weight"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        let value = app.textFields["measurement-picker-value"]
        XCTAssertTrue(value.waitForExistence(timeout: 5))
        value.tap()
        value.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: (value.value as? String ?? "").count) + "72,5")
        app.buttons["measurement-picker-apply"].tap()
        let done = app.buttons["morning-check-in-save"]
        if !done.isHittable { app.swipeUp() }
        done.tap()
        XCTAssertTrue(open.waitForExistence(timeout: 5))
        XCTAssertEqual(open.label, "Sjekket inn i dag")
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: open)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 5), .completed)
        open.tap()
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertEqual(field.value as? String, "72,5")
        // Opening and cancelling the ruler must preserve the recorded value.
        field.tap()
        XCTAssertTrue(value.waitForExistence(timeout: 5))
        let ruler = app.otherElements["measurement-picker-ruler"]
        ruler.swipeLeft()
        app.scrollViews["measurement-picker-sheet"].buttons["Avbryt"].tap()
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertEqual(field.value as? String, "72,5")
        app.buttons["Avbryt"].tap()
        app.buttons["Forrige dag"].tap()
        XCTAssertFalse(open.exists)
    }
}
