import XCTest
import UIKit

/// Run only against the separate QA app; never changes a user's ordinary app.
final class SporCompanionRenderingUITests: XCTestCase {
    @MainActor
    func testEmptyDiaryOpensLoggingForSelectedDateWithLargestText() throws {
        let app = try qaApplication(requiresMotion: false)
        app.launchArguments = ["--skip-auth", "-demoModeActive", "NO",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        let previous = app.buttons["Forrige dag"]
        XCTAssertTrue(previous.waitForExistence(timeout: 20))
        previous.tap()
        let addFood = app.buttons["home-log-food"]
        XCTAssertTrue(addFood.waitForExistence(timeout: 10))
        let title = app.staticTexts["Ingen mat registrert denne dagen"]
        XCTAssertTrue(title.exists)
        XCTAssertEqual(addFood.label, "Legg til mat")
        let selectedDate = app.buttons["day-navigation-date"].label
        for _ in 0..<6 {
            if addFood.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(addFood.isHittable)
        keep(app.screenshot(), "Empty diary – largest text")
        addFood.tap()
        XCTAssertTrue(app.buttons["quick-log-show-recent"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["I går"].exists,
                      "The empty-day action must preserve yesterday as the logging date")
        app.buttons["Lukk"].tap()
        for _ in 0..<6 {
            if app.buttons["day-navigation-date"].isHittable { break }
            app.swipeDown()
        }
        XCTAssertEqual(app.buttons["day-navigation-date"].label, selectedDate)
        XCTAssertTrue(addFood.exists)
    }

    @MainActor
    func testIntroKeepsMascotVisibleAfterOpening() throws {
        guard ProcessInfo.processInfo.environment["SPOR_QA_APP_BUNDLE_ID"]
                == "com.nithusan.MatLogg.spor-integration-qa" else {
            throw XCTSkip("Requires the isolated Spor integration QA app")
        }
        let app = XCUIApplication(bundleIdentifier: "com.nithusan.MatLogg.spor-integration-qa")
        app.launchArguments = ["-ml_local_profile", "", "-ml_local_mode_active", "NO",
                               "-demoModeActive", "NO", "-appAppearance", "light"]
        app.launch()
        XCTAssertTrue(app.buttons["onboarding-next"].waitForExistence(timeout: 20))
        Thread.sleep(forTimeInterval: 2)
        let greeting = app.screenshot()
        let attachment = XCTAttachment(screenshot: greeting)
        attachment.name = "Spor remains visible after opening"
        attachment.lifetime = .keepAlways
        add(attachment)
        XCTAssertGreaterThan(try coralPixels(in: greeting.image), 1_000,
                             "The mascot viewport must not go blank after opening")
    }

    @MainActor
    func testIntroductionMovesThenSettles() throws {
        try verifyIntroductionMovesThenSettles(appearance: "light")
    }

    @MainActor
    func testIntroductionMovesThenSettlesInDarkMode() throws {
        try verifyIntroductionMovesThenSettles(appearance: "dark")
    }

    @MainActor
    private func verifyIntroductionMovesThenSettles(appearance: String) throws {
        let app = try qaApplication(requiresMotion: true)
        app.launchArguments = introArguments(appearance: appearance)
        app.launch()
        XCTAssertTrue(app.buttons["onboarding-next"].waitForExistence(timeout: 20))
        Thread.sleep(forTimeInterval: 0.5)
        let first = app.screenshot()
        Thread.sleep(forTimeInterval: 1)
        let second = app.screenshot()
        keep(first, "Intro – animation frame 1")
        keep(second, "Intro – animation frame 2")
        XCTAssertGreaterThan(try changedPixels(first, second, region: .intro), 500)
        Thread.sleep(forTimeInterval: 5)
        let settled = app.screenshot()
        Thread.sleep(forTimeInterval: 0.7)
        let settledAgain = app.screenshot()
        keep(settled, "Intro – settled still image")
        XCTAssertGreaterThan(try coralPixels(in: settled.image), 1_000)
        XCTAssertLessThan(try changedPixels(settled, settledAgain, region: .intro), 20)
    }

    @MainActor
    func testIntroductionStaysStillAfterBackground() throws {
        let app = try qaApplication(requiresMotion: true)
        app.launchArguments = introArguments()
        app.launch()
        XCTAssertTrue(app.buttons["onboarding-next"].waitForExistence(timeout: 20))
        Thread.sleep(forTimeInterval: 1)
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(app.buttons["onboarding-next"].waitForExistence(timeout: 10))
        let first = app.screenshot()
        Thread.sleep(forTimeInterval: 0.7)
        let second = app.screenshot()
        keep(first, "Intro – after background")
        XCTAssertGreaterThan(try coralPixels(in: first.image), 1_000)
        XCTAssertLessThan(try changedPixels(first, second, region: .intro), 20)
    }

    @MainActor
    func testIntroductionStaysStillAfterPageNavigation() throws {
        let app = try qaApplication(requiresMotion: true)
        app.launchArguments = introArguments()
        app.launch()
        XCTAssertTrue(app.buttons["onboarding-next"].waitForExistence(timeout: 20))
        Thread.sleep(forTimeInterval: 1)
        app.buttons["onboarding-next"].tap()
        XCTAssertTrue(app.buttons["onboarding-start-logging"].waitForExistence(timeout: 5))
        let firstPage = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Introside 1 av'")).firstMatch
        XCTAssertTrue(firstPage.isHittable)
        firstPage.tap()
        XCTAssertTrue(app.buttons["onboarding-next"].waitForExistence(timeout: 5))
        let first = app.screenshot()
        Thread.sleep(forTimeInterval: 0.7)
        let second = app.screenshot()
        keep(first, "Intro – after page navigation")
        XCTAssertGreaterThan(try coralPixels(in: first.image), 1_000)
        XCTAssertLessThan(try changedPixels(first, second, region: .intro), 20)
    }

    @MainActor
    func testHomeGreetingDoesNotRepeatAfterRelaunchOrNavigation() throws {
        guard ProcessInfo.processInfo.isLowPowerModeEnabled else {
            throw XCTSkip("Enable Low Power Mode to isolate the daily greeting from idle breathing")
        }
        let app = try qaApplication(requiresMotion: true)
        // Empty argument-domain value opens the daily gate in this first QA
        // process. The date it writes still persists in the application domain.
        app.launchArguments = ["--skip-auth", "-demoModeActive", "NO", "-appAppearance", "light",
                               "-spor.lastHomeGreeting", ""]
        app.launch()
        XCTAssertTrue(app.buttons["tab-log-food"].waitForExistence(timeout: 20))
        Thread.sleep(forTimeInterval: 0.5)
        let moving = app.screenshot()
        let region = try mascotRegion(in: moving, button: app.buttons["spor-wave-button"], app: app)
        Thread.sleep(forTimeInterval: 1)
        let movingAgain = app.screenshot()
        keep(moving, "Home – animation frame 1")
        keep(movingAgain, "Home – animation frame 2")
        XCTAssertGreaterThan(try changedPixels(moving, movingAgain, region: region), 40)
        app.terminate()
        // Remove the override: subsequent processes use the real persisted date.
        app.launchArguments = ["--skip-auth", "-demoModeActive", "NO", "-appAppearance", "light"]
        app.launch()
        XCTAssertTrue(app.buttons["tab-log-food"].waitForExistence(timeout: 20))
        waitForWaveReady(app.buttons["spor-wave-button"])
        let still = app.screenshot()
        Thread.sleep(forTimeInterval: 1)
        let stillAgain = app.screenshot()
        keep(still, "Home – persisted daily gate after restart")
        XCTAssertLessThan(try changedPixels(still, stillAgain, region: region), 20)
        app.buttons["Søk"].firstMatch.tap()
        app.buttons["Hjem"].firstMatch.tap()
        Thread.sleep(forTimeInterval: 0.5)
        let afterNavigation = app.screenshot()
        XCTAssertLessThan(try changedPixels(stillAgain, afterNavigation, region: region), 20)
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(app.buttons["tab-log-food"].waitForExistence(timeout: 10))
        let afterBackground = app.screenshot()
        keep(afterBackground, "Home – unchanged after background")
        XCTAssertLessThan(try changedPixels(stillAgain, afterBackground, region: region), 20)
    }

    @MainActor
    func testReducedMotionAllowsManualWaveButNoAutomaticPlayback() throws {
        guard UIAccessibility.isReduceMotionEnabled else {
            throw XCTSkip("Enable system Reduce Motion for this accessibility scenario")
        }
        try testHomeTapWavesAgainAndStopsAfterBackground()
    }

    @MainActor
    func testHomeTapWavesAgainAndStopsAfterBackground() throws {
        let app = try qaApplication(requiresMotion: false)
        let idlePixelLimit = UIAccessibility.isReduceMotionEnabled || ProcessInfo.processInfo.isLowPowerModeEnabled ? 20 : 600
        app.launchArguments = ["--skip-auth", "-demoModeActive", "NO", "-appAppearance", "light",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
        app.launch()
        let button = app.buttons["spor-wave-button"]
        waitForWaveReady(button)
        XCTAssertEqual(button.label, "La Spor vinke")
        button.tap()
        Thread.sleep(forTimeInterval: 0.5)
        XCTAssertFalse(button.isEnabled)
        XCTAssertEqual(button.value as? String, "Vinker")
        let first = app.screenshot()
        let region = try mascotRegion(in: first, button: button, app: app)
        Thread.sleep(forTimeInterval: 1)
        let second = app.screenshot()
        try assertArtworkKeepsColor(first, button: button, app: app)
        keep(first, "Home – tapped greeting frame 1")
        keep(second, "Home – tapped greeting frame 2")
        XCTAssertGreaterThan(try changedPixels(first, second, region: region), 40)
        // Raw coordinates exercise ignored touches on the disabled control.
        for _ in 0..<3 { button.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap() }
        waitForWaveReady(button)
        let settled = app.screenshot()
        Thread.sleep(forTimeInterval: 1)
        XCTAssertLessThan(try changedPixels(settled, app.screenshot(), region: region), idlePixelLimit)
        button.tap()
        Thread.sleep(forTimeInterval: 0.5)
        XCTAssertEqual(button.value as? String, "Vinker")
        let again = app.screenshot()
        Thread.sleep(forTimeInterval: 1)
        XCTAssertGreaterThan(try changedPixels(again, app.screenshot(), region: region), 40)
        XCUIDevice.shared.press(.home)
        app.activate()
        waitForWaveReady(button)
        let afterBackground = app.screenshot()
        Thread.sleep(forTimeInterval: 1)
        XCTAssertLessThan(try changedPixels(afterBackground, app.screenshot(), region: region), idlePixelLimit)
    }

    @MainActor
    func testHomeRestMatchesBeforeAndAfterWave() throws {
        guard ProcessInfo.processInfo.isLowPowerModeEnabled else {
            throw XCTSkip("Enable Low Power Mode to compare the exact rest pose without breathing")
        }
        let app = try qaApplication(requiresMotion: true)
        for appearance in ["light", "dark"] {
            app.launchArguments = ["--skip-auth", "-demoModeActive", "NO", "-appAppearance", appearance,
                                   "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
            app.launch()
            let button = app.buttons["spor-wave-button"]
            waitForWaveReady(button)
            Thread.sleep(forTimeInterval: 0.5)
            let before = app.screenshot()
            let restFrame = button.frame
            let region = try mascotRegion(in: before, button: button, app: app)
            try assertArtworkKeepsColor(before, button: button, app: app)
            keep(before, "Home – same 3D rest before tap – \(appearance)")
            button.tap()
            Thread.sleep(forTimeInterval: 2)
            let waving = app.screenshot()
            keep(waving, "Home – continuous 3D wave – \(appearance)")
            XCTAssertGreaterThan(try changedPixels(before, waving, region: region), 40)
            waitForWaveReady(button)
            Thread.sleep(forTimeInterval: 0.5)
            let after = app.screenshot()
            XCTAssertEqual(button.frame, restFrame, "Waving must not move or resize its surface")
            keep(after, "Home – same 3D rest after wave – \(appearance)")
            XCTAssertLessThan(try changedPixels(before, after, region: region), 40,
                              "Returning to rest must preserve silhouette, camera and materials")
            app.terminate()
        }
    }

    @MainActor
    func testHomeBreathStaysSubtleWithoutStartingAnotherGreeting() throws {
        let app = try qaApplication(requiresMotion: true)
        guard !ProcessInfo.processInfo.isLowPowerModeEnabled else {
            throw XCTSkip("Disable Low Power Mode to verify idle breathing")
        }
        app.launchArguments = ["--skip-auth", "-demoModeActive", "NO", "-appAppearance", "light",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
        app.launch()
        let button = app.buttons["spor-wave-button"]
        waitForWaveReady(button)
        Thread.sleep(forTimeInterval: 0.5)
        let first = app.screenshot()
        let region = try mascotRegion(in: first, button: button, app: app)
        Thread.sleep(forTimeInterval: 2.5)
        let second = app.screenshot()
        let difference = try changedPixels(first, second, region: region)
        XCTAssertGreaterThan(difference, 5, "The visible idle figure should breathe")
        XCTAssertLessThan(difference, 600, "A breath must remain much smaller than a greeting")
        XCTAssertTrue(button.isEnabled)
        XCTAssertEqual(button.value as? String, "Klar")
        keep(first, "Home – subtle breath frame 1")
        keep(second, "Home – subtle breath frame 2")
        XCUIDevice.shared.press(.home)
        app.activate()
        waitForWaveReady(button)
        XCTAssertEqual(button.value as? String, "Klar")
    }

    @MainActor
    func testHomeTapIsAvailableAtLargestText() throws {
        let app = try qaApplication(requiresMotion: false)
        app.launchArguments = ["--skip-auth", "-demoModeActive", "NO", "-appAppearance", "dark",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        let button = app.buttons["spor-wave-button"]
        waitForWaveReady(button)
        XCTAssertTrue(button.isHittable)
        XCTAssertTrue(app.frame.contains(button.frame))
        XCTAssertGreaterThanOrEqual(button.frame.width, 44)
        XCTAssertGreaterThanOrEqual(button.frame.height, 44)
        XCTAssertTrue(app.buttons["tab-log-food"].isHittable)
        button.tap()
        Thread.sleep(forTimeInterval: 0.5)
        XCTAssertEqual(button.value as? String, "Vinker")
        let screenshot = app.screenshot()
        try assertArtworkKeepsColor(screenshot, button: button, app: app)
        keep(screenshot, "Home – tap greeting with largest text")
        app.buttons["Søk"].firstMatch.tap()
        app.buttons["Hjem"].firstMatch.tap()
        waitForWaveReady(button)
    }

    @MainActor private func assertArtworkKeepsColor(_ screenshot: XCUIScreenshot,
                                                    button: XCUIElement, app: XCUIApplication) throws {
        let source = try XCTUnwrap(screenshot.image.cgImage)
        let scale = CGFloat(source.width) / app.frame.width
        let frame = button.frame
        let region = CGRect(x: frame.minX * scale, y: frame.minY * scale,
                            width: frame.width * scale, height: frame.height * scale)
        XCTAssertGreaterThan(try coralPixels(in: screenshot.image, region: region), 1_000,
                             "Disabling repeated input must not fade the mascot during its greeting")
    }

    @MainActor private func waitForWaveReady(_ button: XCUIElement) {
        XCTAssertTrue(button.waitForExistence(timeout: 20))
        for _ in 0..<18 {
            if button.isEnabled { return }
            Thread.sleep(forTimeInterval: 0.5)
        }
        XCTFail("Spor should become available after one greeting")
    }

    @MainActor private func qaApplication(requiresMotion: Bool) throws -> XCUIApplication {
        guard ProcessInfo.processInfo.environment["SPOR_QA_APP_BUNDLE_ID"]
                == "com.nithusan.MatLogg.spor-integration-qa" else {
            throw XCTSkip("Requires the isolated Spor integration QA app")
        }
        if requiresMotion && UIAccessibility.isReduceMotionEnabled {
            throw XCTSkip("Disable Reduce Motion on the QA device to verify animation")
        }
        continueAfterFailure = false
        return XCUIApplication(bundleIdentifier: "com.nithusan.MatLogg.spor-integration-qa")
    }
    private func introArguments(appearance: String = "light") -> [String] {
        ["-ml_local_profile", "", "-ml_local_mode_active", "NO", "-demoModeActive", "NO", "-appAppearance", appearance]
    }
    @MainActor private func keep(_ screenshot: XCUIScreenshot, _ name: String) {
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
    @MainActor private func mascotRegion(in screenshot: XCUIScreenshot,
                                           button: XCUIElement, app: XCUIApplication) throws -> Region {
        let source = try XCTUnwrap(screenshot.image.cgImage)
        let scale = CGFloat(source.width) / app.frame.width
        let frame = button.frame.offsetBy(dx: -app.frame.minX, dy: -app.frame.minY)
        return .mascot(CGRect(x: frame.minX * scale, y: frame.minY * scale,
                              width: frame.width * scale, height: frame.height * scale).integral)
    }

    private enum Region { case intro, mascot(CGRect) }
    private func changedPixels(_ first: XCUIScreenshot, _ second: XCUIScreenshot,
                               region: Region) throws -> Int {
        let a = try regionBytes(first.image, region: region)
        let b = try regionBytes(second.image, region: region)
        XCTAssertEqual(a.count, b.count)
        guard a.count == b.count else { return Int.max }
        var count = 0
        for offset in stride(from: 0, to: a.count, by: 4) {
            let red = abs(Int(a[offset]) - Int(b[offset]))
            let green = abs(Int(a[offset + 1]) - Int(b[offset + 1]))
            let blue = abs(Int(a[offset + 2]) - Int(b[offset + 2]))
            if max(red, max(green, blue)) > 12 { count += 1 }
        }
        return count
    }
    private func regionBytes(_ image: UIImage, region: Region) throws -> [UInt8] {
        let source = try XCTUnwrap(image.cgImage)
        let w = CGFloat(source.width), h = CGFloat(source.height)
        let rect: CGRect
        switch region {
        case .intro: rect = CGRect(x: 0, y: h * 0.15, width: w, height: h * 0.28)
        case .mascot(let bounds): rect = bounds
        }
        let crop = try XCTUnwrap(source.cropping(to: rect))
        var bytes = [UInt8](repeating: 0, count: crop.width * crop.height * 4)
        try bytes.withUnsafeMutableBytes { buffer in
            let context = try XCTUnwrap(CGContext(data: buffer.baseAddress,
                width: crop.width, height: crop.height, bitsPerComponent: 8, bytesPerRow: crop.width * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(crop, in: CGRect(x: 0, y: 0, width: crop.width, height: crop.height))
        }
        return bytes
    }

    /// Only inspect the illustration area, excluding the pink action button.
    private func coralPixels(in image: UIImage, region requestedRegion: CGRect? = nil) throws -> Int {
        let source = try XCTUnwrap(image.cgImage)
        let region = requestedRegion ?? CGRect(x: 0, y: CGFloat(source.height) * 0.15,
                            width: CGFloat(source.width), height: CGFloat(source.height) * 0.28)
        let crop = try XCTUnwrap(source.cropping(to: region))
        let width = crop.width, height = crop.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        return try bytes.withUnsafeMutableBytes { buffer in
            let context = try XCTUnwrap(CGContext(data: buffer.baseAddress,
                width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(crop, in: CGRect(x: 0, y: 0, width: width, height: height))
            let values = buffer.bindMemory(to: UInt8.self)
            var count = 0
            for offset in stride(from: 0, to: values.count, by: 4) {
                let red = Int(values[offset]), green = Int(values[offset + 1]), blue = Int(values[offset + 2])
                if red > 200, green > 75, green < 200, blue > 50, blue < 180,
                   Double(red) > Double(green) * 1.2 { count += 1 }
            }
            return count
        }
    }
}
