import XCTest

final class DomainReadFailureUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    func testUnifiedRecentReadFailureShowsErrorAndRetryRecovers() {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["--skip-auth", "--quick-choices-read-failure-qa", "-demoModeActive", "NO",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
        app.launch()
        let open = app.buttons["tab-log-food"]
        XCTAssertTrue(open.waitForExistence(timeout: 10))
        open.tap()
        let error = app.descendants(matching: .any)["logging-recent-read-error"].firstMatch
        let retry = app.buttons["logging-recent-retry"]
        XCTAssertTrue(error.waitForExistence(timeout: 8))
        XCTAssertFalse(app.staticTexts["logging-recent-empty"].exists)
        for _ in 0..<6 {
            if retry.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(retry.isHittable)
        retry.tap()
        XCTAssertTrue(error.waitForNonExistence(timeout: 8))
        XCTAssertTrue(retry.waitForNonExistence(timeout: 5))
        let empty = app.staticTexts["logging-recent-empty"]
        let recent = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'quick-log-repeat-'"))
        XCTAssertTrue(empty.waitForExistence(timeout: 3) || recent.firstMatch.waitForExistence(timeout: 5))
    }

    @MainActor
    func testFavoritesReadFailureShowsErrorAndRetryRecoversWithLargeText() {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["--skip-auth", "--favorite-read-failure-qa", "-demoModeActive", "NO",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        let profile = app.buttons["Profil"].firstMatch
        XCTAssertTrue(profile.waitForExistence(timeout: 10))
        profile.tap()
        let favorites = app.buttons["Favoritter"].firstMatch
        XCTAssertTrue(favorites.waitForExistence(timeout: 5))
        for _ in 0..<8 {
            if favorites.isHittable && favorites.frame.maxY < app.frame.height - 130 { break }
            app.swipeUp()
        }
        favorites.tap()
        let error = app.descendants(matching: .any)["favorites-read-error"].firstMatch
        let retry = app.buttons["favorites-retry"]
        XCTAssertTrue(error.waitForExistence(timeout: 8))
        XCTAssertTrue(retry.waitForExistence(timeout: 5))
        XCTAssertTrue(retry.isHittable)
        XCTAssertFalse(app.descendants(matching: .any)["favorites-empty-state"].firstMatch.exists)
        let failed = XCTAttachment(screenshot: app.screenshot())
        failed.name = "Favoritter – lesefeil med stor tekst"
        failed.lifetime = .keepAlways
        add(failed)

        retry.tap()
        let recovered = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: error)
        XCTAssertEqual(XCTWaiter.wait(for: [recovered], timeout: 8), .completed)
        let empty = app.descendants(matching: .any)["favorites-empty-state"].firstMatch
        let list = app.scrollViews["favorites-list"]
        XCTAssertTrue(empty.waitForExistence(timeout: 5) || list.waitForExistence(timeout: 5))
        XCTAssertFalse(retry.exists)
        let success = XCTAttachment(screenshot: app.screenshot())
        success.name = "Favoritter – vellykket nytt forsøk"
        success.lifetime = .keepAlways
        add(success)
    }
}
