import XCTest

final class WaterLoggingUITests: XCTestCase {
    @MainActor
    func testWaterWorksWithEnergyHiddenAndLargeText() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--skip-auth",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        setEnergyVisibility(false, in: app)
        let count = app.descendants(matching: .any)["water-count"]
        XCTAssertTrue(count.waitForExistence(timeout: 8))
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: app.staticTexts["Registrert energi"])
        waitForExpectations(timeout: 5)
        let add = app.buttons["water-add"]
        expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: add)
        waitForExpectations(timeout: 5)
        for _ in 0..<5 {
            if add.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(add.isHittable)
        let initial = try XCTUnwrap(Int(count.value as? String ?? ""))
        add.tap()
        expectation(for: NSPredicate(format: "value == %@", String(initial + 1)), evaluatedWith: count)
        waitForExpectations(timeout: 5)
        app.buttons["water-remove"].tap()
        expectation(for: NSPredicate(format: "value == %@", String(initial)), evaluatedWith: count)
        waitForExpectations(timeout: 5)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Vann uten energi – største tekst"
        screenshot.lifetime = .keepAlways
        self.add(screenshot)
    }

    @MainActor
    func testOneTapPersistsAndCanBeCorrected() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--skip-auth",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
        app.launch()
        setEnergyVisibility(true, in: app)
        let add = app.buttons["water-add"]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        let ready = NSPredicate(format: "enabled == true")
        expectation(for: ready, evaluatedWith: add)
        waitForExpectations(timeout: 5)
        let count = app.descendants(matching: .any)["water-count"]
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
        if initial == 0 {
            XCTAssertTrue(remove.exists)
            XCTAssertFalse(remove.isEnabled)
        }
    }
    @MainActor
    private func setEnergyVisibility(_ visible: Bool, in app: XCUIApplication) {
        let profile = app.buttons["Profil"]
        XCTAssertTrue(profile.waitForExistence(timeout: 8))
        profile.tap()
        let settings = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Innstillinger'")).firstMatch
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        for _ in 0..<8 {
            if settings.isHittable { break }
            app.swipeUp()
        }
        settings.tap()
        let toggle = app.switches["Vis energi og mål på Hjem"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        for _ in 0..<5 {
            if toggle.isHittable { break }
            app.swipeUp()
        }
        if (toggle.value as? String == "1") != visible {
            let control = toggle.switches.firstMatch
            if control.exists {
                control.tap()
            } else {
                toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
            }
        }
        expectation(for: NSPredicate(format: "value == %@", visible ? "1" : "0"), evaluatedWith: toggle)
        waitForExpectations(timeout: 5)
        app.buttons["Hjem"].tap()
    }

}
