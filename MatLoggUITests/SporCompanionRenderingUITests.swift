import XCTest
import UIKit

/// Run only against the separate QA app; never changes a user's ordinary app.
final class SporCompanionRenderingUITests: XCTestCase {
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
        let app = try qaApplication(requiresMotion: true)
        // Empty argument-domain value opens the daily gate in this first QA
        // process. The date it writes still persists in the application domain.
        app.launchArguments = ["--skip-auth", "-demoModeActive", "NO", "-appAppearance", "light",
                               "-spor.lastHomeGreeting", ""]
        app.launch()
        XCTAssertTrue(app.buttons["tab-log-food"].waitForExistence(timeout: 20))
        Thread.sleep(forTimeInterval: 0.5)
        let moving = app.screenshot()
        Thread.sleep(forTimeInterval: 1)
        let movingAgain = app.screenshot()
        keep(moving, "Home – animation frame 1")
        keep(movingAgain, "Home – animation frame 2")
        XCTAssertGreaterThan(try changedPixels(moving, movingAgain, region: .home), 40)
        app.terminate()
        // Remove the override: subsequent processes use the real persisted date.
        app.launchArguments = ["--skip-auth", "-demoModeActive", "NO", "-appAppearance", "light"]
        app.launch()
        XCTAssertTrue(app.buttons["tab-log-food"].waitForExistence(timeout: 20))
        let still = app.screenshot()
        Thread.sleep(forTimeInterval: 1)
        let stillAgain = app.screenshot()
        keep(still, "Home – persisted daily gate after restart")
        XCTAssertLessThan(try changedPixels(still, stillAgain, region: .home), 20)
        app.buttons["Søk"].firstMatch.tap()
        app.buttons["Hjem"].firstMatch.tap()
        Thread.sleep(forTimeInterval: 0.5)
        let afterNavigation = app.screenshot()
        XCTAssertLessThan(try changedPixels(stillAgain, afterNavigation, region: .home), 20)
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(app.buttons["tab-log-food"].waitForExistence(timeout: 10))
        let afterBackground = app.screenshot()
        keep(afterBackground, "Home – unchanged after background")
        XCTAssertLessThan(try changedPixels(stillAgain, afterBackground, region: .home), 20)
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
    private enum Region { case intro, home }
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
        let rect = region == .intro
            ? CGRect(x: 0, y: h * 0.15, width: w, height: h * 0.28)
            : CGRect(x: w * 0.77, y: h * 0.14, width: w * 0.21, height: h * 0.10)
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
    private func coralPixels(in image: UIImage) throws -> Int {
        let source = try XCTUnwrap(image.cgImage)
        let region = CGRect(x: 0, y: CGFloat(source.height) * 0.15,
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
