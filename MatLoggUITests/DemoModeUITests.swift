import XCTest

final class DemoModeUITests: XCTestCase {
    @MainActor
    func testSwitchingAndRestart() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--skip-auth"]
        app.launch()

        func openProfile() {
            XCTAssertTrue(app.buttons["Profil"].waitForExistence(timeout: 10))
            app.buttons["Profil"].tap()
            let control = app.switches["profile-demo-mode"]
            for _ in 0..<4 where !control.isHittable { app.swipeUp() }
            XCTAssertTrue(control.waitForExistence(timeout: 10))
        }
        openProfile()
        if app.switches["profile-demo-mode"].value as? String == "1" {
            app.switches["profile-demo-mode"].tap()
            openProfile()
        }
        app.switches["profile-demo-mode"].tap()
        openProfile()
        XCTAssertEqual(app.switches["profile-demo-mode"].value as? String, "1")
        XCTAssertFalse(app.buttons["demo-mode-switch"].exists)
        XCTAssertFalse(app.staticTexts["Demo · fiktiv profil"].exists)
        app.terminate()
        app.launch()
        openProfile()
        XCTAssertEqual(app.switches["profile-demo-mode"].value as? String, "1")
        app.switches["profile-demo-mode"].tap()
        openProfile()
        XCTAssertEqual(app.switches["profile-demo-mode"].value as? String, "0")
    }
}
