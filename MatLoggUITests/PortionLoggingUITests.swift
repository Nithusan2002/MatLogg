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
        app.launchArguments = ["--portion-qa", "-ml_local_profile", "", "-ml_local_mode_active", "NO",
                               "-demoModeActive", "NO", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
        app.launch()
        XCTAssertTrue(app.buttons["onboarding-skip-intro"].waitForExistence(timeout: 10))
        app.buttons["onboarding-skip-intro"].tap()
        XCTAssertTrue(app.buttons["first-log-skip"].waitForExistence(timeout: 8))
        app.buttons["first-log-skip"].tap()
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
        app.launchArguments = ["--portion-qa", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        openBreakfast(app)
        reveal(two, in: app)
        two.tap()
        XCTAssertTrue(app.scrollViews["log-editor-scroll"].waitForExistence(timeout: 5))
        reveal(app.staticTexts["portion-total"], in: app)
        XCTAssertTrue(app.staticTexts["portion-total"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["portion-total"].label.contains("2 Polarbrød · 75 g"), app.staticTexts["portion-total"].label)
        reveal(increase, in: app)
        increase.tap()
        reveal(app.staticTexts["portion-total"], in: app)
        let updatedTotal = NSPredicate(format: "label CONTAINS %@", "3 Polarbrød · 112,5 g")
        expectation(for: updatedTotal, evaluatedWith: app.staticTexts["portion-total"])
        waitForExpectations(timeout: 5)
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
            let editor = app.scrollViews["log-editor-scroll"]
            let scroll = editor.exists ? editor : app.scrollViews["product-detail-scroll"]
            if !scroll.exists {
                let tab = app.buttons["tab-log-food"]
                if element.exists && element.isHittable && element.frame.minY >= 102
                    && element.frame.maxY < (tab.exists ? tab.frame.minY : app.frame.maxY) { return }
                if element.exists && element.frame.midY < app.frame.midY { app.swipeDown() }
                else { app.swipeUp() }
                continue
            }
            var visibleFrame = scroll.frame.intersection(app.frame)
            let save = editor.exists ? app.buttons["Lagre endringer"] : app.buttons["product-log-save"]
            if save.exists && save.frame.minY > visibleFrame.minY {
                visibleFrame.size.height = min(visibleFrame.maxY, save.frame.minY) - visibleFrame.minY
            }
            if element.exists && element.isHittable {
                if !scroll.exists || (element.frame.minY >= visibleFrame.minY + 8
                    && element.frame.maxY <= visibleFrame.maxY - 8) { return }
            }
            if scroll.exists {
                let upwards = !element.exists || element.frame.midY >= visibleFrame.midY
                let origin = app.coordinate(withNormalizedOffset: .zero)
                let start = origin.withOffset(CGVector(dx: visibleFrame.minX + 8,
                    dy: visibleFrame.minY + visibleFrame.height * (upwards ? 0.65 : 0.4)))
                let end = origin.withOffset(CGVector(dx: visibleFrame.minX + 8,
                    dy: visibleFrame.minY + visibleFrame.height * (upwards ? 0.4 : 0.65)))
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
