import SwiftUI
import SwiftUIX

class WindowManager {
    static let shared = WindowManager()
    private var settingsWindow: NSWindow?

    func openSettings() {
        if settingsWindow == nil {
            let settingsView = UserSettingsView()  // Your SwiftUI settings view
            settingsWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 200, height: 200),
                styleMask: [.titled, .closable],
                backing: .buffered, defer: false
            )
            settingsWindow?.center()
            settingsWindow?.setFrameAutosaveName("Settings")
            settingsWindow?.contentView = NSHostingView(rootView: settingsView)
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
