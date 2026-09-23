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
        app.launchArguments.append("--show-auth")
        app.launch()
        XCTAssertTrue(app.staticTexts["MatLogg"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Logg inn"].exists)
        XCTAssertFalse(app.buttons["Logg inn med Apple"].exists)
    }

    @MainActor
    func testDebugSessionShowsHomeAndPrimaryNavigation() throws {
        let app = XCUIApplication()
        app.launch()

        let logButton = app.buttons["Loggfør mat"]
        XCTAssertTrue(logButton.waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Åpne profil"].exists)

        logButton.tap()
        XCTAssertTrue(app.staticTexts["Loggfør mat"].waitForExistence(timeout: 2))
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Logg til:'")).firstMatch.exists
        )
    }

    @MainActor
    func testHomeCanNavigateAcrossPastAndFutureDates() throws {
        let app = XCUIApplication()
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
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
