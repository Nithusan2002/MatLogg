import XCTest

final class LoggingDraftUITests: XCTestCase {
    @MainActor func testManualInputSurvivesTerminationAndAmountReopens() throws {
        try runRecovery(abrupt: false, largeText: false)
    }

    @MainActor func testImmediateTerminationAfterTyping() throws {
        try runRecovery(abrupt: true, largeText: false)
    }

    @MainActor func testRecoveryWithLargestTextAndAccessibilityAudit() throws {
        try runRecovery(abrupt: false, largeText: true)
    }

    @MainActor private func runRecovery(abrupt: Bool, largeText: Bool) throws {
        continueAfterFailure = false
        var auditFindings: [String] = []
        let app = XCUIApplication()
        app.launchArguments = ["--skip-auth", "-UIPreferredContentSizeCategoryName", largeText ? "UICTContentSizeCategoryAccessibilityXXXL" : "UICTContentSizeCategoryL"]
        app.launch()
        XCTAssertTrue(app.buttons["tab-log-food"].waitForExistence(timeout: 15))
        // Remove only an unfinished draft on this dedicated QA profile.
        if app.buttons["logging-draft-discard"].exists {
            app.buttons["logging-draft-discard"].tap()
            let confirmation = app.buttons.matching(NSPredicate(format: "label == %@ AND identifier != %@", "Forkast", "logging-draft-discard")).firstMatch
            XCTAssertTrue(confirmation.waitForExistence(timeout: 5))
            confirmation.tap()
            XCTAssertTrue(app.buttons["logging-draft-discard"].waitForNonExistence(timeout: 5))
        }
        app.buttons["tab-log-food"].tap()
        let manual = app.buttons["quick-log-manual"]
        XCTAssertTrue(manual.waitForExistence(timeout: 8))
        manual.tap()
        let name = app.textFields["Produktnavn"]
        XCTAssertTrue(name.waitForExistence(timeout: 8))
        name.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        name.typeText("Utkast QA")
        for (label, value) in [("Energi", "100"), ("Protein", "10"), ("Karbohydrat", "10"), ("Fett", "2")] {
            let field = app.textFields[label]
            for _ in 0..<5 { if field.isHittable { break }; app.swipeUp() }
            field.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
            field.typeText(value)
        }
        // Allow the 300 ms autosave and SQLite commit to complete before killing the process.
        if !abrupt {
        let saved = expectation(description: "autosave window")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { saved.fulfill() }
        wait(for: [saved], timeout: 3)
        }
        // XCTest termination has IPC latency; this does not prove survival within 300 ms.
        app.terminate(); app.launch()
        let resume = app.buttons["logging-draft-continue"].firstMatch
        XCTAssertTrue(resume.waitForExistence(timeout: 12))
        for _ in 0..<5 { if resume.isHittable { break }; app.swipeUp() }
        let recovery = XCTAttachment(screenshot: app.screenshot())
        recovery.name = "Utkast etter terminering"; recovery.lifetime = .keepAlways; add(recovery)
        if largeText {
            try app.performAccessibilityAudit(for: [.dynamicType, .textClipped, .sufficientElementDescription, .hitRegion]) { issue in
                auditFindings.append("\(issue.auditType): \(issue.element?.debugDescription ?? "unknown element")")
                return true // Collect all issues, then fail explicitly after exercising the full flow.
            }
        }
        for _ in 0..<8 {
            if resume.isHittable && resume.frame.maxY < app.buttons["tab-log-food"].frame.minY { break }
            app.scrollViews.firstMatch.swipeUp()
        }
        if largeText {
            let menu = app.scrollViews["matlogg-tab-bar-scroll"]
            XCTAssertTrue(menu.exists)
            menu.swipeLeft()
            XCTAssertTrue(app.buttons["Profil"].firstMatch.isHittable)
            try app.performAccessibilityAudit(for: [.dynamicType, .textClipped, .sufficientElementDescription, .hitRegion]) { issue in
                auditFindings.append("\(issue.auditType): \(issue.element?.debugDescription ?? "unknown element")")
                return true
            }
            for _ in 0..<8 {
                if resume.isHittable && resume.frame.maxY < app.buttons["tab-log-food"].frame.minY { break }
                app.scrollViews.firstMatch.swipeUp()
            }
        }
        resume.tap()
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        XCTAssertEqual(name.value as? String, "Utkast QA")
        let next = app.buttons["Lagre og velg mengde"]
        for _ in 0..<6 { if next.isHittable { break }; app.swipeUp() }
        next.tap()
        XCTAssertTrue(app.buttons["logging-draft-save"].waitForExistence(timeout: 8))
        app.buttons["Lukk"].tap()
        app.terminate(); app.launch()
        XCTAssertTrue(resume.waitForExistence(timeout: 12))
        for _ in 0..<8 {
            if resume.isHittable && resume.frame.maxY < app.buttons["tab-log-food"].frame.minY { break }
            app.scrollViews.firstMatch.swipeUp()
        }
        resume.tap()
        XCTAssertTrue(app.buttons["logging-draft-save"].waitForExistence(timeout: 8))
        if largeText {
            let save = app.buttons["logging-draft-save"]
            for _ in 0..<8 { if save.isHittable { break }; app.swipeUp() }
            try app.performAccessibilityAudit(for: [.dynamicType, .textClipped, .sufficientElementDescription, .hitRegion]) { issue in
                auditFindings.append("\(issue.auditType): \(issue.element?.debugDescription ?? "unknown element")")
                return true // Collect all issues, then fail explicitly after exercising the full flow.
            }
        }
        app.buttons["logging-draft-save"].tap()
        XCTAssertFalse(app.buttons["logging-draft-continue"].waitForExistence(timeout: 2))
        XCTAssertTrue(auditFindings.isEmpty, auditFindings.joined(separator: "\n"))
    }
}
