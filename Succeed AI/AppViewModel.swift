import SwiftUI
import Combine

class AppViewModel: ObservableObject {
    private var globalKeystrokeManager: GlobalKeystrokeManager?
    private let aiProvider: AIProvideable
    @Published var aiResponse: String = ""
    @Published var isAccessibilityPermissionGranted: Bool = false

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
        aiProvider.sendQuery(query) { [weak self] response in
            DispatchQueue.main.async {
                self?.aiResponse = response
            }
        }
    }

    func requestAccessibilityPermission() {
        globalKeystrokeManager?.requestAccessibilityPermission()
    }
}
