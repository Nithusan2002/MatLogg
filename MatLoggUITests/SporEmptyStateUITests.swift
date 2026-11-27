import XCTest

/// Uses only the separate QA application's container.
final class SporEmptyStateUITests: XCTestCase {
    @MainActor
    func testProfileEmptyStatesHaveConsistentLayoutAndWorkingActions() throws {
        for appearance in ["light", "dark"] {
            try verifyProfileEmptyStates(appearance: appearance, largestText: false)
        }
    }

    @MainActor
    func testEmptyStateActionsRemainReachableAtLargestText() throws {
        try verifyProfileEmptyStates(appearance: "light", largestText: true)
    }

    @MainActor
    func testSavedMealsHomeActionClosesQuickLogging() throws {
        let app = try application(appearance: "light", largestText: false)
        app.launch()
        let log = app.buttons["tab-log-food"]
        XCTAssertTrue(log.waitForExistence(timeout: 15))
        log.tap()
        let saved = app.buttons["quick-log-show-saved"]
        XCTAssertTrue(saved.waitForExistence(timeout: 5))
        saved.tap()
        let library = app.buttons["quick-log-saved-meals"]
        reveal(library, in: app)
        library.tap()
        let home = app.buttons["saved-meals-go-home"]
        XCTAssertTrue(home.waitForExistence(timeout: 10))
        reveal(home, in: app)
        home.tap()
        XCTAssertTrue(app.buttons["tab-log-food"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["quick-log-show-recent"].exists)
        XCTAssertTrue(app.buttons["Hjem"].firstMatch.isSelected)
    }

    @MainActor
    private func verifyProfileEmptyStates(appearance: String, largestText: Bool) throws {
        let app = try application(appearance: appearance, largestText: largestText)
        app.launch()
        let profile = app.buttons["Profil"].firstMatch
        XCTAssertTrue(profile.waitForExistence(timeout: 15))
        profile.tap()
        let favorites = app.buttons["Favoritter"].firstMatch
        reveal(favorites, in: app)
        favorites.tap()
        let find = app.buttons["favorites-find-foods"]
        XCTAssertTrue(find.waitForExistence(timeout: 10))
        let favoriteTitle = app.staticTexts["Ingen favoritter ennå"].frame
        reveal(find, in: app)
        keep(app, "Favorites – \(appearance) – \(largestText ? "largest" : "normal")")
        find.tap()
        XCTAssertTrue(app.buttons["Søk"].firstMatch.isSelected)

        profile.tap()
        XCTAssertTrue(app.navigationBars["Favoritter"].waitForExistence(timeout: 5))
        app.navigationBars["Favoritter"].buttons.firstMatch.tap()
        let library = app.buttons["profile-saved-meals"]
        reveal(library, in: app)
        library.tap()
        let home = app.buttons["saved-meals-go-home"]
        XCTAssertTrue(home.waitForExistence(timeout: 10))
        if !largestText {
            XCTAssertEqual(app.staticTexts["Ingen lagrede måltider ennå"].frame.midY,
                           favoriteTitle.midY, accuracy: 12,
                           "Both profile empty states should use the same vertical placement")
        }
        reveal(home, in: app)
        keep(app, "Saved meals – \(appearance) – \(largestText ? "largest" : "normal")")
        home.tap()
        XCTAssertTrue(app.buttons["Hjem"].firstMatch.isSelected)
        XCTAssertTrue(app.buttons["home-diary-menu"].waitForExistence(timeout: 5))
        app.terminate()
    }

    @MainActor
    private func application(appearance: String, largestText: Bool) throws -> XCUIApplication {
        guard ProcessInfo.processInfo.environment["SPOR_QA_APP_BUNDLE_ID"]
                == "com.nithusan.MatLogg.spor-integration-qa" else {
            throw XCTSkip("Requires the isolated Spor QA app")
        }
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "com.nithusan.MatLogg.spor-integration-qa")
        app.launchArguments = ["--skip-auth", "-demoModeActive", "NO", "-appAppearance", appearance,
                               "-UIPreferredContentSizeCategoryName", largestText
                               ? "UICTContentSizeCategoryAccessibilityXXXL" : "UICTContentSizeCategoryL"]
        return app
    }

    @MainActor private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        XCTAssertTrue(element.waitForExistence(timeout: 5))
        for _ in 0..<8 {
            if element.isHittable && element.frame.maxY < app.frame.height - 100 { return }
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable)
    }

    @MainActor private func keep(_ app: XCUIApplication, _ name: String) {
        let capture = XCTAttachment(screenshot: app.screenshot())
        capture.name = name
        capture.lifetime = .keepAlways
        add(capture)
    }
}
