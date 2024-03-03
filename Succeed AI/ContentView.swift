import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var showingPermissionsAlert = false

    var body: some View {
        VStack {
            Text("Succeed AI")
            // Additional UI elements can be added here
        }
        .onAppear {
            viewModel.checkAndRequestAccessibilityPermission()
            showingPermissionsAlert = !viewModel.isAccessibilityPermissionGranted
        }
        .alert("Accessibility Permission Not Granted", isPresented: $showingPermissionsAlert) {
            Button("Open System Preferences", action: viewModel.openSystemPreferences)
        } message: {
            Text("The app requires additional permissions. Please grant the app permissions in System Settings -> Privacy & Security -> Accessibility.")
        }
        .onChange(of: viewModel.showSettingsWindow) { newShowSettings, _ in
            if newShowSettings {
                openSettings()
            }
        }
    }

    private func openSettings() {
        let settingsWindow = NSWindow(
            contentRect: NSRect(x: 20, y: 20, width: 480, height: 300),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false)
        settingsWindow.center()
        settingsWindow.setFrameAutosaveName("Settings")
        settingsWindow.contentView = NSHostingView(rootView: UserSettingsView())
        settingsWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
