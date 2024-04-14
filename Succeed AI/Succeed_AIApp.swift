import SwiftUI
import ServiceManagement

@main
struct SucceedAIApp: App {
    // Launch at Login preference
    @AppStorage("startAtLogin") private var startAtLogin: Bool = true

    @StateObject private var viewModel: AppViewModel
    @State private var showAccessibilityAlert = false

    init() {
        let aiProvider = Config.apiServiceProvider.init(apiKey: Config.apiKey, apiUrl: Config.apiUrl)

        // Check accessibility permissions before initializing AppViewModel
        if AXIsProcessTrusted() {
            _viewModel = StateObject(wrappedValue: AppViewModel(aiProvider: aiProvider))
            showAccessibilityAlert = false
        } else {
            // Set the state variable to show the accessibility alert
            _viewModel = StateObject(wrappedValue: AppViewModel(aiProvider: aiProvider))
            showAccessibilityAlert = true
        }

        if startAtLogin {
            // Enable Login Item helper if the preference is true
            SMLoginItemSetEnabled(Config.bundleIdentifier as CFString, true)
        }
    }

    var body: some Scene {
        MenuBarExtra(Config.appTitle, systemImage: viewModel.isLoading ? Config.loadingIconSymbolName : Config.appIconSymbolName) {
            let accessEnabled = viewModel.checkAndRequestAccessibilityPermission()
            if !accessEnabled {
                Button("⚠️ Accessibility permissions need to be granted ⚠️", action: { viewModel.openSystemPreferences() })
            }

            Text("The AI service is running. Use CMD+SHIFT+Enter to interact")

            Button("Settings", action: { openSettings() }).keyboardShortcut(",")

            Button("Account: License Manager", action: { openURL(Config.renewLicenseUrl) })

            Button("Follow Product News", action: { openURL(Config.socialMediaUrl) })

            Button("Support/Feedback", action: { openURL(Config.supportUrl) })

            Button("Quit", action: { NSApplication.shared.terminate(nil) }).keyboardShortcut("q")
        }
        .menuBarExtraStyle(.menu)
        .alert(isPresented: $showAccessibilityAlert) {
            Alert(
                title: Text("Accessibility Permissions Required"),
                message: Text("Please grant accessibility permissions to use this app."),
                primaryButton: .default(Text("Open System Preferences"), action: {
                    viewModel.openSystemPreferences()
                }),
                secondaryButton: .cancel()
            )
        }
    }

    private func openSettings() {
        // TODO: Implement the settings window
        let settingsView = UserSettingsView()
        viewModel.openSettingsWindow()
    }

    private func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }
}
