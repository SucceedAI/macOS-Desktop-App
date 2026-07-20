import XCTest

final class SucceedAIKeyboardUITests: XCTestCase {
    private let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testKeyboardTypesRunsAndDismissesACommandInPlace() throws {
        try enableSucceedAIKeyboardIfNeeded()

        // Keep this extension-runtime test independent of App Group signing.
        // Custom trigger sharing is covered by the signed app and unit suite.
        let trigger = "/ai"
        app.launchArguments = [
            "--screenshot-keyboard-surface",
            "--ui-test-keyboard-trigger", trigger
        ]
        app.launchEnvironment["SUCCEEDAI_UI_TEST_RESPONSE"] = "Your reply is clear, concise, and ready to send."
        app.launch()

        let editor = app.textViews["composer-editor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 8))
        editor.tap()

        try switchToSucceedAIKeyboard(trigger: trigger)

        let insertTrigger = app.buttons["Insert \(trigger)"]
        XCTAssertTrue(insertTrigger.waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["q"].exists, "The SucceedAI typing pad did not appear.")
        insertTrigger.tap()

        typeOnSucceedAIKeyboard("reply ready")

        let aiReturn = app.buttons["AI Return"]
        XCTAssertTrue(aiReturn.waitForExistence(timeout: 3))
        aiReturn.tap()

        let commandWasReplaced = NSPredicate { _, _ in
            let value = editor.value as? String ?? ""
            return !value.hasPrefix("\(trigger) ") && !value.isEmpty
        }
        expectation(for: commandWasReplaced, evaluatedWith: editor)
        waitForExpectations(timeout: 60)
        XCTAssertTrue(app.buttons["Undo"].waitForExistence(timeout: 3))

        let dismissKeyboard = app.buttons["dismiss-keyboard"]
        XCTAssertTrue(dismissKeyboard.waitForExistence(timeout: 3))
        let completedReplacement = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        completedReplacement.name = "SucceedAI keyboard completed local replacement"
        completedReplacement.lifetime = .keepAlways
        add(completedReplacement)
        dismissKeyboard.tap()
        let keyboardClosed = NSPredicate { _, _ in !insertTrigger.exists }
        expectation(for: keyboardClosed, evaluatedWith: insertTrigger)
        waitForExpectations(timeout: 5)
    }

    private func enableSucceedAIKeyboardIfNeeded() throws {
        let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        settings.launch()

        navigateToSettingsRoot(settings)
        tapCell("General", in: settings)
        tapCell("Keyboard", in: settings)
        tapCell("Keyboards", in: settings)

        if settings.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'Succeed AI'")).firstMatch.exists {
            settings.terminate()
            return
        }

        let addKeyboard = settings.buttons["AddNewKeyboard"]
        XCTAssertTrue(addKeyboard.waitForExistence(timeout: 5), settings.debugDescription)
        addKeyboard.tap()

        let succeedAI = settings.cells["me.ph7.Succeed-AI"]
        XCTAssertTrue(succeedAI.waitForExistence(timeout: 8), settings.debugDescription)
        succeedAI.tap()
        settings.terminate()
    }

    private func navigateToSettingsRoot(_ settings: XCUIApplication) {
        for _ in 0..<6 {
            if settings.navigationBars["Settings"].exists { return }
            let backButton = settings.navigationBars.buttons.element(boundBy: 0)
            guard backButton.exists else { return }
            backButton.tap()
        }
    }

    private func tapCell(_ label: String, in app: XCUIApplication) {
        let containingCell = app.cells.containing(.staticText, identifier: label).firstMatch
        if containingCell.waitForExistence(timeout: 5) {
            containingCell.tap()
            return
        }

        let exactButton = app.buttons[label].firstMatch
        XCTAssertTrue(exactButton.waitForExistence(timeout: 5), app.debugDescription)
        exactButton.tap()
    }

    private func switchToSucceedAIKeyboard(trigger: String) throws {
        let insertTrigger = app.buttons["Insert \(trigger)"]
        for _ in 0..<5 {
            if insertTrigger.exists { return }

            let nextKeyboard = app.descendants(matching: .any).matching(
                NSPredicate(format: "label CONTAINS[c] 'keyboard' OR label CONTAINS[c] 'globe'")
            ).firstMatch
            if nextKeyboard.waitForExistence(timeout: 1), nextKeyboard.isHittable {
                nextKeyboard.tap()
            } else {
                // iOS 26 does not always publish the system globe key into the
                // host application's accessibility tree. Its bottom-leading
                // placement is stable across Apple's portrait keyboards.
                app.coordinate(withNormalizedOffset: CGVector(dx: 0.11, dy: 0.94)).tap()
            }

            if insertTrigger.waitForExistence(timeout: 2) { return }
        }
        XCTFail("SucceedAI Keyboard could not be selected from the enabled keyboard list.")
    }

    private func typeOnSucceedAIKeyboard(_ text: String) {
        for character in text {
            let label = character == " " ? "space" : String(character)
            let key = app.buttons[label]
            XCTAssertTrue(key.waitForExistence(timeout: 2), "Missing SucceedAI key: \(label)")
            key.tap()
        }
    }
}
