import XCTest

final class WaterLoggingUITests: XCTestCase {
    @MainActor
    func testOneTapPersistsAndCanBeCorrected() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--skip-auth"]
        app.launch()
        let add = app.buttons["water-add"]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        let ready = NSPredicate(format: "enabled == true")
        expectation(for: ready, evaluatedWith: add)
        waitForExpectations(timeout: 5)
        let count = app.buttons["water-count"]
        let initial = try XCTUnwrap(Int(count.value as? String ?? ""))
        add.tap()
        expectation(for: NSPredicate(format: "value == %@", String(initial + 1)), evaluatedWith: count)
        waitForExpectations(timeout: 5)
        XCTAssertFalse(app.buttons["Angre"].exists)
        XCTAssertFalse(app.staticTexts["Ett glass lagt til"].exists)
        app.terminate()
        app.launch()
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        expectation(for: ready, evaluatedWith: add)
        waitForExpectations(timeout: 5)
        XCTAssertEqual(count.value as? String, String(initial + 1))
        let remove = app.buttons["water-remove"]
        XCTAssertTrue(remove.isEnabled)
        remove.tap()
        expectation(for: NSPredicate(format: "value == %@", String(initial)), evaluatedWith: count)
        waitForExpectations(timeout: 5)
        if initial == 0 { XCTAssertFalse(remove.isEnabled) }
    }
}
