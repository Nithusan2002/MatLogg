#if DEBUG && SPOR_MASCOT_QA
import XCTest

final class SporMascotPreviewUITests: XCTestCase {
    @MainActor private func launch(_ extra: [String] = []) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--spor-mascot-qa"] + extra
        app.launch()
        return app
    }
    @MainActor private func expectStatus(_ text: String, in app: XCUIApplication) {
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "identifier == %@ AND label == %@", "mascot-status", text))
            .firstMatch.waitForExistence(timeout: 30))
    }
    @MainActor func testThreeClipsPauseRestartAndBackground() {
        let app = launch()
        expectStatus("Hvile · Spiller", in: app)
        app.segmentedControls["mascot-clip"].buttons["Hilsen"].tap()
        expectStatus("Hilsen · Spiller", in: app)
        // The raised arm must be reviewed inside the same fixed camera crop.
        Thread.sleep(forTimeInterval: 2.5)
        let greeting = XCTAttachment(screenshot: app.screenshot())
        greeting.name = "Spor QA – løftet arm"
        greeting.lifetime = .keepAlways
        add(greeting)
        app.segmentedControls["mascot-clip"].buttons["Gange"].tap()
        expectStatus("Gange · Spiller", in: app)
        app.buttons["mascot-playback"].tap()
        expectStatus("Gange · Pauset", in: app)
        app.buttons["mascot-restart"].tap()
        expectStatus("Gange · Pauset", in: app)
        XCUIDevice.shared.press(.home)
        app.activate()
        expectStatus("Gange · Pauset", in: app)
        let image = XCTAttachment(screenshot: app.screenshot())
        image.name = "Spor QA – tre klipp"
        image.lifetime = .keepAlways
        add(image)
    }
    @MainActor func testMissingResourceHasControlledRetry() {
        let app = launch(["--spor-mascot-missing-asset"])
        expectStatus("Kunne ikke laste Spor", in: app)
        app.buttons["mascot-retry"].tap()
        expectStatus("Kunne ikke laste Spor", in: app)
        XCTAssertFalse(app.buttons["mascot-playback"].isEnabled)
    }
    @MainActor func testReducedMotionStartsPausedAndAllowsExplicitPlayback() {
        let app = launch(["--spor-mascot-reduced-motion"])
        expectStatus("Hvile · Pauset", in: app)
        app.buttons["mascot-playback"].tap()
        expectStatus("Hvile · Spiller", in: app)
        let image = XCTAttachment(screenshot: app.screenshot())
        image.name = "Spor QA – redusert bevegelse"
        image.lifetime = .keepAlways
        add(image)
    }
    @MainActor func testLargeTextAppearanceAndSizeControls() {
        let app = launch(["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        expectStatus("Hvile · Spiller", in: app)
        for _ in 0..<4 {
            if app.buttons["mascot-size"].isHittable { break }
            app.swipeUp()
        }
        app.buttons["mascot-size"].tap()
        app.buttons["Stor"].tap()
        for _ in 0..<4 {
            if app.buttons["mascot-appearance"].isHittable { break }
            app.swipeUp()
        }
        app.buttons["mascot-appearance"].tap()
        app.buttons["Mørk"].tap()
        XCTAssertTrue(app.staticTexts["Spor – forhåndsvisning"].exists)
        let image = XCTAttachment(screenshot: app.screenshot())
        image.name = "Spor QA – mørk og stor tekst"
        image.lifetime = .keepAlways
        add(image)
    }
}
#endif
