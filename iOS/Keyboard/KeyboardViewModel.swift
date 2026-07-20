import SwiftUI

@MainActor
final class KeyboardViewModel: ObservableObject {
    @Published private(set) var isGenerating = false
    @Published private(set) var status = "Type normally, or insert a private AI command."
    @Published private(set) var isError = false
    @Published private(set) var availability: AIAvailabilityStatus
    @Published private(set) var hasPendingResult = false
    @Published private(set) var hasSelection = false
    @Published private(set) var hasUndoableEdit = false
    @Published private(set) var hasRunnableCommand = false
    @Published private(set) var trigger = KeyboardTriggerSettings.defaultTrigger

    private let provider: AIProvideable
    private let contextBeforeInput: () -> String?
    private let contextAfterInput: () -> String?
    private let selectedText: () -> String?
    private let documentIdentifier: () -> UUID
    private let deleteBackward: () -> Void
    private let insertText: (String) -> Void
    private let triggerProvider: () -> String
    private var pendingEdit: PendingKeyboardEdit?
    private var undoSnapshot: KeyboardUndoSnapshot?
    private var activeRequestID: UUID?
    private var generationTask: Task<Void, Never>?
    private var timeoutTask: Task<Void, Never>?
    private var undoExpirationTask: Task<Void, Never>?
    private var isTrackingCommand = false

    init(
        provider: AIProvideable = LocalFoundationModelProvider(),
        contextBeforeInput: @escaping () -> String?,
        contextAfterInput: @escaping () -> String?,
        selectedText: @escaping () -> String?,
        documentIdentifier: @escaping () -> UUID,
        deleteBackward: @escaping () -> Void,
        insertText: @escaping (String) -> Void,
        triggerProvider: @escaping () -> String = { KeyboardTriggerSettings.load() }
    ) {
        self.provider = provider
        self.availability = provider.availability
        self.contextBeforeInput = contextBeforeInput
        self.contextAfterInput = contextAfterInput
        self.selectedText = selectedText
        self.documentIdentifier = documentIdentifier
        self.deleteBackward = deleteBackward
        self.insertText = insertText
        self.triggerProvider = triggerProvider
        self.trigger = KeyboardTriggerSettings.validated(triggerProvider()) ?? KeyboardTriggerSettings.defaultTrigger
        refreshDocumentContext()
    }

    func refreshDocumentContext() {
        hasSelection = currentSelectionSnapshot() != nil
        let command = currentCommand()
        hasRunnableCommand = command?.request.isEmpty == false
        let nowTrackingCommand = command != nil
        if nowTrackingCommand && !isTrackingCommand {
            provider.prepare()
        }
        isTrackingCommand = nowTrackingCommand
        guard !isGenerating, pendingEdit == nil else { return }
        updateIdleStatus(command: command)
    }

    func refreshSettings() {
        trigger = KeyboardTriggerSettings.validated(triggerProvider()) ?? KeyboardTriggerSettings.defaultTrigger
        isTrackingCommand = false
        refreshDocumentContext()
    }

    func insertTrigger() {
        guard !hasSelection else {
            showError("Deselect the text before inserting a custom \(trigger) command.")
            return
        }
        discardPendingResult()
        discardUndo()
        let prefix = KeyboardTriggerSettings.commandPrefix(for: trigger)
        if contextBeforeInput()?.hasSuffix(prefix) != true {
            insertText(prefix)
        }
        provider.prepare()
        isTrackingCommand = true
        hasRunnableCommand = false
        isError = false
        status = "Type the request, then press AI Return."
        UISelectionFeedbackGenerator().selectionChanged()
    }

    func insertKey(_ key: String) {
        guard !isGenerating else { return }
        insertText(key)
        refreshDocumentContext()
    }

    func deleteKey() {
        guard !isGenerating else { return }
        deleteBackward()
        refreshDocumentContext()
    }

    func handleReturnKey() {
        guard !isGenerating else { return }
        refreshDocumentContext()
        if hasRunnableCommand {
            replaceCommand()
        } else {
            insertText("\n")
            refreshDocumentContext()
        }
    }

    func releasePreparedResources() {
        provider.releasePreparedResources()
    }

    @discardableResult
    func performAction(_ action: WritingAction) -> Bool {
        guard WritingAction.quickActions.contains(action) else { return false }
        discardPendingResult()
        discardUndo()

        if let snapshot = currentSelectionSnapshot() {
            startGeneration(
                request: action.request(sourceText: snapshot.selectedText, targetLanguage: .english),
                progressStatus: "\(action.title) is running privately on your selection…",
                makePendingEdit: { .selection(snapshot: snapshot, response: $0) }
            )
            return false
        }

        insertText("\(KeyboardTriggerSettings.commandPrefix(for: trigger))\(action.instruction(targetLanguage: .english)) ")
        provider.prepare()
        isTrackingCommand = true
        isError = false
        status = "Add the source text, then press AI Return."
        UISelectionFeedbackGenerator().selectionChanged()
        return false
    }

    @discardableResult
    func performTranslation(to language: WritingLanguage) -> Bool {
        discardPendingResult()
        discardUndo()

        if let snapshot = currentSelectionSnapshot() {
            startGeneration(
                request: WritingAction.translate.request(
                    sourceText: snapshot.selectedText,
                    targetLanguage: language
                ),
                progressStatus: "Translating your selection to \(language.displayName) on this device…",
                makePendingEdit: { .selection(snapshot: snapshot, response: $0) }
            )
            return false
        }

        insertText("\(KeyboardTriggerSettings.commandPrefix(for: trigger))\(language.translationInstruction) ")
        provider.prepare()
        isTrackingCommand = true
        isError = false
        status = "Add the source text, then press AI Return."
        UISelectionFeedbackGenerator().selectionChanged()
        return false
    }

    @discardableResult
    func performTone(_ tone: WritingTone) -> Bool {
        discardPendingResult()
        discardUndo()

        if let snapshot = currentSelectionSnapshot() {
            startGeneration(
                request: WritingAction.tone.request(
                    sourceText: snapshot.selectedText,
                    targetLanguage: .english,
                    targetTone: tone
                ),
                progressStatus: "Making your selection \(tone.guidanceDescription) on this device…",
                makePendingEdit: { .selection(snapshot: snapshot, response: $0) }
            )
            return false
        }

        insertText("\(KeyboardTriggerSettings.commandPrefix(for: trigger))\(tone.rewriteInstruction) ")
        provider.prepare()
        isTrackingCommand = true
        isError = false
        status = "Add the source text, then press AI Return."
        UISelectionFeedbackGenerator().selectionChanged()
        return false
    }

    func replaceCommand() {
        guard !isGenerating else { return }
        if pendingEdit != nil {
            insertPendingResult()
            return
        }
        discardUndo()
        availability = provider.availability
        guard availability.isAvailable else {
            showError(availability.detail)
            return
        }
        guard let context = contextBeforeInput(),
              let command = KeyboardCommand.find(in: context, trigger: trigger) else {
            showError("No \(trigger) command found before the cursor.")
            return
        }
        guard !command.request.isEmpty else {
            showError("Add an instruction after \(trigger) first.")
            return
        }

        startGeneration(
            request: command.request,
            progressStatus: "Thinking privately on this device…",
            makePendingEdit: {
                .command(command: command.fullText, expectedContext: context, response: $0)
            }
        )
    }

    func cancelGeneration() {
        guard isGenerating else { return }
        generationTask?.cancel()
        isError = false
        status = "Canceled. Your original text is unchanged."
        finishGeneration()
    }

    func insertPendingResult() {
        guard let pendingEdit else { return }
        guard apply(pendingEdit) else {
            isError = true
            status = pendingEdit.recoveryMessage
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            return
        }
        status = pendingEdit.successMessage
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    func discardPendingResult() {
        self.pendingEdit = nil
        hasPendingResult = false
        guard !isGenerating else { return }
        refreshDocumentContext()
    }

    func undoLastEdit() {
        guard let undoSnapshot else { return }
        guard undoSnapshot.matches(
            documentIdentifier: documentIdentifier(),
            selectedText: selectedText(),
            contextBefore: contextBeforeInput(),
            contextAfter: contextAfterInput()
        ) else {
            isError = true
            status = "Undo paused because the document, cursor, or result changed. Return to the unchanged result and place the cursor immediately after it, or use the app’s Undo command."
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            return
        }

        for _ in undoSnapshot.replacementText { deleteBackward() }
        insertText(undoSnapshot.originalText)
        discardUndo()
        hasSelection = false
        isError = false
        status = "Undone. Your original text is back."
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func startGeneration(
        request: String,
        progressStatus: String,
        makePendingEdit: @escaping (String) -> PendingKeyboardEdit
    ) {
        guard !isGenerating else { return }
        availability = provider.availability
        guard availability.isAvailable else {
            showError(availability.detail)
            return
        }

        isGenerating = true
        isError = false
        status = progressStatus
        let requestID = UUID()
        activeRequestID = requestID
        generationTask = provider.query(request) { [weak self] result in
            Task { @MainActor in
                guard let self, self.activeRequestID == requestID else { return }
                switch result {
                case .success(let response):
                    let pendingEdit = makePendingEdit(response)
                    if self.apply(pendingEdit) {
                        self.status = pendingEdit.successMessage
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    } else {
                        self.pendingEdit = pendingEdit
                        self.hasPendingResult = true
                        self.isError = true
                        self.status = pendingEdit.recoveryMessage
                        UINotificationFeedbackGenerator().notificationOccurred(.warning)
                    }
                case .failure(let error):
                    if error != .cancelled { self.showError(error.userMessage) }
                }
                self.finishGeneration()
            }
        }
        scheduleTimeout(requestID: requestID)
    }

    private func currentSelectionSnapshot() -> KeyboardSelectionSnapshot? {
        KeyboardSelectionSnapshot(
            documentIdentifier: documentIdentifier(),
            selectedText: selectedText(),
            contextBefore: contextBeforeInput(),
            contextAfter: contextAfterInput()
        )
    }

    private func currentCommand() -> KeyboardCommand? {
        KeyboardCommand.find(in: contextBeforeInput(), trigger: trigger)
    }

    private func updateIdleStatus(command: KeyboardCommand?) {
        isError = false
        if hasSelection {
            status = "Selection ready. Tap an action to transform it privately."
        } else if command?.request.isEmpty == false {
            status = "Command ready. Press AI Return for an in-place local result."
        } else if command != nil {
            status = "Type the request, then press AI Return."
        } else {
            status = "Type normally, or tap Insert \(trigger) for private AI anywhere."
        }
    }

    private func apply(_ pendingEdit: PendingKeyboardEdit) -> Bool {
        let undoSnapshot: KeyboardUndoSnapshot?
        switch pendingEdit {
        case .command(let command, let expectedContext, let response):
            guard KeyboardReplacementSafety.canApply(
                command: command,
                expectedContext: expectedContext,
                currentContext: contextBeforeInput()
            ) else { return false }

            let prefix = String(expectedContext.dropLast(command.count))
            undoSnapshot = KeyboardUndoSnapshot(
                documentIdentifier: documentIdentifier(),
                originalText: command,
                replacementText: response,
                expectedContextBefore: prefix + response,
                expectedContextAfter: contextAfterInput() ?? ""
            )
            for _ in command { deleteBackward() }
            insertText(response)

        case .selection(let snapshot, let response):
            guard snapshot.matches(
                documentIdentifier: documentIdentifier(),
                selectedText: selectedText(),
                contextBefore: contextBeforeInput(),
                contextAfter: contextAfterInput()
            ) else { return false }

            let replacement = snapshot.replacementPreservingBoundaryWhitespace(response)
            let contextBefore = contextBeforeInput() ?? ""
            let contextAfter = contextAfterInput() ?? ""
            undoSnapshot = KeyboardUndoSnapshot(
                documentIdentifier: snapshot.documentIdentifier,
                originalText: snapshot.selectedText,
                replacementText: replacement,
                expectedContextBefore: contextBefore + replacement,
                expectedContextAfter: contextAfter
            )
            insertText(replacement)
            hasSelection = false
        }

        installUndoSnapshot(undoSnapshot)
        self.pendingEdit = nil
        hasPendingResult = false
        isError = false
        return true
    }

    private func installUndoSnapshot(_ snapshot: KeyboardUndoSnapshot?) {
        undoExpirationTask?.cancel()
        undoSnapshot = snapshot
        hasUndoableEdit = snapshot != nil
        guard snapshot != nil else { return }

        undoExpirationTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(90))
            } catch {
                return
            }
            self?.discardUndo()
        }
    }

    private func discardUndo() {
        undoExpirationTask?.cancel()
        undoExpirationTask = nil
        undoSnapshot = nil
        hasUndoableEdit = false
    }

    private func showError(_ message: String) {
        isError = true
        status = message
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    private func scheduleTimeout(requestID: UUID) {
        timeoutTask?.cancel()
        timeoutTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(35))
            } catch {
                return
            }
            guard let self, self.activeRequestID == requestID else { return }
            self.generationTask?.cancel()
            self.isError = true
            self.status = "Local generation took too long. Your original text is unchanged."
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            self.finishGeneration()
        }
    }

    private func finishGeneration() {
        activeRequestID = nil
        generationTask = nil
        timeoutTask?.cancel()
        timeoutTask = nil
        isGenerating = false
        provider.releasePreparedResources()
    }
}

private enum PendingKeyboardEdit {
    case command(command: String, expectedContext: String, response: String)
    case selection(snapshot: KeyboardSelectionSnapshot, response: String)

    var successMessage: String {
        switch self {
        case .command:
            "Done. Your AI command was replaced locally. Undo is available while the result and cursor stay unchanged."
        case .selection:
            "Done. Your selection was transformed locally. Undo is available while the result and cursor stay unchanged."
        }
    }

    var recoveryMessage: String {
        switch self {
        case .command:
            "Your cursor or text changed. Return to the unchanged command, then tap Insert ready result."
        case .selection:
            "Your selection changed. Reselect the unchanged source text in the same field, then tap Insert ready result."
        }
    }
}
