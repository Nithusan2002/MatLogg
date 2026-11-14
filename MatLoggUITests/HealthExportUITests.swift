import XCTest

final class HealthExportUITests: XCTestCase {
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
