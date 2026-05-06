import Foundation
import SwiftUI
import Combine

class AppViewModel: ObservableObject {
    @Published var aiResponse: String = ""
    @Published var isLoading: Bool = false
    @Published private(set) var isMonitoring: Bool = false
    
    private var globalKeystrokeManager: GlobalKeystrokeManager?
    private let aiProvider: AIProvideable
    private var cancellables = Set<AnyCancellable>()

    init(aiProvider: AIProvideable) {
        self.aiProvider = aiProvider
        self.globalKeystrokeManager = GlobalKeystrokeManager(aiProvider: aiProvider)
        bindGlobalKeystrokeManager()
        startGlobalKeystrokeMonitoringIfAllowed()
    }

    func startGlobalKeystrokeMonitoring() {
        guard let globalKeystrokeManager else { return }
        let didStart = globalKeystrokeManager.triggerGlobalKeystrokeMonitoring()
        isMonitoring = didStart
    }

    func startGlobalKeystrokeMonitoringIfAllowed() {
        guard isAccessibilityPermissionGranted() else { return }
        startGlobalKeystrokeMonitoring()
    }

    public func openSystemPreferences() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    public func checkAndRequestAccessibilityPermission() -> Bool {
        let isAccessibilityPermissionGranted = globalKeystrokeManager?.checkAndRequestAccessibilityPermission(prompt: true) ?? false
        if !isAccessibilityPermissionGranted {
            openSystemPreferences()
        }

        return isAccessibilityPermissionGranted
    }

    public func isAccessibilityPermissionGranted() -> Bool {
        globalKeystrokeManager?.isAccessibilityPermissionGranted() ?? false
    }

    public func openSettingsWindow() {
        WindowManager.shared.openSettings()
    }

    private func bindGlobalKeystrokeManager() {
        globalKeystrokeManager?.$isLoading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLoading in
                self?.isLoading = isLoading
            }
            .store(in: &cancellables)
    }
}
