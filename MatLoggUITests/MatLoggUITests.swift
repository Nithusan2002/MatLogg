//
//  MatLoggUITests.swift
//  MatLoggUITests
//
//  Created by Nithusan Krishnasamymudali on 21/01/2026.
//

import XCTest

final class MatLoggUITests: XCTestCase {
    @MainActor
    func testBottomBarKeepsEveryActionVisibleWithLargestText() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["--skip-auth", "-demoModeActive", "NO",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()

        let logging = app.buttons["tab-log-food"]
        XCTAssertTrue(logging.waitForExistence(timeout: 15))
        let labels = ["Hjem", "Søk", "tab-log-food", "Utvikling", "Profil"]
        let buttons = labels.map { app.buttons[$0].firstMatch }
        for (label, button) in zip(labels, buttons) {
            XCTAssertTrue(button.isHittable, "\(label) must be reachable without scrolling the bar")
            if button.exists {
                XCTAssertTrue(app.frame.contains(button.frame), "\(label) must fit on screen")
                XCTAssertGreaterThanOrEqual(button.frame.width, 44)
                XCTAssertGreaterThanOrEqual(button.frame.height, 44)
            }
        }
        guard buttons.allSatisfy(\.isHittable) else { return }
        for (index, button) in buttons.enumerated() {
            for other in buttons.dropFirst(index + 1) {
                XCTAssertFalse(button.frame.intersects(other.frame), "Bottom bar buttons must not overlap")
            }
        }

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Bunnmeny – største tekst"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        for label in ["Søk", "Utvikling", "Profil", "Hjem"] {
            let button = app.buttons[label].firstMatch
            button.tap()
            XCTAssertTrue(button.isSelected, "\(label) must become the selected tab")
        }
        logging.tap()
        XCTAssertTrue(app.navigationBars["Loggfør"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testPendingAccountLinkResumesAfterRestartAndPreservesLog() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["--local-link-qa", "--local-link-qa-reset"]
        app.launch()
        XCTAssertTrue(app.alerts["Knytt lokale data til kontoen?"].waitForExistence(timeout: 15))
        app.terminate()
        app.launchArguments = ["--local-link-qa"]
        app.launch()
        let confirmation = app.alerts["Knytt lokale data til kontoen?"]
        XCTAssertTrue(confirmation.waitForExistence(timeout: 15))
        XCTAssertTrue(confirmation.staticTexts.matching(NSPredicate(format: "label CONTAINS '1 loggføringer'")).firstMatch.exists)
        confirmation.buttons["Knytt til konto"].tap()
        XCTAssertTrue(app.buttons["home-diary-menu"].waitForExistence(timeout: 10))
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["home-diary-menu"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.alerts["Knytt lokale data til kontoen?"].exists)
        XCTAssertTrue(app.staticTexts["Kontokobling testmat"].firstMatch.waitForExistence(timeout: 8))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Kontokobling etter omstart – bevart logg"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }


    @MainActor
    func testLegacyDetailsRequireExplicitRecovery() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["--local-link-qa", "--local-link-qa-reset", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        let link = app.alerts["Knytt lokale data til kontoen?"]
        XCTAssertTrue(link.waitForExistence(timeout: 15))
        link.buttons["Knytt til konto"].tap()
        XCTAssertTrue(app.buttons["Profil"].waitForExistence(timeout: 10))
        app.buttons["Profil"].tap()
        app.buttons["profile-personal-details"].tap()
        let recovery = app.buttons["personal-details-recover-legacy"]
        XCTAssertTrue(recovery.waitForExistence(timeout: 8))
        let name = app.textFields["personal-details-name"]
        XCTAssertNotEqual(name.value as? String, "Eldre testnavn")
        recovery.tap()
        let confirmation = app.alerts["Tilhører opplysningene denne profilen?"]
        XCTAssertTrue(confirmation.waitForExistence(timeout: 5))
        confirmation.buttons["Avbryt"].tap()
        XCTAssertNotEqual(name.value as? String, "Eldre testnavn")
        recovery.tap()
        confirmation.buttons["Knytt til denne profilen"].tap()
        XCTAssertEqual(name.value as? String, "Eldre testnavn")
        XCTAssertFalse(recovery.exists)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Eksplisitt gjenoppretting – største tekst"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testPreparedProductUsesCookedWeightAndLogs() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["--skip-auth", "--prepared-nutrition-qa", "-demoModeActive", "NO"]
        app.launch()
        XCTAssertTrue(app.buttons["Søk"].waitForExistence(timeout: 10))
        app.buttons["Søk"].tap()
        let search = app.textFields["food-search-field"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("Tilberedte testnudler")
        let result = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'food-search-' AND label CONTAINS[c] 'Tilberedte testnudler'")).firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 8))
        if app.buttons["Ferdig"].exists { app.buttons["Ferdig"].tap() }
        result.tap()
        let notice = app.descendants(matching: .any)["prepared-nutrition-notice"].firstMatch
        XCTAssertTrue(notice.waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Gram tilberedt mat"].exists)
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Hel pakke'")).firstMatch.exists)
        let amount = app.textFields["Mengde"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        amount.tap()
        amount.typeText("200")
        if app.buttons["Ferdig"].exists { app.buttons["Ferdig"].tap() }
        XCTAssertEqual(amount.value as? String, "200 g")
        let save = app.buttons["product-log-save"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        XCTAssertTrue(save.isEnabled)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Tilberedt produkt – 200 g og tydelig næringsgrunnlag"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        save.tap()
        XCTAssertTrue(app.descendants(matching: .any)["log-receipt"].firstMatch.waitForExistence(timeout: 8))
    }




    @MainActor
    func testManualBarcodeEntryWithoutCameraValidatesAndCancels() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["--skip-auth", "-demoModeActive", "NO", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.buttons["Søk"].waitForExistence(timeout: 8))
        app.buttons["Søk"].tap()
        let scan = app.buttons.matching(NSPredicate(format: "label == 'Skann strekkode' OR label == 'Skann'")).firstMatch
        XCTAssertTrue(scan.waitForExistence(timeout: 5))
        for _ in 0..<5 {
            if scan.isHittable && scan.frame.minY >= 130 && scan.frame.maxY < app.frame.height * 0.75 { break }
            if scan.frame.minY < 130 {
                app.collectionViews.firstMatch.swipeDown()
            } else {
                app.collectionViews.firstMatch.swipeUp()
            }
        }
        let cameraEntryScreenshot = XCTAttachment(screenshot: app.screenshot())
        cameraEntryScreenshot.name = "Skann-inngang med stor tekst"
        cameraEntryScreenshot.lifetime = .keepAlways
        add(cameraEntryScreenshot)
        scan.tap()
        let enter = app.buttons["Skriv inn strekkode"]
        for _ in 0..<5 {
            if enter.exists && enter.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(enter.waitForExistence(timeout: 5))
        enter.tap()
        let field = app.textFields["manualBarcodeInput"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("7035620067708")
        let done = app.buttons["manual-barcode-keyboard-done"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        done.tap()
        let keyboardClosed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: app.keyboards.firstMatch)
        XCTAssertEqual(XCTWaiter.wait(for: [keyboardClosed], timeout: 5), .completed)
        XCTAssertEqual(field.value as? String, "7035620067708")
        let find = app.buttons["findManualBarcode"]
        let form = app.collectionViews["manual-barcode-form"]
        XCTAssertTrue(form.waitForExistence(timeout: 5))
        func scrollForm(up: Bool) {
            let keyboardTop = app.keyboards.firstMatch.exists ? app.keyboards.firstMatch.frame.minY : app.frame.maxY
            let top = max(form.frame.minY, app.navigationBars["Skriv inn strekkode"].frame.maxY) + 16
            let bottom = min(form.frame.maxY, keyboardTop) - 16
            let origin = form.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0))
            let start = origin.withOffset(CGVector(dx: 0, dy: (up ? bottom : top) - form.frame.minY))
            let end = origin.withOffset(CGVector(dx: 0, dy: (up ? top : bottom) - form.frame.minY))
            start.press(forDuration: 0.1, thenDragTo: end)
        }
        for _ in 0..<8 {
            let bottom = app.keyboards.firstMatch.exists ? app.keyboards.firstMatch.frame.minY : app.frame.maxY
            if find.isHittable && find.frame.minY >= form.frame.minY && find.frame.maxY < bottom { break }
            scrollForm(up: true)
        }
        XCTAssertTrue(find.isHittable)
        if app.keyboards.firstMatch.exists { XCTAssertLessThan(find.frame.maxY, app.keyboards.firstMatch.frame.minY) }
        find.tap()
        let validation = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Kontroller nummeret.'")).firstMatch
        for _ in 0..<8 {
            if validation.exists { break }
            scrollForm(up: false)
        }
        XCTAssertTrue(validation.waitForExistence(timeout: 5))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Strekkodeinntasting – stor tekst og validering"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.buttons["Avbryt"].firstMatch.tap()
        XCTAssertTrue(enter.waitForExistence(timeout: 5))
        XCTAssertFalse(field.exists)
    }

    @MainActor
    func testManualBarcodeFindsLocalDemoProductAndLogs() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["--skip-auth", "-demoModeActive", "YES"]
        app.launch()
        XCTAssertTrue(app.buttons["Søk"].waitForExistence(timeout: 10))
        app.buttons["Søk"].tap()
        let scan = app.buttons.matching(NSPredicate(format: "label == 'Skann strekkode' OR label == 'Skann'")).firstMatch
        XCTAssertTrue(scan.waitForExistence(timeout: 5))
        scan.tap()
        let enter = app.buttons["Skriv inn strekkode"]
        XCTAssertTrue(enter.waitForExistence(timeout: 8))
        if !enter.isHittable { app.swipeUp() }
        enter.tap()
        let field = app.textFields["manualBarcodeInput"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("7044416013141")
        app.buttons["findManualBarcode"].tap()
        let logButton = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Legg til '")).firstMatch
        XCTAssertTrue(logButton.waitForExistence(timeout: 8))
        XCTAssertTrue(app.descendants(matching: .any)["product-hero-image"].firstMatch.waitForExistence(timeout: 8))
        let productScreenshot = XCTAttachment(screenshot: app.screenshot())
        productScreenshot.name = "Strekkodetreff før logging"
        productScreenshot.lifetime = .keepAlways
        add(productScreenshot)
        let productTitle = app.staticTexts.matching(NSPredicate(format: "label ==[c] %@", "Lettkokte havregryn")).firstMatch
        XCTAssertTrue(productTitle.waitForExistence(timeout: 5))
        logButton.tap()
        XCTAssertTrue(app.descendants(matching: .any)["log-receipt"].firstMatch.waitForExistence(timeout: 8))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Strekkodeinntasting – lokal vare loggført"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testWholeDayCopyOffersUndoOnHome() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--skip-auth", "--portion-qa", "-demoModeActive", "NO",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
        app.launch()
        let ready = app.buttons["home-select"]
        XCTAssertTrue(ready.waitForExistence(timeout: 15))
        selectPreviousDiaryDay(in: app)
        logPortionTestBread(in: app, returningTo: ready)
        let close = app.buttons["log-receipt-close"]
        if close.exists { close.tap() }
        let today = app.buttons["home-go-to-today"]
        revealDiaryElement(today, in: app)
        today.tap()
        revealDiaryElement(ready, in: app)
        app.buttons["home-diary-menu"].tap()
        let copy = app.buttons["Kopier hele dagen fra i går"]
        XCTAssertTrue(copy.waitForExistence(timeout: 5))
        copy.tap()
        let receipt = app.otherElements.matching(identifier: "log-receipt")
            .containing(.staticText, identifier: "Dagen fra i går er kopiert").firstMatch
        XCTAssertTrue(receipt.waitForExistence(timeout: 5))
        receipt.buttons["Angre"].tap()
        let undone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: receipt)
        XCTAssertEqual(XCTWaiter.wait(for: [undone], timeout: 5), .completed)
        XCTAssertTrue(app.buttons["tab-log-food"].exists)
        attachSearchScreenshot(app, name: "Hjem – hele dagen kopiert og angret")
    }

    @MainActor
    func testHomeDiaryMenuOffersSavedMealsAndDayActions() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--skip-auth", "--portion-qa", "-demoModeActive", "NO"]
        app.launch()
        XCTAssertTrue(app.buttons["home-select"].waitForExistence(timeout: 15))
        revealDiaryElement(app.buttons["home-select"], in: app)
        app.buttons["home-diary-menu"].tap()
        XCTAssertTrue(app.buttons["Lagre som måltid"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Gå til i dag"].exists)
    }

    @MainActor
    func testHomeShowsAllMealRowsAndCanCollapseWithoutLosingAddAction() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--skip-auth", "--portion-qa", "-demoModeActive", "NO"]
        app.launch()
        let ready = app.buttons["home-diary-menu"]
        XCTAssertTrue(ready.waitForExistence(timeout: 15))
        let emptyDay = app.buttons["home-log-food"]
        for _ in 0..<12 {
            if emptyDay.exists { break }
            selectPreviousDiaryDay(in: app)
        }
        XCTAssertTrue(emptyDay.exists, "Regresjonstesten skal bruke en tom QA-dag.")
        let add = app.buttons["home-meal-add-frokost"]
        revealDiaryElement(add, in: app)
        add.tap()
        app.buttons["Lukk"].tap()
        for _ in 0..<4 { logPortionTestBread(in: app, returningTo: ready) }
        let close = app.buttons["log-receipt-close"]
        if close.exists { close.tap() }
        let rows = app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH 'home-log-row-' AND label CONTAINS[c] 'Porsjonstestbrød'"))
        revealDiaryElement(rows.firstMatch, in: app)
        XCTAssertGreaterThanOrEqual(rows.count, 4, "Alle registreringer må vises, også den fjerde.")
        let nutrition = app.descendants(matching: .any)["home-meal-nutrition-frokost"].firstMatch
        revealDiaryElement(nutrition, in: app)
        let expandedNutrition = nutrition.label
        for nutrient in ["kilokalorier", "proteiner", "karbohydrater", "fett"] {
            XCTAssertTrue(expandedNutrition.contains(nutrient))
        }
        let meal = app.buttons["home-meal-open-frokost"]
        revealDiaryElement(meal, in: app)
        meal.tap()
        XCTAssertEqual(meal.value as? String, "Sammenfoldet")
        XCTAssertTrue(nutrition.waitForExistence(timeout: 5))
        XCTAssertEqual(nutrition.label, expandedNutrition, "Samme næringsinnhold skal vises når matvarelisten er skjult.")
        XCTAssertEqual(rows.count, 0)
        XCTAssertTrue(add.isHittable)
        meal.tap()
        XCTAssertEqual(meal.value as? String, "Utvidet")
        XCTAssertGreaterThanOrEqual(rows.count, 4)
        meal.tap()
        add.tap()
        XCTAssertTrue(app.buttons["Logg til Frokost"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Logg til Frokost"].isSelected)
        app.buttons["Lukk"].tap()
        XCTAssertEqual(meal.value as? String, "Utvidet")
        attachSearchScreenshot(app, name: "Hjem – full dagslogg og sammenleggbare måltider")
    }

    @MainActor
    func testHomeSwipeDeletesOnlySelectedRegistrationAndOffersUndo() {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["--skip-auth", "--portion-qa"]
        app.launch()
        let dailyLog = app.buttons["home-diary-menu"]
        XCTAssertTrue(dailyLog.waitForExistence(timeout: 10))
        let emptyDay = app.buttons["home-log-food"]
        for _ in 0..<7 {
            if emptyDay.exists { break }
            app.buttons["Forrige dag"].tap()
        }
        XCTAssertTrue(emptyDay.exists)
        for _ in 0..<2 { logPortionTestBread(in: app, returningTo: dailyLog) }
        let closeReceipt = app.buttons["log-receipt-close"]
        if closeReceipt.exists { closeReceipt.tap() }

        let rows = app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH 'home-log-row-' AND label CONTAINS[c] 'Porsjonstestbrød'"))
        revealDiaryElement(rows.firstMatch, in: app)
        let hasTwoRows = NSPredicate(format: "count == 2")
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: hasTwoRows, object: rows)],
                                     timeout: 8), .completed)
        let target = app.buttons[rows.element(boundBy: 0).identifier]
        let duplicate = app.buttons[rows.element(boundBy: 1).identifier]
        let mealTotals = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH 'Totalt for '"))
        let originalTotals = mealTotals.allElementsBoundByIndex.map(\.label)
        XCTAssertFalse(originalTotals.isEmpty)
        for _ in 0..<6 {
            if target.frame.midY < app.frame.height * 0.68 { break }
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.68))
                .press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.48)))
        }
        XCTAssertTrue(target.isHittable)
        XCTAssertLessThan(target.frame.midY, app.frame.height * 0.68)
        let startingY = target.frame.midY
        target.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.1, thenDragTo: target.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                .withOffset(CGVector(dx: 0, dy: -60)))
        XCTAssertLessThan(target.frame.midY, startingY - 20)
        let delete = app.buttons["Slett"]
        XCTAssertFalse(delete.exists)
        revealDiaryElement(target, in: app)
        target.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5))
            .press(forDuration: 0.05, thenDragTo: target.coordinate(withNormalizedOffset: CGVector(dx: 0.38, dy: 0.5)),
                   withVelocity: .slow, thenHoldForDuration: 0.15)
        XCTAssertTrue(delete.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Rediger"].exists)
        XCTAssertTrue(app.buttons["Flytt"].exists)
        XCTAssertTrue(target.exists)
        XCTAssertTrue(duplicate.exists)

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Hjem – Rediger, Flytt og Slett"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        delete.tap()
        let receipt = app.otherElements.matching(identifier: "log-receipt")
            .containing(.staticText, identifier: "Varen er slettet").firstMatch
        XCTAssertTrue(receipt.waitForExistence(timeout: 5))
        XCTAssertFalse(target.exists)
        XCTAssertTrue(duplicate.exists)
        XCTAssertNotEqual(mealTotals.allElementsBoundByIndex.map(\.label), originalTotals)
        receipt.buttons["Angre"].tap()
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: hasTwoRows, object: rows)],
                                     timeout: 8), .completed)
        XCTAssertTrue(duplicate.exists)
        XCTAssertFalse(target.exists) // Undo restores the entry with a fresh ID.
        XCTAssertEqual(mealTotals.allElementsBoundByIndex.map(\.label), originalTotals)

        revealDiaryElement(app.buttons["home-select"], in: app)
        let diaryRows = app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH 'home-log-row-' AND label CONTAINS[c] 'Porsjonstestbrød'"))
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: hasTwoRows, object: diaryRows)],
                                     timeout: 8), .completed)
    }

    @MainActor
    func testDiarySelectionDeletesAndRestoresWholeBatch() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = try prepareDiarySelection()
        let rows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'home-log-row-' AND label CONTAINS[c] 'Porsjonstestbrød'"))
        // Selection changes the visible list. Capture IDs while both saved rows are present.
        let populated = NSPredicate(format: "count >= 2")
        if !populated.evaluate(with: rows) { app.swipeUp() }
        let ready = XCTNSPredicateExpectation(predicate: populated, object: rows)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 8), .completed)
        let rowIDs = rows.allElementsBoundByIndex.map(\.identifier)
        XCTAssertGreaterThanOrEqual(rowIDs.count, 2)
        guard rowIDs.count >= 2 else { return }
        let firstID = rowIDs[rowIDs.count - 1]
        let secondID = rowIDs[rowIDs.count - 2]
        let originalCount = rowIDs.count
        revealDiaryElement(app.buttons["home-select"], in: app)
        app.buttons["home-select"].tap()
        XCTAssertTrue(app.otherElements["meal-room-selection-bar"].exists)
        XCTAssertFalse(app.buttons["tab-log-food"].exists)
        revealDiaryElement(app.buttons[firstID], in: app)
        app.buttons[firstID].tap()
        revealDiaryElement(app.buttons[secondID], in: app)
        app.buttons[secondID].tap()
        XCTAssertTrue(app.staticTexts["2 valgt"].exists)
        app.buttons["meal-room-delete-selection"].tap()
        XCTAssertTrue(app.buttons["Slett"].waitForExistence(timeout: 5))
        app.buttons["Slett"].tap()
        let deletionReceipt = app.otherElements.matching(identifier: "log-receipt")
            .containing(.staticText, identifier: "2 varer er slettet").firstMatch
        XCTAssertTrue(deletionReceipt.waitForExistence(timeout: 8))
        let undoDeletion = app.buttons["Angre"]
        // The receipt expires after four seconds; verify the result after tapping.
        undoDeletion.tap()
        revealDiaryElement(rows.firstMatch, in: app)
        let restored = NSPredicate(format: "count == %d", originalCount)
        expectation(for: restored, evaluatedWith: rows)
        waitForExpectations(timeout: 8)
        XCTAssertTrue(app.buttons["tab-log-food"].exists)
        XCTAssertFalse(app.buttons[firstID].exists) // Restoration uses fresh IDs.
        XCTAssertFalse(app.buttons[secondID].exists)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Dagbok – samlet Angre"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testDiarySelectionSavesOnlyChosenEntryWithLargeText() throws {
        let app = try prepareDiarySelection(largeText: true)
        revealDiaryElement(app.buttons["home-select"], in: app)
        let select = app.buttons["home-select"]
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: select)
        XCTAssertEqual(XCTWaiter.wait(for: [enabled], timeout: 8), .completed)
        select.tap()
        XCTAssertTrue(app.otherElements["meal-room-selection-bar"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["tab-log-food"].exists)
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'home-log-row-' AND label CONTAINS[c] 'Porsjonstestbrød'")).firstMatch
        revealDiaryElement(row, in: app)
        // At the largest text size the row can be taller than the available area.
        // Tap its upper selection area instead of its potentially obscured midpoint.
        let rowTapY = max(row.frame.minY + 20, app.frame.minY + 120)
        app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: row.frame.minX + 24, dy: rowTapY)).tap()
        XCTAssertTrue(app.staticTexts["1 valgt"].exists)
        app.buttons["meal-room-save-selection"].tap()
        let name = app.textFields["saved-meal-name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        let sourceRows = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'saved-meal-source-row-'"))
        XCTAssertEqual(sourceRows.count, 1)
        let cancel = app.buttons.matching(NSPredicate(
            format: "label == %@ AND identifier != %@", "Avbryt", "home-select")).element
        XCTAssertTrue(app.frame.contains(cancel.frame))
        XCTAssertTrue(cancel.isHittable)
        cancel.tap()
        XCTAssertTrue(app.staticTexts["1 valgt"].waitForExistence(timeout: 5))
        app.buttons["meal-room-save-selection"].tap()
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Dagbok – lagre utvalg med stor tekst"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        name.tap()
        name.typeText("Utvalgstest")
        if app.buttons["Ferdig"].exists { app.buttons["Ferdig"].tap() }
        app.buttons["saved-meal-save"].tap()
        revealDiaryElement(app.buttons["home-select"], in: app)
        XCTAssertTrue(app.buttons["home-select"].waitForExistence(timeout: 8))
        XCTAssertEqual(app.buttons["home-select"].label, "Velg")
        XCTAssertTrue(app.buttons["tab-log-food"].exists)
        revealDiaryElement(row, in: app)
        XCTAssertTrue(row.exists)
        revealDiaryElement(app.buttons["home-select"], in: app)
        app.buttons["home-select"].tap()
        XCTAssertFalse(app.buttons["tab-log-food"].exists)
        revealDiaryElement(app.buttons["home-select"], in: app)
        app.buttons["home-select"].tap()
        XCTAssertTrue(app.buttons["tab-log-food"].exists)
    }

    @MainActor
    private func revealDiaryElement(_ element: XCUIElement, in app: XCUIApplication) {
        func isReachable() -> Bool {
            guard element.exists, element.isHittable else { return false }
            let bar = app.otherElements["meal-room-selection-bar"]
            let navigationTop = ["Hjem", "Søk", "tab-log-food", "Utvikling", "Profil"]
                .map { app.buttons[$0].firstMatch }
                .filter { $0.exists && $0.frame.height > 0 }
                .map { $0.frame.minY }.min() ?? app.frame.maxY - 100
            let bottom = bar.exists ? bar.frame.minY : navigationTop
            return element.frame.minY >= app.frame.minY + 100 && element.frame.maxY <= bottom - 8
        }
        guard !isReachable() else { return }
        // Keep drags above the persistent selection bar, including at accessibility sizes.
        let upper = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25))
        let lower = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55))
        for _ in 0..<8 {
            if isReachable() { return }
            upper.press(forDuration: 0.05, thenDragTo: lower)
        }
        for _ in 0..<24 {
            if isReachable() { return }
            lower.press(forDuration: 0.05, thenDragTo: upper)
        }
        XCTAssertTrue(isReachable())
    }

    @MainActor
    private func prepareDiarySelection(largeText: Bool = false) throws -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--skip-auth", "--portion-qa", "-demoModeActive", "NO", "-UIPreferredContentSizeCategoryName",
            largeText ? "UICTContentSizeCategoryAccessibilityXXXL" : "UICTContentSizeCategoryL"]
        app.launch()
        let dailyLog = app.buttons["home-diary-menu"]
        XCTAssertTrue(dailyLog.waitForExistence(timeout: 10))
        let emptyDay = app.buttons["home-log-food"]
        for _ in 0..<12 {
            if emptyDay.exists { break }
            selectPreviousDiaryDay(in: app)
        }
        XCTAssertTrue(emptyDay.exists)
        let add = app.buttons["home-meal-add-frokost"]
        revealDiaryElement(add, in: app)
        add.tap()
        app.buttons["Lukk"].tap()
        for _ in 0..<2 {
            logPortionTestBread(in: app, returningTo: app.buttons["home-select"])
        }
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'home-log-row-' AND label CONTAINS[c] 'Porsjonstestbrød'")).firstMatch
        for _ in 0..<8 { if row.isHittable { break }; app.swipeUp() }
        return app
    }

    @MainActor
    private func logPortionTestBread(in app: XCUIApplication, returningTo destination: XCUIElement) {
        let openLogging = app.buttons["tab-log-food"]
        openLogging.tap()
        let searchAction = app.textFields["food-search-field"]
        if !searchAction.waitForExistence(timeout: 5) { openLogging.tap() }
        XCTAssertTrue(searchAction.waitForExistence(timeout: 5))
        searchAction.tap()
        let search = app.textFields["food-search-field"]
        XCTAssertTrue(search.waitForExistence(timeout: 8))
        search.tap()
        search.typeText("Porsjonstestbrød")
        if app.buttons["Ferdig"].exists { app.buttons["Ferdig"].tap() }
        let result = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'food-search-' AND label CONTAINS[c] 'Porsjonstestbrød'")).firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 8))
        for _ in 0..<8 { if result.isHittable { break }; app.swipeUp() }
        result.tap()
        let save = app.buttons["product-log-save"]
        XCTAssertTrue(save.waitForExistence(timeout: 8))
        save.tap()
        XCTAssertTrue(app.buttons["tab-log-food"].waitForExistence(timeout: 8))
        revealDiaryElement(app.buttons["home-select"], in: app)
        XCTAssertTrue(destination.exists)
    }

    @MainActor
    func testPilotAccountOffersAppleWithoutEmailForms() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ml_local_profile", "", "-ml_local_mode_active", "NO", "-demoModeActive", "NO"]
        app.launch()
        XCTAssertTrue(app.buttons["onboarding-skip-intro"].waitForExistence(timeout: 10))
        app.buttons["onboarding-skip-intro"].tap()
        XCTAssertTrue(app.buttons["first-log-login"].waitForExistence(timeout: 10))
        app.buttons["first-log-login"].tap()
        XCTAssertTrue(app.buttons["Logg inn med Apple"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.textFields["navn@eksempel.no"].exists)
        XCTAssertFalse(app.secureTextFields["Passord"].exists)
        XCTAssertFalse(app.buttons["Logg inn med e-post"].exists)
        XCTAssertFalse(app.buttons["Ny i Spor Mat? Opprett konto med e-post"].exists)
    }

    @MainActor
    func testMealRoomShowsWholeDayAndMealActionsKeepLoggingContext() throws {
        let app = XCUIApplication()
        app.launchArguments += ["--skip-auth", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
        app.launch()
        let dailyLog = app.buttons["home-diary-menu"]
        XCTAssertTrue(dailyLog.waitForExistence(timeout: 8))
        revealDiaryElement(app.buttons["home-select"], in: app)
        XCTAssertTrue(app.buttons["home-diary-menu"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["meal-room-all"].exists)
        let lunch = app.buttons["home-meal-add-lunsj"]
        for _ in 0..<8 {
            if lunch.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(lunch.isHittable)
        lunch.tap()
        let lunchChoice = app.buttons["Logg til Lunsj"]
        XCTAssertTrue(lunchChoice.waitForExistence(timeout: 5))
        XCTAssertTrue(lunchChoice.isSelected)
        app.buttons["Lukk"].tap()
        selectPreviousDiaryDay(in: app)
        XCTAssertTrue(app.buttons["home-diary-menu"].exists)
    }

    @MainActor
    func testMealRoomLogsAndEditsFoodForSelectedPastDay() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["--skip-auth", "-demoModeActive", "NO", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
        app.launch()
        let breakfast = app.buttons["home-meal-open-frokost"]
        XCTAssertTrue(breakfast.waitForExistence(timeout: 8))
        for _ in 0..<8 {
            if breakfast.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(app.buttons["home-meal-open-frokost"].waitForExistence(timeout: 5))
        selectPreviousDiaryDay(in: app)
        let dateLabel = app.buttons["day-navigation-date"].label
        let addFood = app.buttons["tab-log-food"]
        XCTAssertTrue(addFood.waitForExistence(timeout: 5))
        addFood.tap()
        app.buttons["Logg til Frokost"].tap()
        app.textFields["food-search-field"].tap()
        let search = app.textFields["food-search-field"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("havregryn")
        let result = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Havregryn' AND label CONTAINS 'Matvaretabellen'")).firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        if app.buttons["Ferdig"].exists { app.buttons["Ferdig"].tap() }
        result.tap()
        let save = app.buttons["product-log-save"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        save.tap()
        let closeReceipt = app.buttons["log-receipt-close"]
        if closeReceipt.waitForExistence(timeout: 3) { closeReceipt.tap() }
        let edit = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'home-log-row-' AND label CONTAINS[c] 'Havregryn'")).firstMatch
        revealDiaryElement(edit, in: app)
        XCTAssertTrue(edit.waitForExistence(timeout: 8))
        let loggedRowID = edit.identifier
        revealDiaryElement(app.buttons["day-navigation-date"], in: app)
        XCTAssertEqual(app.buttons["day-navigation-date"].label, dateLabel)
        revealDiaryElement(edit, in: app)
        edit.tap()
        let editor = app.scrollViews["log-editor-scroll"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        let lunchChoice = app.buttons["Flytt til Lunsj"]
        let saveChanges = app.buttons["Lagre endringer"]
        for _ in 0..<5 {
            if lunchChoice.isHittable && lunchChoice.frame.maxY < saveChanges.frame.minY { break }
            editor.swipeUp()
        }
        XCTAssertTrue(lunchChoice.isHittable)
        lunchChoice.tap()
        XCTAssertTrue(lunchChoice.isSelected)
        XCTAssertTrue(saveChanges.isEnabled)
        saveChanges.tap()
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: editor)
        waitForExpectations(timeout: 8)
        let movedRow = app.buttons[loggedRowID]
        revealDiaryElement(movedRow, in: app)
        XCTAssertTrue(movedRow.waitForExistence(timeout: 8))
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Måltidsrom – registrert mat"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testMealRoomEditedPastDaySurvivesRelaunch() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        // Existing synthetic history isolates edit/persistence from food search
        // and creation, which the separate logging test covers.
        app.launchArguments = ["--skip-auth", "-demoModeActive", "YES",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
        app.launch()
        XCTAssertTrue(app.buttons["home-diary-menu"].waitForExistence(timeout: 10))
        selectPreviousDiaryDay(in: app)
        let dateLabel = app.buttons["day-navigation-date"].label
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'home-log-row-'")).firstMatch
        revealDiaryElement(row, in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 8))
        let loggedRowID = row.identifier
        row.tap()
        let editor = app.scrollViews["log-editor-scroll"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        let lunchChoice = app.buttons["Flytt til Lunsj"]
        let breakfastChoice = app.buttons["Flytt til Frokost"]
        let saveChanges = app.buttons["Lagre endringer"]
        for _ in 0..<5 {
            if lunchChoice.isHittable && lunchChoice.frame.maxY < saveChanges.frame.minY { break }
            editor.swipeUp()
        }
        // Always change the meal, including when this synthetic row was moved
        // by an earlier run against the same demo database.
        let moveToBreakfast = lunchChoice.isSelected
        let destination = moveToBreakfast ? breakfastChoice : lunchChoice
        XCTAssertTrue(destination.isHittable)
        destination.tap()
        XCTAssertTrue(destination.isSelected)
        XCTAssertTrue(saveChanges.isEnabled)
        saveChanges.tap()
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: editor)
        waitForExpectations(timeout: 8)
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["home-diary-menu"].waitForExistence(timeout: 10))
        selectPreviousDiaryDay(in: app)
        XCTAssertEqual(app.buttons["day-navigation-date"].label, dateLabel)
        let restoredRow = app.buttons[loggedRowID]
        revealDiaryElement(restoredRow, in: app)
        XCTAssertTrue(restoredRow.waitForExistence(timeout: 8), "Den redigerte matloggen skal overleve omstart med samme ID og dato.")
        restoredRow.tap()
        XCTAssertTrue(app.buttons["Flytt til Frokost"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons[moveToBreakfast ? "Flytt til Frokost" : "Flytt til Lunsj"].isSelected, "Valgt måltid skal være lagret etter omstart.")
    }

    @MainActor
    private func selectPreviousDiaryDay(in app: XCUIApplication) {
        let previousDay = app.buttons["Forrige dag"]
        let date = app.buttons["day-navigation-date"]
        for _ in 0..<8 {
            if previousDay.isHittable {
                let oldLabel = date.label
                previousDay.tap()
                let changed = XCTNSPredicateExpectation(
                    predicate: NSPredicate(format: "label != %@", oldLabel),
                    object: date
                )
                XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 5), .completed)
                return
            }
            app.swipeDown()
        }
        XCTFail("Forrige dag ble ikke synlig under navigasjonslinjen.")
    }

    @MainActor
    func testFirstLoggingWithoutAccountAndRelaunch() throws {
        XCUIDevice.shared.orientation = .portrait
        // Override profile lookup on the first launch only. The newly created
        // profile is persisted normally and restored without overrides below.
        let app = XCUIApplication()
        app.launchArguments = ["-ml_local_profile", "", "-ml_local_mode_active", "NO", "-demoModeActive", "NO"]
        app.launch()
        XCTAssertTrue(app.buttons["onboarding-next"].waitForExistence(timeout: 10))
        app.swipeLeft()
        XCTAssertTrue(app.buttons["onboarding-start-logging"].waitForExistence(timeout: 5))
        app.swipeRight()
        XCTAssertTrue(app.buttons["onboarding-next"].waitForExistence(timeout: 5))
        app.buttons["onboarding-next"].tap()
        let start = app.buttons["onboarding-start-logging"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        XCTAssertFalse(app.keyboards.firstMatch.exists)
        start.tap()
        let field = app.textFields["food-search-field"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["local-storage-explanation"].exists)
        XCTAssertTrue(app.buttons["first-log-login"].exists)
        XCTAssertTrue(app.buttons["first-log-skip"].exists)
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        app.buttons["Ferdig"].tap()
        let keyboardDismissed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"), object: app.keyboards.firstMatch
        )
        XCTAssertEqual(XCTWaiter.wait(for: [keyboardDismissed], timeout: 5), .completed)
        field.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        field.typeText("havregryn")
        let result = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Havregryn' AND label CONTAINS 'Matvaretabellen'")).firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 10))
        XCTAssertTrue(result.isHittable, "Lokale treff skal kunne velges mens tastaturet er åpent.")
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Første logging – lokale treff med tastatur"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        result.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.3)).tap()
        let save = app.buttons["product-log-save"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        save.tap()
        XCTAssertTrue(app.buttons["Angre"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["first-log-skip"].exists)
        app.buttons["Angre"].tap()
        app.terminate()
        app.launchArguments = []
        app.launch()
        XCTAssertTrue(app.buttons["Profil"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["first-log-skip"].exists)
    }

    @MainActor
    func testUnfinishedOnboardingReturnsToIntroduction() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ml_local_profile", "", "-ml_local_mode_active", "NO", "-demoModeActive", "NO"]
        app.launch()
        XCTAssertTrue(app.buttons["onboarding-next"].waitForExistence(timeout: 10))
        app.buttons["onboarding-next"].tap()
        let start = app.buttons["onboarding-start-logging"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        start.tap()
        XCTAssertTrue(app.textFields["food-search-field"].waitForExistence(timeout: 5))
        app.terminate()
        app.launchArguments = []
        app.launch()
        XCTAssertTrue(app.buttons["onboarding-next"].waitForExistence(timeout: 10))
        app.buttons["onboarding-skip-intro"].tap()
        XCTAssertTrue(app.buttons["first-log-skip"].waitForExistence(timeout: 5))
        app.buttons["first-log-skip"].tap()
        XCTAssertTrue(app.buttons["Profil"].waitForExistence(timeout: 8))
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["Profil"].waitForExistence(timeout: 8))
        XCTAssertFalse(start.exists)
    }

    @MainActor
    func testLocalStorageInformationInProfile() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ml_local_profile", "", "-ml_local_mode_active", "NO", "-demoModeActive", "NO"]
        app.launch()
        XCTAssertTrue(app.buttons["onboarding-skip-intro"].waitForExistence(timeout: 10))
        app.buttons["onboarding-skip-intro"].tap()
        XCTAssertTrue(app.buttons["first-log-skip"].waitForExistence(timeout: 5))
        app.buttons["first-log-skip"].tap()
        XCTAssertTrue(app.buttons["Profil"].waitForExistence(timeout: 8))
        app.buttons["Profil"].tap()
        let settings = app.buttons["Innstillinger"]
        for _ in 0..<5 {
            if settings.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(settings.exists)
        settings.tap()
        let export = app.buttons["Eksporter data"]
        for _ in 0..<5 {
            if export.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(export.isHittable)
        let status = app.staticTexts["Lagret på denne iPhonen"]
        for _ in 0..<5 {
            if status.exists { break }
            app.swipeDown()
        }
        XCTAssertTrue(status.exists)
        let noBackup = app.staticTexts["Ingen skybackup. Data kan gå tapt hvis du sletter appen eller mister telefonen."]
        let noImport = app.staticTexts["Eksporten er en kopi for innsyn og deling. Den kan ikke importeres tilbake i Spor Mat."]
        for _ in 0..<8 {
            if noImport.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(noBackup.exists)
        XCTAssertTrue(noImport.isHittable)
        XCTAssertFalse(app.buttons["Synkroniser ventende endringer"].exists)
        XCTAssertFalse(app.buttons["Prøv denne på nytt"].exists)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Lokal lagring og eksport – Profil"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testFirstLogCanBeSkippedWithLargeText() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ml_local_profile", "", "-ml_local_mode_active", "NO", "-demoModeActive", "NO",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.buttons["onboarding-next"].waitForExistence(timeout: 10))
        app.buttons["onboarding-next"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let start = app.buttons["onboarding-start-logging"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        XCTAssertFalse(app.keyboards.firstMatch.exists)
        start.tap()
        let field = app.textFields["food-search-field"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        // At accessibility sizes, dismiss the keyboard before inspecting the
        // vertically stacked alternatives in the scrollable first-use list.
        if app.keyboards.firstMatch.waitForExistence(timeout: 5) {
            app.buttons["Ferdig"].tap()
        }
        let manual = app.buttons["food-search-manual-registration"]
        for _ in 0..<8 {
            if manual.isHittable { break }
            app.collectionViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(manual.isHittable)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Første logging – stor tekst"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.buttons["first-log-skip"].tap()
        XCTAssertTrue(app.buttons["Profil"].waitForExistence(timeout: 8))
        app.terminate()
        app.launchArguments = []
        app.launch()
        XCTAssertTrue(app.buttons["Profil"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["first-log-skip"].exists)
    }

    @MainActor
    func testDailyLogIsDirectAndSavedMealsRemainDiscoverable() throws {
        let app = XCUIApplication()
        app.launchArguments += ["--skip-auth", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
        app.launch()
        let dailyLog = app.buttons["home-diary-menu"]
        XCTAssertTrue(dailyLog.waitForExistence(timeout: 8))
        revealDiaryElement(app.buttons["home-select"], in: app)
        XCTAssertTrue(app.buttons["home-diary-menu"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["meal-room-all"].exists)
        for meal in ["frokost", "lunsj", "middag", "snacks"] {
            XCTAssertFalse(app.buttons["meal-room-select-" + meal].exists)
        }
        XCTAssertTrue(app.buttons["home-diary-menu"].exists)
        app.buttons["tab-log-food"].tap()
        let savedTab = app.buttons["logging-reuse-saved"]
        XCTAssertTrue(savedTab.waitForExistence(timeout: 5))
        if !savedTab.isHittable { app.swipeUp() }
        savedTab.tap()
        XCTAssertTrue(savedTab.isSelected)
        let scroll = app.collectionViews.firstMatch
        XCTAssertTrue(scroll.exists)
        let bounds = scroll.frame
        let savedFrame = savedTab.frame
        XCTAssertGreaterThanOrEqual(savedFrame.minX, bounds.minX)
        XCTAssertLessThanOrEqual(savedFrame.maxX, bounds.maxX)
        scroll.swipeLeft()
        scroll.swipeRight()
        XCTAssertEqual(savedTab.frame.minX, savedFrame.minX, accuracy: 1)
        XCTAssertTrue(savedTab.isSelected)
        let recentTab = app.buttons["logging-reuse-recent"]
        recentTab.tap()
        XCTAssertTrue(recentTab.isSelected)
        XCTAssertFalse(app.buttons["food-search-saved-meals"].exists)
        XCTAssertFalse(app.staticTexts["Andre hurtigvalg"].exists)
        savedTab.tap()
        let library = app.buttons["food-search-saved-meals"]
        XCTAssertTrue(library.waitForExistence(timeout: 5))
        if !library.isHittable { app.swipeUp() }
        library.tap()
        XCTAssertTrue(app.navigationBars["Lagrede måltider"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testProfileSavedMealsReturnsWithoutChangingDateWithLargestText() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--skip-auth", "-demoModeActive", "NO",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        let previousDay = app.buttons["Forrige dag"]
        XCTAssertTrue(previousDay.waitForExistence(timeout: 10))
        previousDay.tap()
        let selectedDate = app.buttons["day-navigation-date"].label
        app.buttons["Profil"].firstMatch.tap()
        let library = app.buttons["profile-saved-meals"]
        XCTAssertTrue(library.waitForExistence(timeout: 5))
        revealDiaryElement(library, in: app)
        library.tap()
        let navigationBar = app.navigationBars["Lagrede måltider"]
        XCTAssertTrue(navigationBar.waitForExistence(timeout: 5))
        XCTAssertFalse(navigationBar.buttons["Lukk"].exists)
        let back = navigationBar.buttons.firstMatch
        XCTAssertTrue(back.isHittable)
        back.tap()
        XCTAssertTrue(library.waitForExistence(timeout: 5))
        app.buttons["Hjem"].firstMatch.tap()
        XCTAssertEqual(app.buttons["day-navigation-date"].label, selectedDate)
    }

    @MainActor
    func testQuickLogManualOpensDirectlyAndCancelReturnsToQuickMenu() throws {
        let app = XCUIApplication()
        app.launchArguments += ["--skip-auth"]
        app.launch()
        XCTAssertTrue(app.buttons["Forrige dag"].waitForExistence(timeout: 8))
        app.buttons["Forrige dag"].tap()
        let dateLabel = app.buttons["day-navigation-date"].label
        app.buttons["tab-log-food"].tap()
        XCTAssertTrue(app.buttons["food-search-manual-registration"].waitForExistence(timeout: 5))
        app.buttons["food-search-manual-registration"].tap()
        if app.staticTexts["Du har en uferdig registrering"].waitForExistence(timeout: 2) {
            for _ in 0..<2 {
                let discard = try XCTUnwrap(app.buttons.matching(identifier: "Forkast")
                    .allElementsBoundByIndex.first(where: { $0.isHittable }))
                discard.tap()
            }
        }
        XCTAssertTrue(app.navigationBars["Opprett produkt"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.navigationBars["Søk"].exists)
        app.buttons["Lukk"].tap()
        XCTAssertTrue(app.buttons["food-search-manual-registration"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.navigationBars["Søk"].exists)
        app.buttons["logging-done"].tap()
        XCTAssertTrue(app.buttons["day-navigation-date"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["day-navigation-date"].label, dateLabel)
    }

    @MainActor
    func testQuickLogManualRegistrationAndDirectHomeEditingKeepPastDate() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ml_local_profile", "", "-ml_local_mode_active", "NO", "-demoModeActive", "NO",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
        app.launch()
        XCTAssertTrue(app.buttons["onboarding-skip-intro"].waitForExistence(timeout: 10))
        app.buttons["onboarding-skip-intro"].tap()
        XCTAssertTrue(app.buttons["first-log-skip"].waitForExistence(timeout: 5))
        app.buttons["first-log-skip"].tap()
        XCTAssertTrue(app.buttons["Forrige dag"].waitForExistence(timeout: 8))
        app.buttons["Forrige dag"].tap()
        let dateLabel = app.buttons["day-navigation-date"].label
        let addToBreakfast = app.buttons["home-meal-add-frokost"]
        revealDiaryElement(addToBreakfast, in: app)
        addToBreakfast.tap()
        XCTAssertTrue(app.buttons["food-search-manual-registration"].waitForExistence(timeout: 5))
        let breakfast = app.buttons["Logg til Frokost"]
        for _ in 0..<8 {
            if breakfast.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(breakfast.isHittable)
        breakfast.tap()
        XCTAssertTrue(breakfast.isSelected)
        let manual = app.buttons["food-search-manual-registration"]
        for _ in 0..<8 {
            if manual.isHittable { break }
            app.swipeDown()
        }
        manual.tap()
        let name = "Navigasjonstest " + UUID().uuidString.prefix(8)
        XCTAssertTrue(app.textFields["Produktnavn"].waitForExistence(timeout: 8))
        for (label, value) in [("Produktnavn", name), ("Energi", "100"),
                               ("Protein", "2"), ("Karbohydrat", "10"), ("Fett", "4")] {
            for _ in 0..<5 {
                if app.textFields[label].isHittable { break }
                app.swipeUp()
            }
            app.textFields[label].tap()
            app.textFields[label].typeText(value)
        }
        let save = app.buttons["Lagre og velg mengde"]
        for _ in 0..<5 {
            if save.isHittable { break }
            app.swipeUp()
        }
        save.tap()
        let log = app.buttons["logging-draft-save"]
        XCTAssertTrue(log.waitForExistence(timeout: 8))
        log.tap()
        XCTAssertTrue(app.buttons["day-navigation-date"].waitForExistence(timeout: 8))
        XCTAssertEqual(app.buttons["day-navigation-date"].label, dateLabel)
        let closeReceipt = app.buttons["log-receipt-close"]
        if closeReceipt.waitForExistence(timeout: 2) {
            closeReceipt.tap()
            XCTAssertTrue(closeReceipt.waitForNonExistence(timeout: 5))
        }
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'home-log-row-' AND label CONTAINS %@", name)).firstMatch
        revealDiaryElement(row, in: app)
        XCTAssertTrue(row.exists)
        row.staticTexts[name].tap()
        let editor = app.scrollViews["log-editor-scroll"]
        let openedOnFirstTap = editor.waitForExistence(timeout: 5)
        attachSearchScreenshot(app, name: "Redigering – etter første trykk")
        if !openedOnFirstTap {
            let hierarchy = XCTAttachment(string: app.debugDescription)
            hierarchy.name = "Redigering – hierarki ved feil"
            hierarchy.lifetime = .keepAlways
            add(hierarchy)
            row.staticTexts[name].tap()
            let retry = XCTAttachment(string: "Opened on second tap: \(editor.waitForExistence(timeout: 5))")
            retry.name = "Redigering – diagnostisk andretrykk"
            retry.lifetime = .keepAlways
            add(retry)
        }
        XCTAssertTrue(openedOnFirstTap, "Første trykk skal åpne redigering; andretrykk er bare diagnostikk.")
        let lunchChoice = app.buttons["Flytt til Lunsj"]
        for _ in 0..<5 {
            if lunchChoice.isHittable && lunchChoice.frame.maxY < app.buttons["Lagre endringer"].frame.minY { break }
            editor.swipeUp()
        }
        XCTAssertTrue(lunchChoice.isHittable)
        lunchChoice.tap()
        XCTAssertTrue(app.buttons["Lagre endringer"].isEnabled, "Måltidsvalget skal aktivere lagring.")
        app.buttons["Lagre endringer"].tap()
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: editor)
        waitForExpectations(timeout: 8)
        XCTAssertTrue(row.waitForExistence(timeout: 8))
        let lunch = app.buttons["home-meal-open-lunsj"]
        for _ in 0..<8 {
            if lunch.isHittable { break }
            app.swipeUp()
        }
        let moved = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'home-log-row-' AND label CONTAINS %@", name)).firstMatch
        XCTAssertTrue(moved.waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["home-meal-open-lunsj"].exists)
        XCTAssertTrue(app.buttons["day-navigation-date"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["day-navigation-date"].label, dateLabel)
        attachSearchScreenshot(app, name: "Navigasjon – direkte redigering på tidligere dato")
    }

    @MainActor
    func testLogEditorTogglesFavoriteFromHomeAndDiary() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["--skip-auth", "--portion-qa", "-demoModeActive", "NO",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
        app.launch()

        let dailyLog = app.buttons["home-diary-menu"]
        XCTAssertTrue(dailyLog.waitForExistence(timeout: 10))
        logPortionTestBread(in: app, returningTo: dailyLog)
        let closeReceipt = app.buttons["log-receipt-close"]
        if closeReceipt.exists { closeReceipt.tap() }
        let homeRow = app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH 'home-log-row-' AND label CONTAINS[c] 'Porsjonstestbrød'")).firstMatch
        revealDiaryElement(homeRow, in: app)
        XCTAssertTrue(homeRow.waitForExistence(timeout: 8))
        let logID = String(homeRow.identifier.dropFirst("home-log-row-".count))
        homeRow.tap()

        let favorite = app.buttons["log-editor-favorite"]
        let addLabel = "Legg til favoritt"
        let removeLabel = "Fjern fra favoritter"
        func waitForFavorite(_ label: String) {
            expectation(for: NSPredicate(format: "enabled == true AND label == %@", label), evaluatedWith: favorite)
            waitForExpectations(timeout: 5)
        }

        expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: favorite)
        waitForExpectations(timeout: 5)
        XCTAssertGreaterThan(favorite.frame.midX, app.staticTexts["Rediger logging"].frame.midX)
        if favorite.label == removeLabel {
            favorite.tap()
        }
        waitForFavorite(addLabel)
        favorite.tap()
        waitForFavorite(removeLabel)
        XCTAssertFalse(app.buttons["Lagre endringer"].isEnabled)
        attachSearchScreenshot(app, name: "Rediger logging – favoritt")
        app.buttons["Avbryt"].tap()

        revealDiaryElement(app.buttons["home-select"], in: app)
        let diaryRow = app.buttons["home-log-row-\(logID)"]
        revealDiaryElement(diaryRow, in: app)
        XCTAssertTrue(diaryRow.waitForExistence(timeout: 8))
        diaryRow.tap()
        waitForFavorite(removeLabel)
        favorite.tap()
        waitForFavorite(addLabel)
    }

    @MainActor
    func testDebugSessionShowsHomeAndPrimaryNavigation() throws {
        let app = XCUIApplication()
        app.launchArguments.append("--skip-auth")
        app.launch()

        let logButton = app.buttons["tab-log-food"]
        XCTAssertTrue(logButton.waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Profil"].exists)
        XCTAssertFalse(app.buttons["Åpne profil"].exists)
        XCTAssertFalse(app.staticTexts["Spor Mat"].exists)
        XCTAssertFalse(app.buttons["Søk etter mat"].exists)
        XCTAssertFalse(app.buttons["Skann strekkode"].exists)

        logButton.tap()
        XCTAssertTrue(app.navigationBars["Loggfør"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields["food-search-field"].exists)
        XCTAssertTrue(app.buttons["Skann strekkode"].exists)
        XCTAssertTrue(
            app.staticTexts["Måltid"].exists
        )
    }

    @MainActor
    func testSearchTabSupportsLocalSearchAndProductOpening() throws {
        let app = XCUIApplication()
        app.launchArguments.append("--skip-auth")
        app.launch()
        XCTAssertTrue(app.buttons["Søk"].waitForExistence(timeout: 5))
        app.buttons["Søk"].tap()
        let field = app.textFields["food-search-field"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertFalse(app.keyboards.firstMatch.exists)
        XCTAssertFalse(app.staticTexts["Snarveier"].exists)
        attachSearchScreenshot(app, name: "Søk – start")
        field.tap()
        field.typeText("havregryn")
        XCTAssertFalse(app.buttons["Loggfør mat"].exists, "Bunnmenyen skal ikke dekke søketreff over tastaturet.")
        let row = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Havregryn' AND label CONTAINS 'Matvaretabellen'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        attachSearchScreenshot(app, name: "Søk – lokale treff")
        // The keyboard toolbar can overlap the first row's tap point.
        if app.buttons["Ferdig"].exists { app.buttons["Ferdig"].tap() }
        row.tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Legg til '")).firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["product-hero-image"].firstMatch.exists)
        XCTAssertFalse(app.staticTexts["Bilde ikke tilgjengelig"].exists)
        attachSearchScreenshot(app, name: "Søk – mengdevalg")
        if app.buttons["Legg til favoritt"].exists {
            app.buttons["Legg til favoritt"].tap()
        }
        XCTAssertTrue(app.buttons["Fjern fra favoritter"].waitForExistence(timeout: 5))
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Legg til '")).firstMatch.tap()
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        app.buttons["Tøm søket"].tap()
        if app.buttons["Ferdig"].exists { app.buttons["Ferdig"].tap() }
        XCTAssertTrue(app.buttons["Loggfør mat"].waitForExistence(timeout: 5))
        let favorite = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'food-search-favorite-' AND label CONTAINS[c] 'Havregryn'")).firstMatch
        XCTAssertTrue(favorite.waitForExistence(timeout: 5), "Favorittvaren skal være tilgjengelig.")
        // A lazy List need not materialize both sections at the same time.
        let recent = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'food-search-recent-' AND label CONTAINS[c] 'Havregryn'")).firstMatch
        for _ in 0..<6 {
            if recent.exists { break }
            app.collectionViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(recent.exists, "Den loggførte varen skal finnes under Nylig brukt.")
        attachSearchScreenshot(app, name: "Søk – favoritt og nylig brukt")
    }

    @MainActor
    func testSearchManualFallbackSavesAndOpensAmountSelection() throws {
        let app = XCUIApplication()
        app.launchArguments.append("--skip-auth")
        app.launch()
        XCTAssertTrue(app.buttons["Søk"].waitForExistence(timeout: 5))
        app.buttons["Søk"].tap()
        let field = app.textFields["food-search-field"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("zzzsokutenlokaletreff")
        app.buttons["Ferdig"].tap()
        XCTAssertTrue(app.staticTexts["Ingen lokale treff"].waitForExistence(timeout: 5))
        app.buttons["Registrer manuelt"].tap()
        XCTAssertTrue(app.textFields["Produktnavn"].waitForExistence(timeout: 5))
        let photoOptions = app.buttons["manual-product-photo-options"]
        for _ in 0..<4 {
            if photoOptions.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(photoOptions.isHittable)
        photoOptions.tap()
        XCTAssertTrue(app.buttons["Ta bilde"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Velg fra bilder"].exists)
        // Confirmation choices may be presented as a popover on newer iOS.
        if app.sheets.buttons["Avbryt"].exists {
            app.sheets.buttons["Avbryt"].tap()
        } else {
            app.navigationBars["Opprett produkt"].staticTexts["Opprett produkt"].tap()
        }
        XCTAssertTrue(app.textFields["Produktnavn"].exists)
        app.swipeDown()
        for (label, value) in [("Produktnavn", "Søktest " + UUID().uuidString.prefix(8)),
                               ("Energi", "100"), ("Protein", "2"), ("Karbohydrat", "10"), ("Fett", "4")] {
            if !app.textFields[label].isHittable { app.swipeUp() }
            app.textFields[label].tap()
            app.textFields[label].typeText(value)
        }
        app.swipeUp()
        let save = app.buttons["Lagre og velg mengde"]
        if !save.isHittable { app.swipeUp() }
        XCTAssertTrue(save.isHittable)
        save.tap()
        XCTAssertTrue(app.buttons["logging-draft-save"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Søktest '")).firstMatch.exists)
    }

    @MainActor
    func testSearchSupportsAccessibilityTextSize() throws {
        let app = XCUIApplication()
        app.launchArguments += ["--skip-auth", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.buttons["Søk"].waitForExistence(timeout: 5))
        app.buttons["Søk"].tap()
        XCTAssertTrue(app.textFields["food-search-field"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields["food-search-field"].isHittable)
        XCTAssertTrue(app.buttons["Skann strekkode"].isHittable)
        XCTAssertTrue(app.buttons["food-search-submit"].isHittable)
        for control in [app.textFields["food-search-field"], app.buttons["Skann strekkode"], app.buttons["food-search-submit"]] {
            XCTAssertGreaterThanOrEqual(control.frame.minX, app.frame.minX)
            XCTAssertLessThanOrEqual(control.frame.maxX, app.frame.maxX)
        }
        attachSearchScreenshot(app, name: "Søk – stor tekst")
    }

    @MainActor
    func testSearchDistinguishesPackagesAndGenericFoods() throws {
        verifySearchMetadata(largeText: false)
    }

    @MainActor
    func testSearchMetadataSupportsLargestText() throws {
        verifySearchMetadata(largeText: true)
    }

    @MainActor
    private func verifySearchMetadata(largeText: Bool) {
        let app = XCUIApplication()
        app.launchArguments = ["--skip-auth", "--search-metadata-qa", "-demoModeActive", "NO",
            "-UIPreferredContentSizeCategoryName",
            largeText ? "UICTContentSizeCategoryAccessibilityXXXL" : "UICTContentSizeCategoryL"]
        app.launch()
        XCTAssertTrue(app.buttons["Søk"].waitForExistence(timeout: 10))
        app.buttons["Søk"].tap()
        let field = app.textFields["food-search-field"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.tap()
        field.typeText("Pakningstest")
        if app.buttons["Ferdig"].exists { app.buttons["Ferdig"].tap() }
        let list = app.collectionViews.firstMatch
        attachSearchScreenshot(app, name: "Søkemetadata – start – \(largeText ? "stor" : "vanlig") tekst")
        var visibleTop: CGFloat { list.frame.minY + 8 }
        var visibleBottom: CGFloat { min(list.frame.maxY, app.buttons["Hjem"].frame.minY - 16) }
        func scrollVisibleList(by distance: CGFloat) {
            // List's frame includes the area covered by the persistent menu.
            let top = visibleTop + 12
            let bottom = visibleBottom - 12
            let movement = min(abs(distance), (bottom - top) * 0.75)
            let startY = distance > 0 ? bottom : top
            let endY = distance > 0 ? bottom - movement : top + movement
            let origin = app.coordinate(withNormalizedOffset: .zero)
            let start = origin.withOffset(CGVector(dx: list.frame.midX, dy: startY))
            let end = origin.withOffset(CGVector(dx: list.frame.midX, dy: endY))
            start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.1)
        }
        for expected in ["Pakning: 1 l", "Pakning: 500 ml", "Generell matvare"] {
            let row = app.buttons.matching(NSPredicate(format:
                "identifier BEGINSWITH 'food-search-result-' AND label CONTAINS %@", expected)).firstMatch
            for _ in 0..<12 {
                if row.exists && row.isHittable {
                    if !largeText || abs(row.frame.minY - visibleTop) <= 28 { break }
                    scrollVisibleList(by: row.frame.minY - visibleTop)
                } else {
                    scrollVisibleList(by: 200)
                }
            }
            if !row.exists {
                attachSearchScreenshot(app, name: "Søkemetadata – manglende rad – \(expected)")
                let tree = XCTAttachment(string: list.debugDescription)
                tree.name = "Søkemetadata – tilgjengelighetstre etter rulling"
                tree.lifetime = .keepAlways
                add(tree)
            }
            XCTAssertTrue(row.exists, expected)
            XCTAssertTrue(row.isHittable, expected)
            if row.exists {
                XCTAssertGreaterThanOrEqual(row.frame.minX, app.frame.minX)
                XCTAssertLessThanOrEqual(row.frame.maxX, app.frame.maxX)
                if largeText {
                    XCTAssertLessThanOrEqual(abs(row.frame.minY - visibleTop), 28,
                        "Navn og pakningsinfo skal være rullet fram over bunnmenyen")
                }
                if expected.hasPrefix("Pakning:") {
                    XCTAssertTrue(row.label.contains("Pakkevare"))
                    XCTAssertTrue(row.label.contains("Open Food Facts"))
                    XCTAssertTrue(row.label.contains("per 100 ml"))
                } else {
                    XCTAssertTrue(row.label.contains("Matvaretabellen"))
                    XCTAssertFalse(row.label.contains("Pakning:"))
                }
            }
            attachSearchScreenshot(app, name: "Søkemetadata – \(expected) – \(largeText ? "stor" : "vanlig") tekst")
            if largeText && row.exists {
                for _ in 0..<12 {
                    if row.frame.maxY <= visibleBottom + 12 { break }
                    scrollVisibleList(by: row.frame.maxY - visibleBottom)
                }
                XCTAssertLessThanOrEqual(row.frame.maxY, visibleBottom + 12,
                    "Kilde og næringsgrunnlag skal kunne rulles fram over bunnmenyen")
                XCTAssertGreaterThan(row.frame.maxY, visibleTop + 40)
                attachSearchScreenshot(app, name: "Søkemetadata – kilde og enhet – \(expected) – stor tekst")
            }
        }
    }

    @MainActor
    private func attachSearchScreenshot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testHomeCanNavigateAcrossPastAndFutureDates() throws {
        verifyReturnToToday(largeText: false)
    }

    @MainActor
    func testReturnToTodaySupportsLargestText() throws {
        verifyReturnToToday(largeText: true)
    }

    @MainActor
    private func verifyReturnToToday(largeText: Bool) {
        let app = XCUIApplication()
        app.launchArguments = ["--skip-auth", "-UIPreferredContentSizeCategoryName",
            largeText ? "UICTContentSizeCategoryAccessibilityXXXL" : "UICTContentSizeCategoryL"]
        app.launch()
        let date = app.buttons["day-navigation-date"]
        let today = app.buttons["home-go-to-today"]
        XCTAssertTrue(date.waitForExistence(timeout: 15))
        let originalDate = date.label
        XCTAssertFalse(today.exists)
        for direction in ["Forrige dag", "Neste dag"] {
            app.buttons[direction].tap()
            XCTAssertTrue(today.waitForExistence(timeout: 5))
            XCTAssertNotEqual(date.label, originalDate)
            XCTAssertTrue(today.isHittable)
            XCTAssertTrue(app.frame.contains(today.frame))
            XCTAssertGreaterThanOrEqual(today.frame.height, 44)
            XCTAssertGreaterThanOrEqual(today.frame.minY, date.frame.maxY)
            today.tap()
            let returned = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "label == %@", originalDate), object: date)
            XCTAssertEqual(XCTWaiter.wait(for: [returned], timeout: 5), .completed)
            let hidden = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: today)
            XCTAssertEqual(XCTWaiter.wait(for: [hidden], timeout: 5), .completed)
        }
        attachSearchScreenshot(app, name: largeText ? "Datovelger – tilbake til i dag med stor tekst" : "Datovelger – tilbake til i dag")
    }

    @MainActor
    func testProfileOpensFavoritesEmptyState() throws {
        let app = XCUIApplication()
        app.launchArguments.append("--skip-auth")
        app.launch()

        let profileTab = app.buttons["Profil"]
        XCTAssertTrue(profileTab.waitForExistence(timeout: 3))
        profileTab.tap()

        let favorites = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Favoritter'")).firstMatch
        XCTAssertTrue(favorites.waitForExistence(timeout: 2))
        favorites.tap()

        XCTAssertTrue(app.staticTexts["Ingen favoritter ennå"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Finn matvarer"].exists)
    }

    @MainActor
    func testProfileSettingsDoesNotDuplicateOverview() throws {
        let app = XCUIApplication()
        app.launchArguments.append("--skip-auth")
        app.launch()

        let profileTab = app.buttons["Profil"]
        XCTAssertTrue(profileTab.waitForExistence(timeout: 3))
        profileTab.tap()

        let settings = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'Innstillinger'")
        ).firstMatch
        XCTAssertTrue(settings.waitForExistence(timeout: 2))
        settings.tap()

        XCTAssertTrue(app.navigationBars["Innstillinger"].waitForExistence(timeout: 2))
        XCTAssertEqual(
            app.buttons.matching(NSPredicate(format: "label == 'Utvikling'")).count,
            1,
            "Utvikling skal bare finnes i bunnmenyen, ikke som snarvei i Innstillinger."
        )
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }

    @MainActor
    func testCombinedLoggingRetainsOriginalNavigation() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["--skip-auth", "-demoModeActive", "YES"]
        app.launch()
        XCTAssertTrue(app.buttons["tab-log-food"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["Søk"].exists)
        XCTAssertTrue(app.buttons["Profil"].exists)
        app.buttons["tab-log-food"].tap()
        XCTAssertTrue(app.textFields["food-search-field"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["logging-scan"].exists)
        XCTAssertTrue(app.buttons["food-search-manual-registration"].exists)
        XCTAssertTrue(app.buttons["logging-reuse-saved"].exists)
        let startCapture = XCTAttachment(screenshot: app.screenshot())
        startCapture.name = "Samlet Loggfør – fysisk iPhone"
        startCapture.lifetime = .keepAlways
        add(startCapture)
        let recent = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'quick-log-repeat-'"))
        XCTAssertTrue(recent.firstMatch.waitForExistence(timeout: 8))
        recent.firstMatch.tap()
        XCTAssertTrue(app.buttons["tab-log-food"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["logging-done"].exists)
        let undo = app.buttons["Angre"]
        XCTAssertTrue(undo.waitForExistence(timeout: 3))
        undo.tap()
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: undo)
        waitForExpectations(timeout: 8)
        let capture = XCTAttachment(screenshot: app.screenshot())
        capture.name = "Samlet logging – tilbake på Hjem etter Angre"
        capture.lifetime = .keepAlways
        add(capture)
    }
}
