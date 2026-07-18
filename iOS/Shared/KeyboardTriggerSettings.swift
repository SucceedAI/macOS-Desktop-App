import Foundation

enum KeyboardTriggerSettings {
    static let appGroupIdentifier = "group.me.ph7.succeedai"
    static let storageKey = "iOSKeyboardCommandTrigger"
    static let defaultTrigger = "/ai"

    static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: appGroupIdentifier) ?? .standard
    }

    static func load(from defaults: UserDefaults = sharedDefaults) -> String {
        validated(defaults.string(forKey: storageKey)) ?? defaultTrigger
    }

    @discardableResult
    static func save(_ value: String, to defaults: UserDefaults = sharedDefaults) -> Bool {
        guard let trigger = validated(value) else { return false }
        defaults.set(trigger, forKey: storageKey)
        return true
    }

    static func restoreDefault(in defaults: UserDefaults = sharedDefaults) {
        defaults.removeObject(forKey: storageKey)
    }

    static func validated(_ value: String?) -> String? {
        guard let value else { return nil }
        let trigger = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (2...12).contains(trigger.count),
              let firstScalar = trigger.unicodeScalars.first,
              Self.allowedLeadingCharacters.contains(firstScalar),
              trigger.unicodeScalars.allSatisfy(Self.allowedCharacters.contains) else {
            return nil
        }
        return trigger
    }

    static func commandPrefix(for trigger: String) -> String {
        "\(validated(trigger) ?? defaultTrigger) "
    }

    private static let allowedLeadingCharacters = CharacterSet(charactersIn: "/;:!@#")
    private static let allowedCharacters = CharacterSet.alphanumerics.union(
        CharacterSet(charactersIn: "/;:!@#._-")
    )
}
