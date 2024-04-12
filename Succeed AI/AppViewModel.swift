import Foundation
import SwiftUI

class AppViewModel: ObservableObject {
    @Published var aiResponse: String = ""
    @Published var showSettingsWindow = false
    
    private var globalKeystrokeManager: GlobalKeystrokeManager?
    private let aiProvider: AIProvideable

    init(aiProvider: AIProvideable) {
        self.aiProvider = aiProvider
        initializeGlobalKeystrokeManager()
    }

    private func initializeGlobalKeystrokeManager() {
        globalKeystrokeManager = GlobalKeystrokeManager(aiProvider: aiProvider)
        globalKeystrokeManager?.triggerGlobalKeystrokeMonitoring()
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
