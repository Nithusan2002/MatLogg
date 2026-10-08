//
//  MatLoggUITests.swift
//  MatLoggUITests
//
//  Created by Nithusan Krishnasamymudali on 21/01/2026.
//

import XCTest

final class MatLoggUITests: XCTestCase {

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
        XCTAssertFalse(app.buttons["Ny i MatLogg? Opprett konto med e-post"].exists)
    }

    @MainActor
    func testMealRoomShowsWholeDayAndMealActionsKeepLoggingContext() throws {
        let app = XCUIApplication()
        app.launchArguments += ["--skip-auth", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
        app.launch()
        let dailyLog = app.buttons["home-daily-log"]
        XCTAssertTrue(dailyLog.waitForExistence(timeout: 8))
        for _ in 0..<8 {
            if dailyLog.isHittable { break }
            app.swipeUp()
        }
        dailyLog.tap()
        XCTAssertTrue(app.staticTexts["Hele dagen"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["meal-room-all"].exists)
        let lunch = app.buttons["meal-room-add-lunsj"]
        for _ in 0..<8 {
            if lunch.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(lunch.isHittable)
        lunch.tap()
        XCTAssertTrue(app.buttons["Lunsj ✓"].waitForExistence(timeout: 5))
        app.buttons["Lukk"].tap()
        for _ in 0..<8 {
            if app.buttons["Forrige dag"].isHittable { break }
            app.swipeDown()
        }
        app.buttons["Forrige dag"].tap()
        XCTAssertTrue(app.staticTexts["Hele dagen"].firstMatch.exists)
        XCTAssertFalse(lunch.isSelected)
    }

    @MainActor
    func testMealRoomLogsAndEditsFoodForSelectedPastDay() throws {
        let app = XCUIApplication()
        app.launchArguments += ["--skip-auth", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
        app.launch()
        let breakfast = app.buttons["home-meal-open-frokost"]
        XCTAssertTrue(breakfast.waitForExistence(timeout: 8))
        for _ in 0..<8 {
            if breakfast.isHittable { break }
            app.swipeUp()
        }
        breakfast.tap()
        XCTAssertTrue(app.staticTexts["meal-room-heading-frokost"].waitForExistence(timeout: 5))
        for _ in 0..<8 {
            if app.buttons["Forrige dag"].isHittable { break }
            app.swipeDown()
        }
        app.buttons["Forrige dag"].tap()
        let dateLabel = app.buttons["day-navigation-date"].label
        let addFood = app.buttons["tab-log-food"]
        XCTAssertTrue(addFood.waitForExistence(timeout: 5))
        addFood.tap()
        app.buttons["Søk etter mat"].tap()
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
        let edit = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'meal-room-row-' AND label CONTAINS[c] 'Havregryn'")).firstMatch
        XCTAssertTrue(edit.waitForExistence(timeout: 8))
        XCTAssertEqual(app.buttons["day-navigation-date"].label, dateLabel)
        edit.tap()
        XCTAssertTrue(app.buttons["Flytt til Lunsj"].waitForExistence(timeout: 5))
        app.buttons["Flytt til Lunsj"].tap()
        app.buttons["Lagre endringer"].tap()
        for _ in 0..<8 {
            if edit.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(edit.isHittable)
        XCTAssertTrue(edit.waitForExistence(timeout: 8))
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Måltidsrom – registrert mat"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testFirstLoggingWithoutAccountAndRelaunch() throws {
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
        let noImport = app.staticTexts["Eksporten er en kopi for innsyn og deling. Den kan ikke importeres tilbake i MatLogg."]
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
        let dailyLog = app.buttons["home-daily-log"]
        XCTAssertTrue(dailyLog.waitForExistence(timeout: 8))
        for _ in 0..<8 {
            if dailyLog.isHittable { break }
            app.swipeUp()
        }
        dailyLog.tap()
        XCTAssertTrue(app.staticTexts["Hele dagen"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["meal-room-all"].exists)
        for meal in ["frokost", "lunsj", "middag", "snacks"] {
            XCTAssertFalse(app.buttons["meal-room-select-" + meal].exists)
        }
        XCTAssertTrue(app.buttons["meal-room-reuse"].exists)
        app.buttons["tab-log-food"].tap()
        let savedTab = app.buttons["quick-log-show-saved"]
        XCTAssertTrue(savedTab.waitForExistence(timeout: 5))
        if !savedTab.isHittable { app.swipeUp() }
        savedTab.tap()
        XCTAssertTrue(savedTab.isSelected)
        let scroll = app.scrollViews["quick-log-scroll"]
        XCTAssertTrue(scroll.exists)
        let bounds = scroll.frame
        let savedFrame = savedTab.frame
        XCTAssertGreaterThanOrEqual(savedFrame.minX, bounds.minX)
        XCTAssertLessThanOrEqual(savedFrame.maxX, bounds.maxX)
        scroll.swipeLeft()
        scroll.swipeRight()
        XCTAssertEqual(savedTab.frame.minX, savedFrame.minX, accuracy: 1)
        XCTAssertTrue(savedTab.isSelected)
        let recentTab = app.buttons["quick-log-show-recent"]
        recentTab.tap()
        XCTAssertTrue(recentTab.isSelected)
        XCTAssertFalse(app.buttons["quick-log-saved-meals"].exists)
        XCTAssertFalse(app.staticTexts["Andre hurtigvalg"].exists)
        savedTab.tap()
        let library = app.buttons["quick-log-saved-meals"]
        XCTAssertTrue(library.waitForExistence(timeout: 5))
        if !library.isHittable { app.swipeUp() }
        library.tap()
        XCTAssertTrue(app.navigationBars["Lagrede måltider"].waitForExistence(timeout: 5))
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
        XCTAssertTrue(app.buttons["quick-log-manual"].waitForExistence(timeout: 5))
        app.buttons["quick-log-manual"].tap()
        XCTAssertTrue(app.navigationBars["Opprett produkt"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.navigationBars["Søk"].exists)
        app.buttons["Avbryt"].tap()
        XCTAssertTrue(app.buttons["quick-log-manual"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.navigationBars["Søk"].exists)
        app.buttons["Lukk"].tap()
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
        app.buttons["tab-log-food"].tap()
        XCTAssertTrue(app.buttons["quick-log-manual"].waitForExistence(timeout: 5))
        let breakfast = app.buttons["Logg til Frokost"]
        for _ in 0..<8 {
            if breakfast.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(breakfast.isHittable)
        breakfast.tap()
        XCTAssertTrue(breakfast.isSelected)
        let manual = app.buttons["quick-log-manual"]
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
        if closeReceipt.waitForExistence(timeout: 2) { closeReceipt.tap() }
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'home-log-row-' AND label CONTAINS %@", name)).firstMatch
        for _ in 0..<10 {
            if row.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(row.exists)
        row.tap()
        let editor = app.scrollViews["log-editor-scroll"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
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
        lunch.tap()
        let moved = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'meal-room-row-' AND label CONTAINS %@", name)).firstMatch
        XCTAssertTrue(moved.waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["meal-room-heading-lunsj"].exists)
        app.buttons["BackButton"].tap()
        XCTAssertTrue(app.buttons["day-navigation-date"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["day-navigation-date"].label, dateLabel)
        attachSearchScreenshot(app, name: "Navigasjon – direkte redigering på tidligere dato")
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
        XCTAssertFalse(app.staticTexts["MatLogg"].exists)
        XCTAssertFalse(app.buttons["Søk etter mat"].exists)
        XCTAssertFalse(app.buttons["Skann strekkode"].exists)

        logButton.tap()
        XCTAssertTrue(app.staticTexts["Loggfør mat"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Søk etter mat"].exists)
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
    private func attachSearchScreenshot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testHomeCanNavigateAcrossPastAndFutureDates() throws {
        let app = XCUIApplication()
        app.launchArguments.append("--skip-auth")
        app.launch()

        let dateButton = app.buttons["day-navigation-date"]
        XCTAssertTrue(dateButton.waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Neste dag"].isEnabled)

        dateButton.tap()
        XCTAssertTrue(app.staticTexts["Velg dato"].waitForExistence(timeout: 2))
        app.buttons["Ferdig"].tap()

        app.buttons["Forrige dag"].tap()

        XCTAssertTrue(app.staticTexts["Måltider i går"].waitForExistence(timeout: 2))
        app.buttons["Neste dag"].tap()
        XCTAssertTrue(app.staticTexts["Måltider i dag"].waitForExistence(timeout: 2))
        app.buttons["Neste dag"].tap()
        XCTAssertTrue(app.staticTexts["Måltider i morgen"].waitForExistence(timeout: 2))
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
}
