import Foundation

struct KeyboardDocumentIdentity {
    private let fallbackIdentifier = UUID()

    func resolve(_ documentIdentifier: UUID?) -> UUID {
        documentIdentifier ?? fallbackIdentifier
    }
}

struct KeyboardCommand: Equatable {
    let fullText: String
    let request: String

    static func find(in context: String?, trigger: String) -> KeyboardCommand? {
        guard let context else { return nil }
        let prefix = KeyboardTriggerSettings.commandPrefix(for: trigger)
        guard let triggerRange = context.range(of: prefix, options: .backwards) else { return nil }

        let fullText = String(context[triggerRange.lowerBound...])
        let request = String(context[triggerRange.upperBound...])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return KeyboardCommand(fullText: fullText, request: request)
    }
}

enum KeyboardReplacementSafety {
    static func canApply(
        command: String,
        expectedContext: String,
        currentContext: String?
    ) -> Bool {
        guard !command.isEmpty,
              expectedContext.hasSuffix(command),
              let currentContext else { return false }
        return currentContext == expectedContext
    }
}

struct KeyboardUndoSnapshot: Equatable {
    static let anchorLength = 96

    let documentIdentifier: UUID
    let originalText: String
    let replacementText: String
    let contextBeforeAnchor: String
    let contextAfterAnchor: String

    init?(
        documentIdentifier: UUID,
        originalText: String,
        replacementText: String,
        expectedContextBefore: String,
        expectedContextAfter: String
    ) {
        guard !originalText.isEmpty, !replacementText.isEmpty else { return nil }
        self.documentIdentifier = documentIdentifier
        self.originalText = originalText
        self.replacementText = replacementText
        self.contextBeforeAnchor = String(expectedContextBefore.suffix(Self.anchorLength))
        self.contextAfterAnchor = String(expectedContextAfter.prefix(Self.anchorLength))
    }

    func matches(
        documentIdentifier: UUID,
        selectedText: String?,
        contextBefore: String?,
        contextAfter: String?
    ) -> Bool {
        guard documentIdentifier == self.documentIdentifier,
              selectedText == nil || selectedText?.isEmpty == true,
              Self.matchesSuffix(contextBeforeAnchor, in: contextBefore),
              Self.matchesPrefix(contextAfterAnchor, in: contextAfter) else {
            return false
        }
        return true
    }

    private static func matchesSuffix(_ anchor: String, in context: String?) -> Bool {
        anchor.isEmpty ? context?.isEmpty != false : context?.hasSuffix(anchor) == true
    }

    private static func matchesPrefix(_ anchor: String, in context: String?) -> Bool {
        anchor.isEmpty ? context?.isEmpty != false : context?.hasPrefix(anchor) == true
    }
}

struct KeyboardSelectionSnapshot: Equatable {
    static let anchorLength = 96

    let documentIdentifier: UUID
    let selectedText: String
    let contextBeforeAnchor: String
    let contextAfterAnchor: String

    init?(
        documentIdentifier: UUID,
        selectedText: String?,
        contextBefore: String?,
        contextAfter: String?
    ) {
        guard let selectedText,
              !selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        self.documentIdentifier = documentIdentifier
        self.selectedText = selectedText
        self.contextBeforeAnchor = String((contextBefore ?? "").suffix(Self.anchorLength))
        self.contextAfterAnchor = String((contextAfter ?? "").prefix(Self.anchorLength))
    }

    func matches(
        documentIdentifier: UUID,
        selectedText: String?,
        contextBefore: String?,
        contextAfter: String?
    ) -> Bool {
        guard documentIdentifier == self.documentIdentifier,
              selectedText == self.selectedText,
              Self.matchesSuffix(contextBeforeAnchor, in: contextBefore),
              Self.matchesPrefix(contextAfterAnchor, in: contextAfter) else {
            return false
        }
        return true
    }

    func replacementPreservingBoundaryWhitespace(_ response: String) -> String {
        let leadingWhitespace = selectedText.prefix(while: \.isWhitespace)
        let trailingWhitespace = selectedText.reversed().prefix(while: \.isWhitespace).reversed()
        let finishedText = response.trimmingCharacters(in: .whitespacesAndNewlines)
        return String(leadingWhitespace) + finishedText + String(trailingWhitespace)
    }

    private static func matchesSuffix(_ anchor: String, in context: String?) -> Bool {
        anchor.isEmpty || context?.hasSuffix(anchor) == true
    }

    private static func matchesPrefix(_ anchor: String, in context: String?) -> Bool {
        anchor.isEmpty || context?.hasPrefix(anchor) == true
    }
}
