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
