import Foundation

enum UserSettings {
    static let commandTriggerKey = "commandTrigger"
    static let defaultCommandTrigger = Config.keystrokePrefixTrigger

    static func commandTrigger(from defaults: UserDefaults = .standard) -> String {
        validatedCommandTrigger(defaults.string(forKey: commandTriggerKey))
    }

    static func validatedCommandTrigger(_ value: String?) -> String {
        guard let value, isValidCommandTrigger(value) else {
            return defaultCommandTrigger
        }

        return normalizedCommandTrigger(value)
    }

    static func normalizedCommandTrigger(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return defaultCommandTrigger }

        return "\(trimmed) "
    }

    static func isValidCommandTrigger(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count >= 2 && !trimmed.contains(where: { $0.isWhitespace })
    }
}
