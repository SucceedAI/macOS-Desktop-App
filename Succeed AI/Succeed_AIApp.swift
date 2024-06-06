import SwiftUI
import ServiceManagement

@main
struct SucceedAIApp: App {
    @AppStorage("startAtLogin") private var startAtLogin: Bool = true
    @StateObject private var viewModel: AppViewModel

    init() {
        let aiProvider = Config.apiServiceProvider.init(apiKey: Config.apiKey, apiUrl: Config.apiUrl)
        _viewModel = StateObject(wrappedValue: AppViewModel(aiProvider: aiProvider))

        if startAtLogin {
            enableLoginItemIfNeeded()
        }
    }

    var body: some Scene {
        MenuBarExtra(Config.appTitle, systemImage: viewModel.isLoading ? Config.loadingIconSymbolName : Config.appIconSymbolName) {
            let accessEnabled = viewModel.checkAndRequestAccessibilityPermission()
            if !accessEnabled {
                Button("'" + Config.appTitle + "' Accessibility permissions need to be granted", action: { viewModel.openSystemPreferences() })
                Text("System Settings -> Privacy & Security -> Accessibility -> Enable " + Config.appTitle)
            } else {
                Button(action: {
                    viewModel.startGlobalKeystrokeMonitoring()
                }) {
                    Text("✨ AI service running. Type /ai <YOUR_QUERY> and press ENTER. Let the magic happening 💫")
                }
            }

            Button("Settings", action: { viewModel.openSettingsWindow() }).keyboardShortcut(",")

            Button("Account: License Manager", action: { openURL(Config.renewLicenseUrl) })

            Button("Follow Product News", action: { openURL(Config.socialMediaUrl) })

            Button("Support/Feedback", action: { openURL(Config.supportUrl) })

            Button("Quit", action: { NSApplication.shared.terminate(nil) }).keyboardShortcut("q")
        }
        .menuBarExtraStyle(.menu)
    }

    private func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }

    private func enableLoginItemIfNeeded() {
        let runningApps = NSWorkspace.shared.runningApplications
        let isRunning = runningApps.contains {
            $0.bundleIdentifier == Config.bundleIdentifier
        }

        SMLoginItemSetEnabled(Config.bundleIdentifier as CFString, true)

        if isRunning {
            return
        }
    }
}
