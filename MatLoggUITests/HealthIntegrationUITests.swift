import XCTest

final class HealthIntegrationUITests: XCTestCase {
    @MainActor
    func testChoicesPersistAndDisconnectWithLargeTextUsingFakeHealthKit() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--skip-auth", "--enable-healthkit", "--healthkit-fake",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        func tapVisible(_ element: XCUIElement) {
            for _ in 0..<8 {
                if element.exists && element.isHittable {
                    if element.elementType == .switch {
                        // A multiline SwiftUI switch label may be hittable while its knob is under the tab bar.
                        let frame = element.frame
                        if frame.maxY > app.frame.maxY - 120 { app.swipeUp(); continue }
                        if frame.minY < app.frame.minY + 100 { app.swipeDown(); continue }
                        element.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
                    } else { element.tap() }
                    return
                }
                app.swipeUp()
            }
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.lifetime = .keepAlways
            add(screenshot)
            let hierarchy = XCTAttachment(string: app.debugDescription)
            hierarchy.lifetime = .keepAlways
            add(hierarchy)
            XCTFail("Control must be reachable above the tab bar: \(element.identifier)")
        }
        func openHealth() {
            tapVisible(app.buttons["Profil"])
            tapVisible(app.buttons.matching(NSPredicate(format: "label CONTAINS 'Apple Helse'")).firstMatch)
        }
        func disconnectIfConnected() {
            let disconnect = app.buttons["health-disconnect"]
            if disconnect.exists {
                tapVisible(disconnect)
                tapVisible(app.buttons["Koble fra"])
                let disconnected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == '0'"), object: app.switches["health-share-nutrition"])
                if XCTWaiter.wait(for: [disconnected], timeout: 5) != .completed {
                    let hierarchy = XCTAttachment(string: app.debugDescription)
                    hierarchy.lifetime = .keepAlways
                    add(hierarchy)
                    let screenshot = XCTAttachment(screenshot: app.screenshot())
                    screenshot.lifetime = .keepAlways
                    add(screenshot)
                }
                // Return to the toggles so the next interaction addresses the rendered controls.
                for _ in 0..<5 { app.swipeDown() }
            }
        }
        app.launch()
        openHealth()
        disconnectIfConnected()
        let nutrition = app.switches["health-share-nutrition"]
        let read = app.switches["health-read-weight"]
        XCTAssertEqual(nutrition.value as? String, "0")
        XCTAssertEqual(read.value as? String, "0")
        tapVisible(nutrition)
        tapVisible(read)
        XCTAssertEqual(read.value as? String, "1")
        tapVisible(app.buttons["health-connect"])
        let update = app.buttons["health-refresh"]
        XCTAssertTrue(update.waitForExistence(timeout: 10))
        // Fake HealthKit has no samples. The UI must not claim that read access was granted.
        let empty = app.staticTexts["Ingen tilgjengelige vektmålinger. Kontroller at det finnes data, og at MatLogg har tilgang i Helse."]
        for _ in 0..<6 where !empty.exists { app.swipeUp() }
        if !empty.exists {
            let hierarchy = XCTAttachment(string: app.debugDescription)
            hierarchy.lifetime = .keepAlways
            add(hierarchy)
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.lifetime = .keepAlways
            add(screenshot)
        }
        XCTAssertTrue(empty.exists)
        app.terminate()
        app.launch()
        openHealth()
        XCTAssertEqual(app.switches["health-share-nutrition"].value as? String, "1")
        XCTAssertEqual(app.switches["health-read-weight"].value as? String, "1")
        disconnectIfConnected()
        XCTAssertTrue(app.buttons["health-connect"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.switches["health-share-nutrition"].value as? String, "0")
        XCTAssertEqual(app.switches["health-read-weight"].value as? String, "0")
    }
}
