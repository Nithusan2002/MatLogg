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
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
