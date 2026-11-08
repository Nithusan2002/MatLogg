import XCTest

final class HealthStepsUITests: XCTestCase {
    @MainActor
    func testStepsConnectRefreshAfterRestartAndDisconnect() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-demoModeActive", "YES", "--steps-qa", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
        app.launch()
        configureStepsCard(app, isVisible: false)
        XCTAssertFalse(app.buttons["progress-hub-steps-open"].exists)
        app.openAppleHealthSettings()
        app.setAppleHealthToggle("apple-health-steps-toggle", enabled: true)
        capture("Apple Helse – innstillinger", app)
        configureStepsCard(app)
        openActivity(app)
        let count = app.staticTexts["health-step-count"]
        XCTAssertTrue(count.waitForExistence(timeout: 5))
        XCTAssertEqual(count.label.components(separatedBy: .whitespacesAndNewlines).joined(), "6543skritt")
        XCTAssertTrue(app.staticTexts["QA – eksempeldata"].exists)
        XCTAssertTrue(app.staticTexts["Skritt per dag"].exists)
        capture("Skritt – ukesum og dagsfordeling", app)
        app.navigationBars["Aktivitet"].buttons.element(boundBy: 0).tap()
        capture("Skritt – kompakt kort med QA-data", app)

        app.buttons["progress-period-day"].tap()
        let range = app.staticTexts["progress-period-range"]
        let initialDay = range.label
        app.buttons["progress-period-previous"].tap()
        let previousDay = range.label
        XCTAssertNotEqual(initialDay, previousDay)
        openActivity(app)
        XCTAssertTrue(count.waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["health-steps-period"].label, "\(previousDay) · Apple Helse")
        XCTAssertTrue(app.staticTexts["Skritt per time"].exists)
        XCTAssertEqual(count.label.components(separatedBy: .whitespacesAndNewlines).joined(), "6543skritt")
        app.navigationBars["Aktivitet"].buttons.element(boundBy: 0).tap()
        capture("Skritt – dagsvisning med graf på Aktivitetskortet", app)

        app.buttons["progress-period-month"].tap()
        let month = range.label
        openActivity(app)
        XCTAssertTrue(count.waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["health-steps-period"].label, "\(month) · Apple Helse")
        XCTAssertTrue(app.staticTexts["Skritt per dag"].exists)

        app.terminate()
        app.launch()
        openHub(app)
        openActivity(app)
        XCTAssertTrue(count.waitForExistence(timeout: 10))
        XCTAssertEqual(count.label.components(separatedBy: .whitespacesAndNewlines).joined(), "6543skritt")
        app.navigationBars["Aktivitet"].buttons.element(boundBy: 0).tap()
        app.openAppleHealthSettings()
        XCTAssertEqual(app.switches["apple-health-steps-toggle"].value as? String, "1")
        app.setAppleHealthToggle("apple-health-steps-toggle", enabled: false)
        openHub(app)
        openActivity(app)
        XCTAssertTrue(app.buttons["apple-health-settings-shortcut"].waitForExistence(timeout: 5))
        XCTAssertFalse(count.exists)
    }

    @MainActor
    func testNoDataIsNotShownAsZeroAndLargeTextRemainsUsable() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-demoModeActive", "YES", "--steps-qa", "--steps-qa-no-data",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        // Set up at normal text size first; then reopen with the accessibility size.
        app.terminate()
        app.launchArguments = ["-demoModeActive", "YES", "--steps-qa", "--steps-qa-no-data",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
        app.launch()
        app.openAppleHealthSettings()
        app.setAppleHealthToggle("apple-health-steps-toggle", enabled: true)
        configureStepsCard(app)
        openActivity(app)
        XCTAssertTrue(app.staticTexts["Ingen skrittdata tilgjengelig"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["health-step-count"].exists)
        app.terminate()
        app.launchArguments = ["-demoModeActive", "YES", "--steps-qa", "--steps-qa-no-data",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        openHub(app)
        openActivity(app)
        let noData = app.staticTexts["Ingen skrittdata tilgjengelig"]
        for _ in 0..<7 {
            if noData.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(noData.waitForExistence(timeout: 5))
        XCTAssertTrue(noData.isHittable)
        XCTAssertFalse(app.staticTexts["health-step-count"].exists)
        capture("Skritt – ingen data med stor tekst", app)
    }

    @MainActor
    func testDemoDoesNotOfferRealHealthAccess() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-demoModeActive", "YES", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
        app.launch()
        app.openAppleHealthSettings()
        XCTAssertFalse(app.switches["apple-health-steps-toggle"].isEnabled)
        XCTAssertFalse(app.switches["apple-health-weight-toggle"].isEnabled)
        configureStepsCard(app)
        let demoLabel = app.staticTexts["progress-hub-demo-label"]
        XCTAssertTrue(demoLabel.exists)
        XCTAssertEqual(demoLabel.label, "Demodata")
        XCTAssertEqual(app.staticTexts.matching(identifier: "Demodata").count, 1)
        XCTAssertFalse(app.buttons["progress-hub-steps-open"].label.contains("Apple Helse"))
        capture("Utvikling – én Demodata-etikett", app)
        openActivity(app)
        let message = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Apple Helse kobles ikke til i demomodus.'")).firstMatch
        XCTAssertTrue(message.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["apple-health-settings-shortcut"].exists)
        XCTAssertFalse(app.staticTexts["health-step-count"].exists)
    }

    @MainActor private func configureStepsCard(_ app: XCUIApplication, isVisible: Bool = true) {
        openHub(app)
        app.buttons["progress-hub-customize"].tap()
        XCTAssertTrue(app.buttons["progress-hub-save"].waitForExistence(timeout: 5))
        app.buttons["Gjenopprett standard"].tap()
        let toggle = app.switches["progress-hub-toggle-steps"]
        for _ in 0..<5 {
            if toggle.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(toggle.isHittable)
        if isVisible {
            toggle.tap()
            XCTAssertEqual(toggle.value as? String, "1")
            app.buttons["Flytt Skritt opp"].tap()
        } else {
            XCTAssertEqual(toggle.value as? String, "0")
        }
        app.buttons["progress-hub-save"].tap()
    }

    @MainActor private func openActivity(_ app: XCUIApplication) {
        let card = app.buttons["progress-hub-steps-open"]
        for _ in 0..<12 {
            if card.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(card.isHittable)
        card.tap()
        XCTAssertTrue(app.navigationBars["Aktivitet"].waitForExistence(timeout: 5))
    }

    @MainActor private func openHub(_ app: XCUIApplication) {
        XCTAssertTrue(app.buttons["Utvikling"].firstMatch.waitForExistence(timeout: 30))
        app.buttons["Utvikling"].firstMatch.tap()
        XCTAssertTrue(app.buttons["progress-hub-customize"].waitForExistence(timeout: 10))
    }

    @MainActor private func capture(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

@MainActor
extension XCUIApplication {
    func openAppleHealthSettings() {
        XCTAssertTrue(buttons["Profil"].firstMatch.waitForExistence(timeout: 30))
        buttons["Profil"].firstMatch.tap()
        let healthSettings = navigationBars["Apple Helse"]
        if healthSettings.exists { return }
        let healthLink = buttons["profile-apple-health"]
        if !healthLink.exists {
            let settings = buttons["Innstillinger"].firstMatch
            XCTAssertTrue(settings.waitForExistence(timeout: 5))
            settings.tap()
        }
        XCTAssertTrue(healthLink.waitForExistence(timeout: 5))
        healthLink.tap()
        XCTAssertTrue(healthSettings.waitForExistence(timeout: 5))
    }

    func setAppleHealthToggle(_ identifier: String, enabled: Bool) {
        let toggle = switches[identifier]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        let expectedValue = enabled ? "1" : "0"
        if toggle.value as? String != expectedValue {
            let control = toggle.switches.firstMatch
            if control.exists && control.isHittable {
                control.tap()
            } else {
                toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
            }
        }
        let updated = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", expectedValue), object: toggle)
        XCTAssertEqual(XCTWaiter.wait(for: [updated], timeout: 5), .completed)
    }
}
