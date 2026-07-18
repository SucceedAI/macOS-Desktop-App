import SwiftUI
import UIKit

@MainActor
final class iOSComposerViewModel: ObservableObject {
    @Published var prompt = ""
    @Published var selectedAction: WritingAction = .custom
    @Published var targetLanguage: WritingLanguage = .french
    @Published private(set) var result = ""
    @Published private(set) var resultActionTitle = ""
    @Published private(set) var isGenerating = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var availability: AIAvailabilityStatus

    private let provider: AIProvideable
    private var activeRequestID: UUID?
    private var generationTask: Task<Void, Never>?
    private var timeoutTask: Task<Void, Never>?

    init(provider: AIProvideable = LocalFoundationModelProvider()) {
        self.provider = provider
        self.availability = provider.availability
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--screenshot-compose") ||
            ProcessInfo.processInfo.arguments.contains("--screenshot-actions") {
            self.selectedAction = .polish
            self.prompt = "Thanks for waiting—we fixed it and you can try again."
            self.result = "Thanks for your patience—we’ve fixed the issue, and you can try again now."
            self.resultActionTitle = WritingAction.polish.title
        }
        #endif
        provider.prepare()
    }

    func refresh() {
        availability = provider.availability
        if availability.isAvailable { provider.prepare() }
    }

    func generate() {
        guard !isGenerating else { return }
        let request = selectedAction.request(
            sourceText: prompt,
            targetLanguage: targetLanguage
        )
        guard !request.isEmpty else {
            errorMessage = "Add text or a writing request first."
            return
        }
        isGenerating = true
        result = ""
        resultActionTitle = ""
        errorMessage = nil
        let requestID = UUID()
        let completedActionTitle = selectedAction == .translate
            ? "Translated to \(targetLanguage.displayName)"
            : selectedAction.title
        activeRequestID = requestID
        generationTask = provider.query(request) { [weak self] response in
            Task { @MainActor in
                guard let self, self.activeRequestID == requestID else { return }
                switch response {
                case .success(let value):
                    self.result = value
                    self.resultActionTitle = completedActionTitle
                case .failure(let error):
                    if error != .cancelled { self.errorMessage = error.userMessage }
                }
                self.availability = self.provider.availability
                self.finishGeneration()
            }
        }
        scheduleTimeout(requestID: requestID)
    }

    func cancelGeneration() {
        guard isGenerating else { return }
        generationTask?.cancel()
        errorMessage = nil
        finishGeneration()
    }

    func copyResult() {
        UIPasteboard.general.string = result
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    func selectAction(_ action: WritingAction) {
        selectedAction = action
        errorMessage = nil
        UISelectionFeedbackGenerator().selectionChanged()
    }

    func selectTranslation(_ language: WritingLanguage) {
        targetLanguage = language
        selectedAction = .translate
        errorMessage = nil
        UISelectionFeedbackGenerator().selectionChanged()
    }

    func refineResult() {
        guard !result.isEmpty else { return }
        prompt = result
        selectedAction = .custom
        result = ""
        resultActionTitle = ""
        errorMessage = nil
        UISelectionFeedbackGenerator().selectionChanged()
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
            self.errorMessage = "Local generation took too long. Your draft is unchanged—try a shorter request."
            self.finishGeneration()
        }
    }

    private func finishGeneration() {
        activeRequestID = nil
        generationTask = nil
        timeoutTask?.cancel()
        timeoutTask = nil
        isGenerating = false
    }
}
