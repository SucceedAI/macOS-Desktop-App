import XCTest
@testable import SucceedAI

final class Succeed_AITests: XCTestCase {
    func testUserSettingsNormalizesCommandTrigger() {
        XCTAssertEqual(UserSettings.normalizedCommandTrigger("/ai"), "/ai ")
        XCTAssertEqual(UserSettings.normalizedCommandTrigger(" ;ai "), ";ai ")
        XCTAssertEqual(UserSettings.normalizedCommandTrigger(""), Config.keystrokePrefixTrigger)
    }

    func testUserSettingsRejectsEmptyCommandTrigger() {
        XCTAssertFalse(UserSettings.isValidCommandTrigger(""))
        XCTAssertFalse(UserSettings.isValidCommandTrigger("   "))
        XCTAssertFalse(UserSettings.isValidCommandTrigger("a"))
        XCTAssertFalse(UserSettings.isValidCommandTrigger("/ai now"))
        XCTAssertTrue(UserSettings.isValidCommandTrigger(";ai"))
    }

    func testUserSettingsReadsCommandTriggerFromDefaults() {
        let suiteName = "SucceedAI.Tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.set(";ask", forKey: UserSettings.commandTriggerKey)

        XCTAssertEqual(UserSettings.commandTrigger(from: defaults), ";ask ")

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testUserSettingsFallsBackWhenSavedCommandTriggerIsInvalid() {
        let suiteName = "SucceedAI.Tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.set("a", forKey: UserSettings.commandTriggerKey)

        XCTAssertEqual(UserSettings.commandTrigger(from: defaults), Config.keystrokePrefixTrigger)

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testSystemUtilityNamesModernMacOSVersions() {
        XCTAssertEqual(SystemUtility.getOSName(version: OperatingSystemVersion(majorVersion: 14, minorVersion: 0, patchVersion: 0)), "macOS Sonoma")
        XCTAssertEqual(SystemUtility.getOSName(version: OperatingSystemVersion(majorVersion: 15, minorVersion: 0, patchVersion: 0)), "macOS Sequoia")
        XCTAssertEqual(SystemUtility.getOSName(version: OperatingSystemVersion(majorVersion: 26, minorVersion: 0, patchVersion: 0)), "macOS Tahoe")
    }

    func testServerApiProviderWrapsInstructions() {
        let provider = ServerApiProvider(apiKey: "test-api-key", apiUrl: "https://example.com/v1/ai")

        let instructions = provider.getAiInstructions("Summarize this")

        XCTAssertTrue(instructions.contains("\"\"\"Summarize this\"\"\""))
        XCTAssertTrue(instructions.contains("ONLY the needed response"))
    }

    func testServerApiProviderFailsFastWhenApiKeyMissing() {
        let provider = ServerApiProvider(apiKey: "api_key", apiUrl: "https://example.com/v1/ai")
        let expectation = expectation(description: "Completion called")

        provider.query("hello") { response in
            XCTAssertEqual(response, .failure(AIProviderError(userMessage: "SucceedAI is not configured: missing API key.")))
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }
}
