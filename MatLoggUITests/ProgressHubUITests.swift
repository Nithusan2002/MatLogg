import XCTest

final class ProgressHubUITests: XCTestCase {
    @MainActor
    func testCustomizePersistsAcrossRestartAndCancelPreservesLayout() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-demoModeActive", "YES", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
        app.launch()
        openHub(app)
        customize(app)
        app.buttons["Gjenopprett standard"].tap()
        app.buttons["progress-hub-save"].tap()
        XCTAssertTrue(app.staticTexts["Mat og næring"].firstMatch.waitForExistence(timeout: 5))
        capture("Hub – mat og vekt", app)

        customize(app)
        app.buttons["Flytt Vekt opp"].tap()
        app.buttons["Flytt Vekt opp"].tap()
        app.buttons["progress-hub-save"].tap()
        let weight = app.staticTexts["Vekt"].firstMatch
        XCTAssertTrue(weight.waitForExistence(timeout: 5))
        capture("Hub – vekt øverst", app)
        app.terminate()
        app.launch()
        openHub(app)
        XCTAssertTrue(weight.waitForExistence(timeout: 5))
        XCTAssertLessThan(weight.frame.minY, app.staticTexts["Mat og næring"].firstMatch.frame.minY)

        customize(app)
        let nutritionSwitch = app.switches["progress-hub-toggle-nutrition"]
        let weightSwitch = app.switches["progress-hub-toggle-weight"]
        nutritionSwitch.tap()
        XCTAssertEqual(nutritionSwitch.value as? String, "0")
        weightSwitch.tap()
        XCTAssertEqual(weightSwitch.value as? String, "0")
        app.buttons["progress-hub-save"].tap()
        XCTAssertTrue(app.staticTexts["Velg hva du vil se her"].waitForExistence(timeout: 5))
        capture("Hub – alle områder skjult", app)
        app.terminate()
        app.launch()
        openHub(app)
        XCTAssertTrue(app.staticTexts["Velg hva du vil se her"].waitForExistence(timeout: 5))
        customize(app)
        app.buttons["Gjenopprett standard"].tap()
        app.buttons["Avbryt"].tap()
        XCTAssertTrue(app.staticTexts["Velg hva du vil se her"].waitForExistence(timeout: 5))
        customize(app)
        app.buttons["Gjenopprett standard"].tap()
        app.buttons["progress-hub-save"].tap()
        XCTAssertTrue(app.staticTexts["Mat og næring"].firstMatch.waitForExistence(timeout: 5))
    }

    @MainActor
    func testPrototypeLayoutAndCalendarNavigation() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-demoModeActive", "YES", "--steps-qa", "-appAppearance", "dark",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
        app.launch()
        app.openAppleHealthSettings()
        app.setAppleHealthToggle("apple-health-steps-toggle", enabled: true)
        openHub(app)
        let title = app.staticTexts["progress-hub-title"]
        let customizeButton = app.buttons["progress-hub-customize"]
        XCTAssertTrue(title.exists)
        XCTAssertLessThan(title.frame.maxX, customizeButton.frame.minX)
        XCTAssertEqual(title.frame.midY, customizeButton.frame.midY, accuracy: 4)
        customize(app)
        app.buttons["Gjenopprett standard"].tap()
        let steps = app.switches["progress-hub-toggle-steps"]
        for _ in 0..<4 {
            if steps.isHittable { break }
            app.swipeUp()
        }
        steps.tap()
        XCTAssertEqual(steps.value as? String, "1")
        app.buttons["progress-hub-save"].tap()
        let activity = app.buttons["progress-hub-steps-open"]
        for _ in 0..<6 {
            if activity.isHittable { break }
            app.swipeUp()
        }
        activity.tap()
        XCTAssertTrue(app.staticTexts["health-step-count"].waitForExistence(timeout: 5))
        app.navigationBars["Skritt"].buttons.element(boundBy: 0).tap()
        app.swipeDown()
        let weight = app.buttons["progress-hub-weight-open"]
        let nutrition = app.buttons["progress-hub-nutrition-daily-totals"]
        XCTAssertTrue(weight.waitForExistence(timeout: 5))
        XCTAssertTrue(activity.label.contains("Skritt"))
        XCTAssertFalse(activity.label.contains("Hentet"))
        XCTAssertFalse(activity.label.contains("Apple Helse"))
        XCTAssertFalse(weight.label.contains("MatLogg"))
        XCTAssertFalse(app.staticTexts["MatLogg"].exists)
        XCTAssertTrue(activity.isHittable && weight.isHittable)
        XCTAssertLessThan(activity.frame.width, app.frame.width * 0.6)
        XCTAssertLessThan(abs(activity.frame.minY - weight.frame.minY), 8)
        XCTAssertEqual(activity.frame.height, weight.frame.height, accuracy: 1)
        XCTAssertLessThan(activity.frame.minX, weight.frame.minX)
        capture("Utvikling – kompakt prototypeoppsett", app)
        let range = app.staticTexts["progress-period-range"]
        let originalWeek = range.label
        app.buttons["progress-period-day"].tap()
        XCTAssertNotEqual(range.label, originalWeek)
        XCTAssertFalse(nutrition.exists)
        let originalDay = range.label
        app.buttons["progress-period-previous"].tap()
        XCTAssertNotEqual(range.label, originalDay)
        let returnToCurrent = app.buttons["progress-period-current"]
        XCTAssertEqual(returnToCurrent.label, "I dag")
        returnToCurrent.tap()
        XCTAssertEqual(range.label, originalDay)
        XCTAssertFalse(returnToCurrent.exists)
        app.buttons["progress-period-month"].tap()
        XCTAssertNotEqual(range.label, originalWeek)
        for period in ["month", "week"] {
            app.buttons["progress-period-\(period)"].tap()
            let periodLabel = range.label
            XCTAssertTrue(nutrition.waitForExistence(timeout: 5))
            if !nutrition.isHittable { app.swipeUp() }
            nutrition.tap()
            XCTAssertTrue(app.navigationBars["Dagstall"].waitForExistence(timeout: 5))
            XCTAssertTrue(app.staticTexts[periodLabel].exists)
            XCTAssertTrue(app.staticTexts["Registrert i MatLogg"].exists)
            let loggedDays = app.descendants(matching: .any).matching(identifier: "nutrition-day-total")
            XCTAssertTrue(loggedDays.firstMatch.exists)
            XCTAssertTrue(loggedDays.firstMatch.label.contains("kcal"))
            XCTAssertTrue(loggedDays.firstMatch.label.contains("Karbohydrater"))
            capture("Mat og næring – dagstall for " + period, app)
            XCTAssertFalse(app.staticTexts["Ingen registreringer"].exists)
            app.buttons["Ferdig"].tap()
            XCTAssertEqual(range.label, periodLabel)
        }
        app.swipeDown()
        app.buttons["progress-period-next"].tap()
        XCTAssertTrue(app.staticTexts["Ingen mat registrert"].waitForExistence(timeout: 5))
        XCTAssertFalse(nutrition.exists)
    }

    @MainActor
    func testWeightRegistrationAndDeletionFromHub() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-demoModeActive", "YES", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
        app.launch()
        openHub(app)
        customize(app)
        app.buttons["Gjenopprett standard"].tap()
        app.buttons["Flytt Vekt opp"].tap()
        app.buttons["Flytt Vekt opp"].tap()
        app.buttons["progress-hub-save"].tap()
        let weightCard = app.buttons["progress-hub-weight-open"]
        for _ in 0..<6 {
            if weightCard.isHittable { break }
            app.swipeUp()
        }
        weightCard.tap()
        let register = app.buttons["Registrer vekt"]
        XCTAssertTrue(register.waitForExistence(timeout: 5))
        register.tap()
        let field = app.textFields["Vekt (kg)"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("74,3")
        if app.buttons["Ferdig"].exists { app.buttons["Ferdig"].tap() }
        let save = app.buttons["Lagre"].firstMatch
        for _ in 0..<4 {
            if save.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(save.isHittable)
        save.tap()
        XCTAssertTrue(app.staticTexts["74,3 kg"].firstMatch.waitForExistence(timeout: 5))
        app.navigationBars["Vekt"].buttons.element(boundBy: 0).tap()
        app.swipeDown()
        app.buttons["progress-period-previous"].tap()
        XCTAssertFalse(weightCard.label.contains("74,3 kg"))
        let historicalCardLabel = weightCard.label
        weightCard.tap()
        let periodWeight = app.staticTexts["local-weight-latest"]
        XCTAssertTrue(periodWeight.waitForExistence(timeout: 5))
        XCTAssertTrue(historicalCardLabel.contains(periodWeight.label))
        XCTAssertNotEqual(periodWeight.label, "74,3 kg")
        capture("Vekt – valgt historisk periode", app)
        let history = app.buttons["Se alle registreringer"]
        for _ in 0..<5 {
            if history.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(history.isHittable)
        history.tap()
        XCTAssertTrue(app.navigationBars["Vekthistorikk"].waitForExistence(timeout: 5))
        let delete = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Slett 74,3 kg registrert'")).firstMatch
        XCTAssertTrue(delete.waitForExistence(timeout: 5))
        let deletedLabel = delete.label
        delete.tap()
        app.alerts.buttons["Slett"].tap()
        let exactEntry = app.buttons.matching(NSPredicate(format: "label == %@", deletedLabel)).firstMatch
        let deleted = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: exactEntry)
        XCTAssertEqual(XCTWaiter.wait(for: [deleted], timeout: 5), .completed)
    }

    @MainActor
    func testAppleHealthWeightConnectsShowsSourceAndDisconnects() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-demoModeActive", "YES", "--health-weight-qa",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
        app.launch()
        app.openAppleHealthSettings()
        app.setAppleHealthToggle("apple-health-weight-toggle", enabled: false)
        openHub(app)
        customize(app)
        app.buttons["Gjenopprett standard"].tap()
        app.buttons["Flytt Vekt opp"].tap()
        app.buttons["Flytt Vekt opp"].tap()
        app.buttons["progress-hub-save"].tap()

        let card = app.buttons["progress-hub-weight-open"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        card.tap()
        let shortcut = app.buttons["apple-health-settings-shortcut"]
        XCTAssertTrue(shortcut.waitForExistence(timeout: 5))
        shortcut.tap()
        let settings = app.navigationBars["Apple Helse"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        let stepValue = app.switches["apple-health-steps-toggle"].value as? String
        app.setAppleHealthToggle("apple-health-weight-toggle", enabled: true)
        XCTAssertEqual(app.switches["apple-health-steps-toggle"].value as? String, stepValue)
        app.buttons["apple-health-settings-done"].tap()
        XCTAssertTrue(app.navigationBars["Vekt"].waitForExistence(timeout: 5))
        let latest = app.staticTexts["health-weight-latest"]
        XCTAssertTrue(latest.waitForExistence(timeout: 5))
        XCTAssertEqual(latest.label, "71,2 kg")
        XCTAssertTrue(app.staticTexts["Vekt fra Apple Helse"].exists)
        XCTAssertTrue(app.staticTexts["Registrert i MatLogg"].exists)
        XCTAssertTrue(app.buttons["Registrer vekt"].exists)
        capture("Vekt fra Apple Helse og MatLogg", app)

        app.navigationBars["Vekt"].buttons.element(boundBy: 0).tap()
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        XCTAssertFalse(card.label.contains("Apple Helse"))
        app.openAppleHealthSettings()
        app.setAppleHealthToggle("apple-health-weight-toggle", enabled: false)
        openHub(app)
        card.tap()
        XCTAssertTrue(shortcut.waitForExistence(timeout: 5))
        XCTAssertFalse(latest.exists)
        XCTAssertTrue(app.buttons["Registrer vekt"].exists)
    }

    @MainActor
    func testCustomizeWithLargeTextAndDarkAppearance() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-demoModeActive", "YES", "-appAppearance", "dark",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        openHub(app)
        let title = app.staticTexts["progress-hub-title"]
        XCTAssertTrue(title.exists)
        XCTAssertLessThan(title.frame.maxY, app.buttons["progress-hub-customize"].frame.minY)
        customize(app)
        XCTAssertTrue(app.navigationBars["Tilpass"].exists)
        capture("Hub – tilpass med stor tekst", app)
        let toggle = app.switches["progress-hub-toggle-nutrition"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        for _ in 0..<6 {
            if toggle.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(toggle.isHittable)
        app.buttons["Avbryt"].tap()
        XCTAssertTrue(app.buttons["progress-hub-customize"].waitForExistence(timeout: 5))
        capture("Hub – mørk modus og stor tekst", app)

        let dailyTotals = app.buttons["progress-hub-nutrition-daily-totals"]
        for _ in 0..<8 {
            if dailyTotals.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(dailyTotals.isHittable)
        dailyTotals.tap()
        XCTAssertTrue(app.navigationBars["Dagstall"].waitForExistence(timeout: 5))
        let row = app.descendants(matching: .any).matching(identifier: "nutrition-day-total").firstMatch
        XCTAssertTrue(row.isHittable)
        XCTAssertTrue(app.buttons["Ferdig"].isHittable)
        capture("Mat og næring – dagstall med stor tekst", app)
    }

    @MainActor private func openHub(_ app: XCUIApplication) {
        XCTAssertTrue(app.buttons["Utvikling"].firstMatch.waitForExistence(timeout: 30))
        app.buttons["Utvikling"].firstMatch.tap()
        XCTAssertTrue(app.buttons["progress-hub-customize"].waitForExistence(timeout: 10))
    }

    @MainActor private func customize(_ app: XCUIApplication) {
        let button = app.buttons["progress-hub-customize"]
        for _ in 0..<6 {
            if button.isHittable { break }
            app.swipeDown()
        }
        button.tap()
        XCTAssertTrue(app.buttons["progress-hub-save"].waitForExistence(timeout: 5))
    }

    @MainActor private func capture(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
