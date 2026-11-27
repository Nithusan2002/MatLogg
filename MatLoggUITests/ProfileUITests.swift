import XCTest

final class ProfileUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    func testMeasurementPickerValidatesInputAndCancelDiscardsDraft() {
        let app = XCUIApplication()
        app.launchArguments.append("--skip-auth")
        app.launch()
        app.buttons["Profil"].tap()
        let details = app.buttons["profile-personal-details"]
        XCTAssertTrue(details.waitForExistence(timeout: 3))
        details.tap()
        XCTAssertTrue(app.navigationBars["Personlige detaljer"].waitForExistence(timeout: 3))
        let weight = app.buttons["personal-details-weight"]
        let original = weight.label
        weight.tap()
        let value = app.textFields["measurement-picker-value"]
        XCTAssertTrue(value.waitForExistence(timeout: 3))
        value.tap()
        value.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: (value.value as? String ?? "").count) + "0")
        XCTAssertEqual(value.value as? String, "0")
        let picker = app.scrollViews["measurement-picker-sheet"]
        picker.swipeDown()
        picker.swipeDown()
        app.buttons["measurement-picker-apply"].tap()
        let afterApply = XCTAttachment(screenshot: app.screenshot())
        afterApply.name = "Vektinntasting – etter bruk av null"
        afterApply.lifetime = .keepAlways
        add(afterApply)
        XCTAssertTrue(picker.waitForExistence(timeout: 5), "Ugyldig verdi skal ikke lukke redigeringen.")
        // Tapping the button can scroll the validation message above the visible viewport.
        picker.swipeDown()
        picker.swipeDown()
        XCTAssertEqual(value.value as? String, "0", "Skalaen skal ikke erstatte ugyldig manuelt input.")
        let validation = app.descendants(matching: .any)["measurement-picker-error"].firstMatch
        let invalid = XCTAttachment(screenshot: app.screenshot())
        invalid.name = "Vektinntasting – synlig validering"
        invalid.lifetime = .keepAlways
        add(invalid)
        XCTAssertTrue(validation.waitForExistence(timeout: 5))
        XCTAssertTrue(validation.label.contains("Skriv et gyldig tall over 0"))
        value.tap()
        value.typeText(XCUIKeyboardKey.delete.rawValue + "72,25")
        picker.swipeDown()
        picker.swipeDown()
        app.buttons["measurement-picker-apply"].tap()
        XCTAssertTrue(weight.waitForExistence(timeout: 3))
        XCTAssertTrue(weight.label.contains("72,25"))
        app.navigationBars["Personlige detaljer"].buttons["Avbryt"].tap()
        details.tap()
        XCTAssertEqual(app.buttons["personal-details-weight"].label, original)
        app.navigationBars["Personlige detaljer"].buttons["Avbryt"].tap()
    }

    @MainActor
    func testMeasurementRulerAdjustsAndSheetCancelKeepsOriginalValue() {
        let app = XCUIApplication()
        app.launchArguments += ["--skip-auth", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        app.buttons["Profil"].tap()
        app.buttons["profile-personal-details"].tap()
        let height = app.buttons["personal-details-height"]
        for _ in 0..<20 {
            if height.isHittable && height.frame.maxY < app.frame.height * 0.55 { break }
            // Keep the gesture above the persistent menu at accessibility sizes.
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2)))
        }
        let original = height.label
        let before = XCTAttachment(screenshot: app.screenshot())
        before.name = "Høyderad før åpning med stor tekst"
        before.lifetime = .keepAlways
        add(before)
        height.tap()
        let value = app.textFields["measurement-picker-value"]
        XCTAssertTrue(value.waitForExistence(timeout: 3))
        let ruler = app.descendants(matching: .any)["measurement-picker-ruler"].firstMatch
        let sheet = app.scrollViews["measurement-picker-sheet"]
        for _ in 0..<6 {
            if ruler.exists && ruler.isHittable { break }
            sheet.swipeUp()
        }
        XCTAssertTrue(ruler.waitForExistence(timeout: 3))
        let initialValue = value.value as? String
        ruler.swipeLeft()
        XCTAssertNotEqual(value.value as? String, initialValue)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Høydevelger med stor tekst"
        attachment.lifetime = .keepAlways
        add(attachment)
        for _ in 0..<6 {
            if sheet.buttons["Avbryt"].isHittable { break }
            sheet.swipeDown()
        }
        sheet.buttons["Avbryt"].tap()
        XCTAssertTrue(height.waitForExistence(timeout: 3))
        XCTAssertEqual(height.label, original)
    }

    @MainActor
    func testProfileNavigationWithLargeText() {
        let app = XCUIApplication()
        app.launchArguments += ["--skip-auth", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        app.buttons["Profil"].tap()
        let details = app.buttons["profile-personal-details"]
        XCTAssertTrue(details.waitForExistence(timeout: 3))
        XCTAssertTrue(details.isHittable)
        details.tap()
        XCTAssertTrue(app.navigationBars["Personlige detaljer"].waitForExistence(timeout: 3))
        app.navigationBars["Personlige detaljer"].buttons["Avbryt"].tap()
        let settings = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Innstillinger'")).firstMatch
        for _ in 0..<8 {
            if settings.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(settings.isHittable)
        settings.tap()
        XCTAssertTrue(app.navigationBars["Innstillinger"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["Personlige detaljer"].exists)
        let privacy = app.buttons["Personvern og valg"]
        XCTAssertTrue(privacy.waitForExistence(timeout: 3))
        privacy.tap()
        XCTAssertTrue(app.navigationBars["Personvern og valg"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.navigationBars.buttons["Innstillinger"].exists)
        XCTAssertFalse(app.switches["Del anonym bruksstatistikk"].exists)
        XCTAssertFalse(app.switches["Del anonyme krasjrapporter"].exists)
        let status = app.descendants(matching: .any)["privacy-telemetry-status"]
        for _ in 0..<8 {
            if status.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(status.exists)
    }
}
