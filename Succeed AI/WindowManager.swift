import SwiftUI

class WindowManager {
    static let shared = WindowManager()
    private var settingsWindow: NSWindow?

    func openSettings() {
        DispatchQueue.main.async {
            self.createSettingsWindowIfNeeded()
            self.settingsWindow?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func createSettingsWindowIfNeeded() {
        guard settingsWindow == nil else { return }

        let settingsView = UserSettingsView()
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 200),
            styleMask: [.titled, .closable],
            backing: .buffered, defer: false
        )
        window.center()
        window.contentView = NSHostingView(rootView: settingsView)

        settingsWindow = window
    }
}
