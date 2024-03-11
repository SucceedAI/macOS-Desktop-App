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
        setupGlobalKeystrokeManager()
    }

    private func setupGlobalKeystrokeManager() {
        globalKeystrokeManager = GlobalKeystrokeManager(aiProvider: aiProvider) { [weak self] query in
            self?.sendQueryToAI(query)
        }

        isAccessibilityPermissionGranted = globalKeystrokeManager?.checkAccessibilityPermission() ?? false
    }

    func sendQueryToAI(_ query: String) {
        let formattedQuery = getAiInstructions(query)
        aiProvider.query(formattedQuery) { [weak self] response in
            DispatchQueue.main.async {
                self?.aiResponse = response
            }
        }
    }
    
    func initializeGlobalKeystrokeManager() {
        globalKeystrokeManager = GlobalKeystrokeManager(aiProvider: aiProvider) { [weak self] query in
            self?.sendQueryToAI(query)
        }
        globalKeystrokeManager?.setupGlobalKeystrokeMonitoring()
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

    private func getAiInstructions(_ query: String) -> String {
        let instructionQuery = """
Follow the instruction from the text in triple quotes below:
\"\"\"\(query)\"\"\"

Do not return anything else other than the given instruction. Do not wrap responses in quotes.
"""

        return instructionQuery
    }
}
