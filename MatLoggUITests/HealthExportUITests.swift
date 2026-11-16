import XCTest

final class HealthExportUITests: XCTestCase {
    @MainActor
    func testHistoryPreviewConfirmationAndRepeatAvoidsNewValues() {
        verifyHistoryExport(largeText: false)
    }

    @MainActor
    func testHistoryExportSupportsLargestText() {
        verifyHistoryExport(largeText: true)
    }

    @MainActor
    private func verifyHistoryExport(largeText: Bool) {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--health-history-qa", "-UIPreferredContentSizeCategoryName",
            largeText ? "UICTContentSizeCategoryAccessibilityXXXL" : "UICTContentSizeCategoryL"]
        app.launch()
        func reveal(_ element: XCUIElement, upwards: Bool = true) {
            for _ in 0..<8 {
                if element.exists && element.isHittable { return }
                if upwards { app.swipeUp() } else { app.swipeDown() }
            }
        }
        let history = app.buttons["health-history-open"]
        reveal(history)
        XCTAssertTrue(history.waitForExistence(timeout: 10))
        history.tap()
        let preview = app.buttons["health-history-preview"]
        reveal(preview)
        XCTAssertTrue(preview.waitForExistence(timeout: 5))
        preview.tap()
        let counts = app.staticTexts["1 matregistrering og 1 vektregistrering"]
        reveal(counts)
        XCTAssertTrue(counts.waitForExistence(timeout: 5))
        let share = app.buttons["health-history-share"]
        reveal(share)
        share.tap()
        let confirm = app.buttons.matching(identifier: "health-history-confirm").firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
        let transferred = app.staticTexts["5 Helse-verdier er overført, inkludert verdier som var delt fra før."]
        reveal(transferred)
        XCTAssertTrue(transferred.waitForExistence(timeout: 5))
        reveal(preview, upwards: false)
        preview.tap()
        let unchanged = app.staticTexts["5 Helse-verdier. 5 er allerede overført eller ligger i kø uten endringer."]
        reveal(unchanged)
        XCTAssertTrue(unchanged.waitForExistence(timeout: 5))
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Historikkeksport – gjentatt forhåndsvisning"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testExportSettingsRemainSeparateFromReadingWithLargestText() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-demoModeActive", "YES", "--enable-healthkit-export",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        app.openAppleHealthSettings()
        XCTAssertTrue(app.switches["apple-health-weight-toggle"].exists)
        let export = app.buttons["apple-health-export-settings"]
        for _ in 0..<6 {
            if export.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(export.waitForExistence(timeout: 5))
        export.tap()
        let nutrition = app.switches["health-share-nutrition"]
        XCTAssertTrue(nutrition.waitForExistence(timeout: 5))
        // Demo sessions must never write real HealthKit data.
        XCTAssertFalse(nutrition.isEnabled)
        XCTAssertFalse(app.switches["health-read-weight"].exists)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Apple Helse-eksport – største tekststørrelse"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
