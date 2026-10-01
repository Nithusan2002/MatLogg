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
    func testExample() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["MatLogg"].waitForExistence(timeout: 3))
        let localContinue = app.buttons["welcome-continue-local"]
        XCTAssertTrue(localContinue.exists)
        XCTAssertTrue(localContinue.isHittable, "Primærhandlingen skal være synlig uten scrolling på standard iPhone.")
        XCTAssertTrue(app.buttons["welcome-login"].isHittable)
        XCTAssertTrue(app.descendants(matching: .any)["welcome-privacy"].isHittable)
        XCTAssertFalse(app.buttons["Logg inn med Apple"].exists)
    }

    @MainActor
    func testDebugSessionShowsHomeAndPrimaryNavigation() throws {
        let app = XCUIApplication()
        app.launchArguments.append("--skip-auth")
        app.launch()

        let logButton = app.buttons["Loggfør mat"]
        XCTAssertTrue(logButton.waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Åpne profil"].exists)
        XCTAssertFalse(app.buttons["Søk etter mat"].exists)
        XCTAssertFalse(app.buttons["Skann strekkode"].exists)

        logButton.tap()
        XCTAssertTrue(app.staticTexts["Loggfør mat"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Søk etter mat"].exists)
        XCTAssertTrue(app.buttons["Skann strekkode"].exists)
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Logg til:'")).firstMatch.exists
        )
    }

    @MainActor
    func testQuickLogAlwaysOffersManualProductCreation() throws {
        let app = XCUIApplication()
        app.launchArguments.append("--skip-auth")
        app.launch()

        let logButton = app.buttons["Loggfør mat"]
        XCTAssertTrue(logButton.waitForExistence(timeout: 3))
        logButton.tap()

        let createButton = app.buttons["Opprett egen matvare"]
        XCTAssertTrue(createButton.waitForExistence(timeout: 2))
        createButton.tap()

        XCTAssertTrue(app.navigationBars["Opprett egen matvare"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.textFields["Produktnavn"].exists)
        XCTAssertTrue(app.staticTexts["Les næringstabell"].exists)
        XCTAssertTrue(app.buttons["Lagre og fortsett"].exists)
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
        app.buttons["Ferdig"].tap()
        XCTAssertTrue(app.buttons["Loggfør mat"].waitForExistence(timeout: 5))
        let reused = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Havregryn' AND label CONTAINS 'Matvaretabellen'"))
        XCTAssertGreaterThanOrEqual(reused.count, 2, "Matvaren skal finnes både i favoritter og nylig brukt.")
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
        for (label, value) in [("Produktnavn", "Søktest " + UUID().uuidString.prefix(8)),
                               ("Energi", "100"), ("Protein", "2"), ("Karbohydrat", "10"), ("Fett", "4")] {
            app.textFields[label].tap()
            app.textFields[label].typeText(value)
        }
        app.swipeUp()
        let save = app.buttons["Lagre og fortsett"]
        if !save.isHittable { app.swipeUp() }
        XCTAssertTrue(save.isHittable)
        save.tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Legg til '")).firstMatch.waitForExistence(timeout: 5))
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
            app.buttons.matching(NSPredicate(format: "label == 'Oversikt'")).count,
            1,
            "Oversikt skal bare finnes i bunnmenyen, ikke som snarvei i Innstillinger."
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
