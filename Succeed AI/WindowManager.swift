import SwiftUI

class WindowManager {
    static let shared = WindowManager()
    private var settingsWindow: NSWindow?

    func openSettings() {
        DispatchQueue.main.async {
            if self.settingsWindow == nil {
                let settingsView = UserSettingsView()
                self.settingsWindow = NSWindow(
                    contentRect: NSRect(x: 0, y: 0, width: 300, height: 200),
                    styleMask: [.titled, .closable],
                    backing: .buffered, defer: false
                )
                self.settingsWindow?.center()
                self.settingsWindow?.contentView = NSHostingView(rootView: settingsView)
            }
            self.settingsWindow?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
