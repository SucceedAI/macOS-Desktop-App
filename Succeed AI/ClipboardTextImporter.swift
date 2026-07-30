import AppKit
import Foundation

enum ClipboardTextImportResult: Equatable {
    case success(String)
    case empty
    case tooLong
}

enum ClipboardTextImporter {
    static let maximumUTF16Length = 20_000

    static func validate(_ text: String?) -> ClipboardTextImportResult {
        guard let text,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .empty
        }
        guard text.utf16.count <= maximumUTF16Length else {
            return .tooLong
        }
        return .success(text)
    }

    static func read(from pasteboard: NSPasteboard = .general) -> ClipboardTextImportResult {
        validate(pasteboard.string(forType: .string))
    }
}
