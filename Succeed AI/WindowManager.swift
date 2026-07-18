import SwiftUI

class WindowManager {
    static let shared = WindowManager()
    private var settingsWindow: NSWindow?

    func openSettings(viewModel: AppViewModel) {
        DispatchQueue.main.async {
            self.createSettingsWindowIfNeeded(viewModel: viewModel)
            self.settingsWindow?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func createSettingsWindowIfNeeded(viewModel: AppViewModel) {
        guard settingsWindow == nil else { return }

        let settingsView = UserSettingsView(viewModel: viewModel)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 620),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered, defer: false
        )
        window.title = "SucceedAI Settings"
        window.center()
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName("SettingsWindow")
        window.contentView = NSHostingView(rootView: settingsView)

        settingsWindow = window
    }
}
