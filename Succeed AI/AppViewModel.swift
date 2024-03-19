import Foundation
import SwiftUI

class AppViewModel: ObservableObject {
    @Published var aiResponse: String = ""
    @Published var isAccessibilityPermissionGranted: Bool = false
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
        
        isAccessibilityPermissionGranted = globalKeystrokeManager?.checkAccessibilityPermission() ?? false
    }

    func checkAndRequestAccessibilityPermission() {
        isAccessibilityPermissionGranted = globalKeystrokeManager?.checkAccessibilityPermission() ?? false

        if !isAccessibilityPermissionGranted {
            globalKeystrokeManager?.requestAccessibilityPermission()
        }
    }

    func openSystemPreferences() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    func openSettingsWindow() {
        showSettingsWindow = true
    }
}
