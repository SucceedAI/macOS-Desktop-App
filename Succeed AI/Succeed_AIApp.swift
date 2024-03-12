import SwiftUI
import SwiftUIX
import ServiceManagement

var globalSettingsWindow: NSWindow?


@main
struct SucceedAIApp: App {
    @State private var isSettingsWindowOpen = false
    @AppStorage("startAtLogin") private var startAtLogin: Bool = false
    @StateObject private var viewModel: AppViewModel

    init() {
        let aiProvider = Config.apiServiceProvider.init(apiKey: Config.apiKey, apiUrl: Config.apiUrl)
        _viewModel = StateObject(wrappedValue: AppViewModel(aiProvider: aiProvider))
        
        viewModel.initializeGlobalKeystrokeManager()
        
        if startAtLogin {
            // Enable the helper app if the preference is true
            SMLoginItemSetEnabled(Config.bundleIdentifier as CFString, true)
        }
    }

    var body: some Scene {
        MenuBarExtra(Config.appTitle, systemImage: Config.systemSymbolName) {
            Text("The AI service is running. Use CMD+SHIFT+Enter to interact 🚀")
            
            Button("Settings", action: { WindowManager.shared.openSettings() }).keyboardShortcut(",")
            Button("Quit", action: { NSApplication.shared.terminate(nil) }).keyboardShortcut("q")
        
        }.menuBarExtraStyle(.menu)
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
}
