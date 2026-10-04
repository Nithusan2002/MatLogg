import XCTest

@MainActor
final class PortionLoggingUITests: XCTestCase {
    func testProcessingSheetPreservesPortionAndMeal() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--skip-auth", "--portion-qa", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
        app.launch()
        openBreakfast(app)
        let add = app.buttons["meal-room-add"]
        reveal(add, in: app)
        add.tap()
        app.buttons["Søk etter mat"].tap()
        let search = app.textFields["food-search-field"]
        XCTAssertTrue(search.waitForExistence(timeout: 8))
        search.tap()
        search.typeText("Porsjonstestbrød")
        if app.buttons["Search"].exists { app.buttons["Search"].tap() }
        let result = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'food-search-' AND label CONTAINS[c] 'Porsjonstestbrød'")).firstMatch
        reveal(result, in: app)
        result.tap()
        let processing = app.buttons["productProcessingInfo"]
        reveal(processing, in: app)
        let total = app.staticTexts["portion-total"]
        XCTAssertTrue(total.waitForExistence(timeout: 5))
        let originalTotal = total.label
        let nutriScore = app.buttons["productNutriScoreInfo"]
        reveal(nutriScore, in: app)
        XCTAssertFalse(app.staticTexts["398 kJ"].exists)
        nutriScore.tap()
        XCTAssertTrue(app.images["nutriscore-logo"].waitForExistence(timeout: 5))
        reveal(app.staticTexts["nutriscore-estimated"], in: app)
        reveal(app.staticTexts["398 kJ"], in: app)
        let proteinInfo = app.buttons["nutriscore-protein-explanation"]
        reveal(proteinInfo, in: app)
        proteinInfo.tap()
        XCTAssertTrue(app.alerts["Protein i Nutri-Score"].waitForExistence(timeout: 5))
        app.alerts["Protein i Nutri-Score"].buttons["Lukk"].tap()
        let logoAttachment = XCTAttachment(screenshot: app.screenshot())
        logoAttachment.name = "Nutri-Score – offisiell grafikk"
        logoAttachment.lifetime = .keepAlways
        self.add(logoAttachment)
        app.buttons["nutriscore-info-close"].tap()
        processing.tap()
        XCTAssertTrue(app.staticTexts["Ultraprosessert · NOVA 4"].waitForExistence(timeout: 5))
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Bearbeidingsgrad – forklaringsark"
        attachment.lifetime = .keepAlways
        self.add(attachment)
        app.buttons["processing-info-close"].tap()
        reveal(total, in: app)
        XCTAssertEqual(total.label, originalTotal)
        app.buttons["product-log-save"].tap()
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'meal-room-row-' AND label CONTAINS 'Polarbrød'")).firstMatch
        reveal(row, in: app)
        XCTAssertTrue(app.staticTexts["meal-room-heading-frokost"].exists)
    }

    func testTwoPiecesSurviveRelaunchAndEditToThree() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--skip-auth", "--portion-qa", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
        app.launch()
        openBreakfast(app)
        let add = app.buttons["meal-room-add"]
        reveal(add, in: app)
        add.tap()
        app.buttons["Søk etter mat"].tap()
        let search = app.textFields["food-search-field"]
        XCTAssertTrue(search.waitForExistence(timeout: 8))
        search.tap()
        search.typeText("Porsjonstestbrød")
        let result = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'food-search-' AND label CONTAINS[c] 'Porsjonstestbrød'")).firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 8))
        reveal(result, in: app)
        result.tap()
        let increase = app.buttons["portion-increase"]
        reveal(increase, in: app)
        let count = app.textFields["Antall"]
        reveal(count, in: app)
        count.tap()
        count.typeText("1")
        if app.buttons["Ferdig"].exists { app.buttons["Ferdig"].tap() }
        reveal(increase, in: app)
        increase.tap()
        XCTAssertTrue(app.staticTexts["portion-total"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["portion-total"].label.contains("2 Polarbrød · 75 g"), app.staticTexts["portion-total"].label)
        app.buttons["product-log-save"].tap()
        let two = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'meal-room-row-' AND label CONTAINS '2 Polarbrød'")).firstMatch
        reveal(two, in: app)
        let loggedRowID = two.identifier
        app.terminate()
        app.launchArguments[app.launchArguments.count - 1] = "UICTContentSizeCategoryAccessibilityXXXL"
        app.launch()
        openBreakfast(app)
        reveal(two, in: app)
        two.tap()
        XCTAssertTrue(app.staticTexts["portion-total"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["portion-total"].label.contains("2 Polarbrød · 75 g"), app.staticTexts["portion-total"].label)
        reveal(increase, in: app)
        increase.tap()
        reveal(app.staticTexts["portion-total"], in: app)
        XCTAssertTrue(app.staticTexts["portion-total"].label.contains("3 Polarbrød · 112,5 g"), app.staticTexts["portion-total"].label)
        app.buttons["Lagre endringer"].tap()
        let three = app.buttons[loggedRowID]
        reveal(three, in: app)
        XCTAssertTrue(three.label.contains("3 Polarbrød"))
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Porsjonslogging – tre brød med stor tekst"
        attachment.lifetime = .keepAlways
        self.add(attachment)
    }

    private func openBreakfast(_ app: XCUIApplication) {
        let breakfast = app.buttons["home-meal-open-frokost"]
        XCTAssertTrue(breakfast.waitForExistence(timeout: 8))
        reveal(breakfast, in: app)
        breakfast.tap()
        XCTAssertTrue(app.staticTexts["meal-room-heading-frokost"].waitForExistence(timeout: 5))
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        _ = element.waitForExistence(timeout: 5)
        for _ in 0..<10 {
            if element.exists && element.isHittable { return }
            let scroll = app.scrollViews["log-editor-scroll"]
            if scroll.exists {
                let upwards = !element.exists || element.frame.midY >= scroll.frame.midY
                let start = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: upwards ? 0.65 : 0.4))
                let end = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: upwards ? 0.4 : 0.65))
                start.press(forDuration: 0.1, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.1)
            } else { app.swipeUp() }
        }
        let failure = XCTAttachment(screenshot: app.screenshot())
        failure.lifetime = .keepAlways
        add(failure)
        print(app.debugDescription)
        XCTAssertTrue(element.isHittable)
    }
}
