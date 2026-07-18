import AppIntents
import Foundation

extension WritingLanguage: AppEnum {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Target Language")
    static let caseDisplayRepresentations: [WritingLanguage: DisplayRepresentation] = [
        .english: "English",
        .french: "French",
        .spanish: "Spanish",
        .german: "German",
        .italian: "Italian",
        .portuguese: "Portuguese",
        .japanese: "Japanese",
        .korean: "Korean",
        .simplifiedChinese: "Simplified Chinese",
    ]
}

struct TransformTextWithSucceedAIIntent: AppIntent {
    static let title: LocalizedStringResource = "Transform Text with SucceedAI"
    static let description = IntentDescription(
        "Rewrite, summarize, translate, or draft text privately with the on-device language model."
    )
    static let supportedModes: IntentModes = .background

    @Parameter(
        title: "Instruction",
        description: "What SucceedAI should do, such as ‘make this concise’ or ‘translate to French’."
    )
    var instruction: String

    @Parameter(
        title: "Text",
        description: "The text to transform. This stays on your device.",
        inputConnectionBehavior: .connectToPreviousIntentResult
    )
    var text: String

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let response = try await LocalTextIntentRunner.transform(
            instruction: instruction,
            text: text
        )
        return .result(value: response)
    }

    static func request(instruction: String, text: String) -> String {
        WritingRequest.transformation(instruction: instruction, sourceText: text)
    }
}

struct PolishTextWithSucceedAIIntent: AppIntent {
    static let title: LocalizedStringResource = "Polish Text with SucceedAI"
    static let description = IntentDescription(
        "Improve clarity, grammar, and flow while preserving the original meaning."
    )
    static let supportedModes: IntentModes = .background
    static let writingInstruction = WritingAction.polish.instruction(targetLanguage: .english)

    @Parameter(
        title: "Text",
        description: "The writing to polish privately on this device.",
        inputConnectionBehavior: .connectToPreviousIntentResult
    )
    var text: String

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let response = try await LocalTextIntentRunner.transform(
            instruction: Self.writingInstruction,
            text: text
        )
        return .result(value: response)
    }
}

struct ShortenTextWithSucceedAIIntent: AppIntent {
    static let title: LocalizedStringResource = "Shorten Text with SucceedAI"
    static let description = IntentDescription(
        "Make writing concise while retaining necessary facts and commitments."
    )
    static let supportedModes: IntentModes = .background
    static let writingInstruction = WritingAction.shorten.instruction(targetLanguage: .english)

    @Parameter(
        title: "Text",
        description: "The writing to shorten privately on this device.",
        inputConnectionBehavior: .connectToPreviousIntentResult
    )
    var text: String

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let response = try await LocalTextIntentRunner.transform(
            instruction: Self.writingInstruction,
            text: text
        )
        return .result(value: response)
    }
}

struct SummarizeTextWithSucceedAIIntent: AppIntent {
    static let title: LocalizedStringResource = "Summarize Text with SucceedAI"
    static let description = IntentDescription(
        "Create a concise summary that preserves key facts and action items."
    )
    static let supportedModes: IntentModes = .background
    static let writingInstruction = WritingAction.summarize.instruction(targetLanguage: .english)

    @Parameter(
        title: "Text",
        description: "The text to summarize privately on this device.",
        inputConnectionBehavior: .connectToPreviousIntentResult
    )
    var text: String

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let response = try await LocalTextIntentRunner.transform(
            instruction: Self.writingInstruction,
            text: text
        )
        return .result(value: response)
    }
}

struct ExtractActionItemsWithSucceedAIIntent: AppIntent {
    static let title: LocalizedStringResource = "Extract Action Items with SucceedAI"
    static let description = IntentDescription(
        "Extract next steps, owners, dates, and dependencies without inventing details."
    )
    static let supportedModes: IntentModes = .background
    static let writingInstruction = WritingAction.actionItems.instruction(targetLanguage: .english)

    @Parameter(
        title: "Notes",
        description: "The notes or update to turn into action items on this device.",
        inputConnectionBehavior: .connectToPreviousIntentResult
    )
    var text: String

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let response = try await LocalTextIntentRunner.transform(
            instruction: Self.writingInstruction,
            text: text
        )
        return .result(value: response)
    }
}

struct PlanFromNotesWithSucceedAIIntent: AppIntent {
    static let title: LocalizedStringResource = "Make a Plan with SucceedAI"
    static let description = IntentDescription(
        "Turn rough notes into an ordered plan with priorities, dependencies, and next actions."
    )
    static let supportedModes: IntentModes = .background
    static let writingInstruction = WritingAction.plan.instruction(targetLanguage: .english)

    @Parameter(
        title: "Notes",
        description: "The goals, constraints, or notes to organize privately on this device.",
        inputConnectionBehavior: .connectToPreviousIntentResult
    )
    var text: String

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let response = try await LocalTextIntentRunner.transform(
            instruction: Self.writingInstruction,
            text: text
        )
        return .result(value: response)
    }
}

struct DraftReplyWithSucceedAIIntent: AppIntent {
    static let title: LocalizedStringResource = "Draft Reply with SucceedAI"
    static let description = IntentDescription(
        "Write a warm, professional reply without inventing missing facts."
    )
    static let supportedModes: IntentModes = .background
    static let writingInstruction = WritingAction.reply.instruction(targetLanguage: .english)

    @Parameter(
        title: "Message",
        description: "The message to answer privately on this device.",
        inputConnectionBehavior: .connectToPreviousIntentResult
    )
    var text: String

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let response = try await LocalTextIntentRunner.transform(
            instruction: Self.writingInstruction,
            text: text
        )
        return .result(value: response)
    }
}

struct TranslateTextWithSucceedAIIntent: AppIntent {
    static let title: LocalizedStringResource = "Translate Text with SucceedAI"
    static let description = IntentDescription(
        "Translate text locally while preserving meaning, tone, names, and formatting."
    )
    static let supportedModes: IntentModes = .background

    @Parameter(
        title: "Text",
        description: "The text to translate privately on this device.",
        inputConnectionBehavior: .connectToPreviousIntentResult
    )
    var text: String

    @Parameter(
        title: "Target Language",
        description: "The language for the translated result."
    )
    var targetLanguage: WritingLanguage

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let response = try await LocalTextIntentRunner.transform(
            instruction: targetLanguage.translationInstruction,
            text: text
        )
        return .result(value: response)
    }
}

struct SucceedAIShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: TransformTextWithSucceedAIIntent(),
            phrases: [
                "Transform text with \(.applicationName)",
                "Rewrite with \(.applicationName)",
                "Use \(.applicationName) on this text",
            ],
            shortTitle: "Transform Text",
            systemImageName: "wand.and.sparkles"
        )
        AppShortcut(
            intent: PolishTextWithSucceedAIIntent(),
            phrases: [
                "Polish writing with \(.applicationName)",
                "Improve my writing with \(.applicationName)",
            ],
            shortTitle: "Polish Text",
            systemImageName: "text.badge.checkmark"
        )
        AppShortcut(
            intent: ShortenTextWithSucceedAIIntent(),
            phrases: [
                "Shorten text with \(.applicationName)",
                "Make this concise with \(.applicationName)",
            ],
            shortTitle: "Shorten Text",
            systemImageName: "arrow.down.right.and.arrow.up.left"
        )
        AppShortcut(
            intent: SummarizeTextWithSucceedAIIntent(),
            phrases: [
                "Summarize text with \(.applicationName)",
                "Make a summary with \(.applicationName)",
            ],
            shortTitle: "Summarize Text",
            systemImageName: "text.alignleft"
        )
        AppShortcut(
            intent: ExtractActionItemsWithSucceedAIIntent(),
            phrases: [
                "Extract action items with \(.applicationName)",
                "Find next steps with \(.applicationName)",
            ],
            shortTitle: "Action Items",
            systemImageName: "checklist"
        )
        AppShortcut(
            intent: PlanFromNotesWithSucceedAIIntent(),
            phrases: [
                "Make a plan with \(.applicationName)",
                "Plan these notes with \(.applicationName)",
            ],
            shortTitle: "Make a Plan",
            systemImageName: "list.number"
        )
        AppShortcut(
            intent: DraftReplyWithSucceedAIIntent(),
            phrases: [
                "Draft a reply with \(.applicationName)",
                "Write a reply with \(.applicationName)",
            ],
            shortTitle: "Draft Reply",
            systemImageName: "arrowshape.turn.up.left"
        )
        AppShortcut(
            intent: TranslateTextWithSucceedAIIntent(),
            phrases: [
                "Translate text with \(.applicationName)",
                "Translate to \(\.$targetLanguage) with \(.applicationName)",
            ],
            shortTitle: "Translate Text",
            systemImageName: "character.bubble"
        )
    }

    static let shortcutTileColor: ShortcutTileColor = .purple
}

private enum LocalTextIntentRunner {
    static func transform(instruction: String, text: String) async throws -> String {
        guard !instruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIProviderError(userMessage: "Add a writing instruction first.")
        }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIProviderError(userMessage: "Add source text to transform first.")
        }

        let provider = LocalFoundationModelProvider()
        guard provider.availability.isAvailable else {
            throw AIProviderError(userMessage: provider.availability.detail)
        }

        let cancellationBox = AIQueryCancellationBox()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let task = provider.query(
                    TransformTextWithSucceedAIIntent.request(
                        instruction: instruction,
                        text: text
                    )
                ) { result in
                    continuation.resume(with: result)
                }
                cancellationBox.store(task)
            }
        } onCancel: {
            cancellationBox.cancel()
        }
    }
}

private final class AIQueryCancellationBox: @unchecked Sendable {
    private let lock = NSLock()
    private var task: Task<Void, Never>?
    private var isCancelled = false

    func store(_ task: Task<Void, Never>) {
        lock.lock()
        if isCancelled {
            lock.unlock()
            task.cancel()
            return
        }
        self.task = task
        lock.unlock()
    }

    func cancel() {
        lock.lock()
        isCancelled = true
        let task = self.task
        self.task = nil
        lock.unlock()
        task?.cancel()
    }
}
