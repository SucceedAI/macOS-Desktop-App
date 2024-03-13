import SwiftUI
import SwiftUIX

class WindowManager {
    static let shared = WindowManager()
    private var settingsWindow: NSWindow?

    func openSettings() {
        DispatchQueue.main.async {
            self.createAndShowSettingsWindow()
        }
    }

    private func createAndShowSettingsWindow() {
        if self.settingsWindow == nil {
            let settingsView = UserSettingsView()  // Your SwiftUI settings view
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 200, height: 200),
                styleMask: [.titled, .closable],
                backing: .buffered, defer: false
            )
            window.center()
            window.setFrameAutosaveName("Settings")
            window.contentView = NSHostingView(rootView: settingsView)

            self.settingsWindow = window
        }
        self.settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
