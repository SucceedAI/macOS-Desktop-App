import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel: AppViewModel
    @State private var showingPermissionsAlert = false

    init() {
        let aiProvider = MistralAiProvider() // Replace with your actual AI service provider
        _viewModel = StateObject(wrappedValue: AppViewModel(aiProvider: aiProvider))
    }

    var body: some View {
        VStack {
            Text("Succeed AI")
        }
        .onAppear {
            viewModel.requestAccessibilityPermission()
            showingPermissionsAlert = !viewModel.isAccessibilityPermissionGranted
        }
        .alert(isPresented: $showingPermissionsAlert) {
            Alert(
                title: Text("Accessibility Permission Not Granted"),
                message: Text("The app requires additional permissions. Allow the app in System Settings -> Privacy & Security -> Accessibility."),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
//    private func openSystemPreferences() {
//        // Open the System Preferences to the Accessibility pane
//        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
//            NSWorkspace.shared.open(url)
//        }
//    }
}
