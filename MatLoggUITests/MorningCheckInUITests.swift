import XCTest

final class MorningCheckInUITests: XCTestCase {
    @MainActor
    func testHomeDoesNotOfferCheckIn() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments.append("--skip-auth")
        app.launch()
        XCTAssertTrue(app.buttons["Forrige dag"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["morning-check-in-open"].exists)
    }
}
