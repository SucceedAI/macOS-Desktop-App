import SwiftUI
import SwiftUIX
import ServiceManagement

var globalSettingsWindow: NSWindow?

@main
struct SucceedAIApp: App {
    @AppStorage("startAtLogin") private var startAtLogin: Bool = false
    @StateObject private var viewModel: AppViewModel = {
        let aiProvider = Config.apiServiceProvider.init(apiKey: Config.apiKey, apiUrl: Config.apiUrl)
        return AppViewModel(aiProvider: aiProvider)
    }()

    init() {
        if startAtLogin {
            // Enable the helper app if the preference is true
            SMLoginItemSetEnabled(Config.bundleIdentifier as CFString, true)
        }
    }

    var body: some Scene {
        MenuBarExtra(Config.appTitle, systemImage: Config.systemSymbolName) {
            Text("The AI service is running. Use CMD+SHIFT+Enter to interact")
            Text("⚠️ Make sure the Accessibility permissions is granted ⚠️")

            Button("Settings", action: { openSettings() }).keyboardShortcut(",")
            Button("Renew License", action: { openURL(Config.renewLicenseUrl) })
            Button("Social", action: { openURL(Config.socialMediaUrl) })
            Button("Quit", action: { NSApplication.shared.terminate(nil) }).keyboardShortcut("q")
        }
        .menuBarExtraStyle(.menu)
    }

    private func openSettings() {
        if globalSettingsWindow == nil {
            let settingsView = UserSettingsView()
            globalSettingsWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 400),
                styleMask: [.titled, .closable],
                backing: .buffered, defer: false
            )
            globalSettingsWindow?.center()
            globalSettingsWindow?.title = "Settings"
            globalSettingsWindow?.contentView = NSHostingView(rootView: settingsView)
        }

        globalSettingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }
}
