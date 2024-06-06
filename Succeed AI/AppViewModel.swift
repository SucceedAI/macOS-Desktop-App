import Foundation
import SwiftUI

class AppViewModel: ObservableObject {
    @Published var aiResponse: String = ""
    @Published var showSettingsWindow = false
    @Published var isLoading: Bool = false
    
    private var globalKeystrokeManager: GlobalKeystrokeManager?
    private let aiProvider: AIProvideable

    init(aiProvider: AIProvideable) {
        self.aiProvider = aiProvider
        self.globalKeystrokeManager = GlobalKeystrokeManager(aiProvider: aiProvider)
    }

    func startGlobalKeystrokeMonitoring() {
        globalKeystrokeManager?.triggerGlobalKeystrokeMonitoring()
    }

    private func initializeGlobalKeystrokeManager() {
        globalKeystrokeManager = GlobalKeystrokeManager(aiProvider: aiProvider)
        globalKeystrokeManager?.triggerGlobalKeystrokeMonitoring()

        // Subscribe to the isLoading property of GlobalKeystrokeManager
        globalKeystrokeManager?.$isLoading
            .assign(to: &$isLoading)
    }

    public func openSystemPreferences() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    public func checkAndRequestAccessibilityPermission() -> Bool {
        let isAccessibilityPermissionGranted = globalKeystrokeManager?.checkAndRequestAccessibilityPermission() ?? false
        if !isAccessibilityPermissionGranted {
            openSystemPreferences()
        }

        return isAccessibilityPermissionGranted
    }

    public func openSettingsWindow() {
        showSettingsWindow = true
    }
}
