import AppKit
import Foundation

@MainActor
final class AppViewModel: ObservableObject {
    @Published private(set) var isLoading = false
    @Published private(set) var aiAvailability: AIAvailabilityStatus
    @Published private(set) var quickResult = ""
    @Published private(set) var errorMessage: String?
    @Published private(set) var clipboardNotice: String?
    @Published private(set) var isQuickGenerating = false
    @Published var quickPrompt: String
    @Published var quickSelectedAction: WritingAction = .custom
    @Published var quickTargetLanguage: WritingLanguage = .french
    @Published var quickTargetTone: WritingTone = .friendly

    private let aiProvider: AIProvideable
    private var activeQuickRequestID: UUID?
    private var quickGenerationTask: Task<Void, Never>?
    private var quickTimeoutTask: Task<Void, Never>?

    init(aiProvider: AIProvideable, initialDraft: String = "") {
        self.aiProvider = aiProvider
        self.aiAvailability = aiProvider.availability
        self.quickPrompt = initialDraft
        aiProvider.prepare()
    }

    func refreshState() {
        aiAvailability = aiProvider.availability
        if aiAvailability.isAvailable {
            aiProvider.prepare()
        }
    }

    func importClipboardText() {
        clipboardNotice = nil
        errorMessage = nil
        switch ClipboardTextImporter.read() {
        case .success(let text):
            quickPrompt = text
            quickResult = ""
            clipboardNotice = "Copied text is ready. Choose an outcome and generate."
        case .empty:
            errorMessage = "Copy some text first, then choose Use Copied Text."
        case .tooLong:
            errorMessage = "The copied text is too long. Use 20,000 characters or fewer."
        }
    }

    func generateQuickResult() {
        generateQuickResult(
            quickSelectedAction.request(
                sourceText: quickPrompt,
                targetLanguage: quickTargetLanguage,
                targetTone: quickTargetTone
            )
        )
    }

    func generateQuickResult(_ request: String) {
        guard !isLoading else { return }
        guard !request.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Add text or a writing request first."
            return
        }

        errorMessage = nil
        clipboardNotice = nil
        quickResult = ""
        isQuickGenerating = true
        isLoading = true

        let requestID = UUID()
        activeQuickRequestID = requestID
        quickGenerationTask = aiProvider.query(request) { [weak self] result in
            Task { @MainActor in
                guard let self, self.activeQuickRequestID == requestID else { return }
                switch result {
                case .success(let response):
                    self.quickResult = response
                case .failure(let error):
                    if error != .cancelled {
                        self.errorMessage = error.userMessage
                    }
                }
                self.aiAvailability = self.aiProvider.availability
                self.finishQuickGeneration()
            }
        }
        scheduleQuickGenerationTimeout(requestID: requestID)
    }

    func cancelQuickGeneration() {
        guard isQuickGenerating else { return }
        quickGenerationTask?.cancel()
        errorMessage = nil
        finishQuickGeneration()
    }

    func clearQuickResult() {
        quickResult = ""
        errorMessage = nil
        clipboardNotice = nil
    }

    func editQuickResult() {
        guard !quickResult.isEmpty else { return }
        quickPrompt = quickResult
        quickSelectedAction = .custom
        clearQuickResult()
    }

    func refineQuickResult(
        with action: WritingAction,
        targetLanguage: WritingLanguage? = nil,
        targetTone: WritingTone? = nil
    ) {
        guard !quickResult.isEmpty, action != .custom else { return }
        quickPrompt = quickResult
        quickSelectedAction = action
        if let targetLanguage { quickTargetLanguage = targetLanguage }
        if let targetTone { quickTargetTone = targetTone }
        clearQuickResult()
        generateQuickResult()
    }

    func copyQuickResult() {
        guard !quickResult.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(quickResult, forType: .string)
        clipboardNotice = "Result copied. Paste it wherever you need it."
    }

    func openSettingsWindow() {
        WindowManager.shared.openSettings(viewModel: self)
    }

    func openAppleIntelligenceSettings() {
        openSystemSettings("x-apple.systempreferences:com.apple.Siri-Settings.extension")
    }

    private func openSystemSettings(_ path: String) {
        guard let url = URL(string: path) else { return }
        NSWorkspace.shared.open(url)
    }

    private func scheduleQuickGenerationTimeout(requestID: UUID) {
        quickTimeoutTask?.cancel()
        quickTimeoutTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(35))
            } catch {
                return
            }
            guard let self, self.activeQuickRequestID == requestID else { return }
            self.quickGenerationTask?.cancel()
            self.errorMessage = "Local generation took too long. Your draft is unchanged. Try a shorter request."
            self.finishQuickGeneration()
        }
    }

    private func finishQuickGeneration() {
        activeQuickRequestID = nil
        quickGenerationTask = nil
        quickTimeoutTask?.cancel()
        quickTimeoutTask = nil
        isQuickGenerating = false
        isLoading = false
    }
}
