import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel: AppViewModel
    @State private var showingPermissionsAlert = false

    init() {
        //let aiProvier = ServerApiProvider()
        let aiProvider = MistralAiProvider() // Replace with your actual AI service provider
        _viewModel = StateObject(wrappedValue: AppViewModel(aiProvider: aiProvider))
    }

    var body: some View {
        VStack {
            Text("Succeed AI")
        }
        .onAppear {
            viewModel.checkAndRequestAccessibilityPermission()
        }
        .alert("Accessibility Permission Not Granted", isPresented: $showingPermissionsAlert) {
            Button("Open System Preferences", action: viewModel.openSystemPreferences)
        } message: {
            Text("The app requires additional permissions. Please grant the app permissions in System Settings -> Privacy & Security -> Accessibility.")
        }
        .onChange(of: viewModel.showSettingsWindow) { show in
            if show {
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
