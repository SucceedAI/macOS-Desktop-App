import AppKit
import Combine
import Foundation

@MainActor
final class AppViewModel: ObservableObject {
    @Published private(set) var isLoading = false
    @Published private(set) var isMonitoring = false
    @Published private(set) var aiAvailability: AIAvailabilityStatus
    @Published private(set) var permissions: AutomationPermissionState
    @Published private(set) var quickResult = ""
    @Published private(set) var errorMessage: String?
    @Published private(set) var isQuickGenerating = false
    @Published private(set) var capturedSelectionText: String?
    @Published private(set) var selectionResult = ""
    @Published private(set) var selectionErrorMessage: String?
    @Published private(set) var isSelectionGenerating = false

    private let aiProvider: AIProvideable
    private let globalKeystrokeManager: GlobalKeystrokeManager
    private let selectionCapture: (() -> FocusedSelectionSnapshot?)?
    private var isGlobalGenerating = false
    private var activeQuickRequestID: UUID?
    private var quickGenerationTask: Task<Void, Never>?
    private var quickTimeoutTask: Task<Void, Never>?
    private var capturedSelection: FocusedSelectionSnapshot?
    private var activeSelectionRequestID: UUID?
    private var selectionGenerationTask: Task<Void, Never>?
    private var selectionTimeoutTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    init(
        aiProvider: AIProvideable,
        selectionCapture: (() -> FocusedSelectionSnapshot?)? = nil,
        automaticallyStartMonitoring: Bool = true
    ) {
        self.aiProvider = aiProvider
        self.globalKeystrokeManager = GlobalKeystrokeManager(aiProvider: aiProvider)
        self.selectionCapture = selectionCapture
        self.aiAvailability = aiProvider.availability
        self.permissions = globalKeystrokeManager.permissionState
        bindGlobalKeystrokeManager()
        aiProvider.prepare()
        if automaticallyStartMonitoring {
            startGlobalKeystrokeMonitoringIfAllowed()
        }
    }

    var isReadyEverywhere: Bool {
        aiAvailability.isAvailable && permissions.isComplete && isMonitoring
    }

    func refreshState() {
        aiAvailability = aiProvider.availability
        permissions = globalKeystrokeManager.permissionState
        isMonitoring = globalKeystrokeManager.isMonitoring
        if aiAvailability.isAvailable {
            aiProvider.prepare()
        }
        startGlobalKeystrokeMonitoringIfAllowed()
        captureFocusedSelection()
    }

    func startGlobalKeystrokeMonitoring() {
        permissions = globalKeystrokeManager.requestPermissions()
        guard permissions.isComplete else { return }
        isMonitoring = globalKeystrokeManager.startMonitoring()
        if !isMonitoring {
            errorMessage = "SucceedAI could not start listening. Reopen the app after granting both permissions."
        }
    }

    func startGlobalKeystrokeMonitoringIfAllowed() {
        guard permissions.isComplete else { return }
        isMonitoring = globalKeystrokeManager.startMonitoring()
    }

    func generateQuickResult(_ request: String) {
        guard !isLoading else { return }
        errorMessage = nil
        quickResult = ""
        isQuickGenerating = true
        updateLoading()

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

    func captureFocusedSelection() {
        guard !isSelectionGenerating, selectionResult.isEmpty else { return }
        let snapshot: FocusedSelectionSnapshot?
        if let selectionCapture {
            snapshot = selectionCapture()
        } else {
            snapshot = globalKeystrokeManager.captureFocusedSelection()
        }
        capturedSelection = snapshot
        capturedSelectionText = snapshot?.selectedText
        selectionErrorMessage = nil
    }

    @discardableResult
    func transformCapturedSelection(
        with action: WritingAction,
        targetLanguage: WritingLanguage = .english
    ) -> Bool {
        guard !isLoading,
              action != .custom,
              let snapshot = capturedSelection else { return false }

        aiAvailability = aiProvider.availability
        guard aiAvailability.isAvailable else {
            selectionErrorMessage = aiAvailability.detail
            return false
        }

        selectionResult = ""
        selectionErrorMessage = nil
        isSelectionGenerating = true
        updateLoading()
        let requestID = UUID()
        activeSelectionRequestID = requestID
        selectionGenerationTask = aiProvider.query(
            action.request(sourceText: snapshot.selectedText, targetLanguage: targetLanguage)
        ) { [weak self] result in
            Task { @MainActor in
                guard let self, self.activeSelectionRequestID == requestID else { return }
                switch result {
                case .success(let response):
                    if snapshot.replaceSelection(with: response) {
                        self.capturedSelection = nil
                        self.capturedSelectionText = nil
                        self.selectionResult = ""
                        self.selectionErrorMessage = nil
                    } else {
                        self.selectionResult = response
                        self.selectionErrorMessage = "The app, field, selection, or document changed. Nothing was overwritten. Reselect the original text to insert the ready result, or copy it."
                        NSSound.beep()
                    }
                case .failure(let error):
                    if error != .cancelled {
                        self.selectionErrorMessage = error.userMessage
                        NSSound.beep()
                    }
                }
                self.aiAvailability = self.aiProvider.availability
                self.finishSelectionGeneration()
            }
        }
        scheduleSelectionTimeout(requestID: requestID)
        return true
    }

    func cancelSelectionGeneration() {
        guard isSelectionGenerating else { return }
        selectionGenerationTask?.cancel()
        selectionErrorMessage = "Canceled — the original selection is unchanged."
        finishSelectionGeneration()
    }

    @discardableResult
    func insertPendingSelectionResult() -> Bool {
        guard !selectionResult.isEmpty,
              let capturedSelection,
              capturedSelection.replaceSelection(with: selectionResult) else {
            selectionErrorMessage = "The original selection is not active and unchanged. Reselect it in the same field, or copy the ready result."
            NSSound.beep()
            return false
        }

        self.capturedSelection = nil
        capturedSelectionText = nil
        selectionResult = ""
        selectionErrorMessage = nil
        return true
    }

    func copySelectionResult() {
        guard !selectionResult.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(selectionResult, forType: .string)
    }

    func discardSelectionResult() {
        guard !isSelectionGenerating else { return }
        capturedSelection = nil
        capturedSelectionText = nil
        selectionResult = ""
        selectionErrorMessage = nil
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
    }

    func copyQuickResult() {
        guard !quickResult.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(quickResult, forType: .string)
    }

    func openSettingsWindow() {
        WindowManager.shared.openSettings(viewModel: self)
    }

    func openInputMonitoringSettings() {
        openSystemSettings("x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")
    }

    func openAccessibilitySettings() {
        openSystemSettings("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    func openAppleIntelligenceSettings() {
        openSystemSettings("x-apple.systempreferences:com.apple.Siri-Settings.extension")
    }

    private func openSystemSettings(_ path: String) {
        guard let url = URL(string: path) else { return }
        NSWorkspace.shared.open(url)
    }

    private func bindGlobalKeystrokeManager() {
        globalKeystrokeManager.$isLoading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in
                self?.isGlobalGenerating = value
                self?.updateLoading()
            }
            .store(in: &cancellables)

        globalKeystrokeManager.$errorMessage
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.errorMessage = $0 }
            .store(in: &cancellables)
    }

    private func updateLoading() {
        isLoading = isQuickGenerating || isGlobalGenerating || isSelectionGenerating
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
            self.errorMessage = "Local generation took too long. Your draft is unchanged—try a shorter request."
            self.finishQuickGeneration()
        }
    }

    private func finishQuickGeneration() {
        activeQuickRequestID = nil
        quickGenerationTask = nil
        quickTimeoutTask?.cancel()
        quickTimeoutTask = nil
        isQuickGenerating = false
        updateLoading()
    }

    private func scheduleSelectionTimeout(requestID: UUID) {
        selectionTimeoutTask?.cancel()
        selectionTimeoutTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(35))
            } catch {
                return
            }
            guard let self, self.activeSelectionRequestID == requestID else { return }
            self.selectionGenerationTask?.cancel()
            self.selectionErrorMessage = "Local generation took too long. The original selection is unchanged."
            NSSound.beep()
            self.finishSelectionGeneration()
        }
    }

    private func finishSelectionGeneration() {
        activeSelectionRequestID = nil
        selectionGenerationTask = nil
        selectionTimeoutTask?.cancel()
        selectionTimeoutTask = nil
        isSelectionGenerating = false
        updateLoading()
    }
}
