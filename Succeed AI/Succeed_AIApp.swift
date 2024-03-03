import SwiftUI

@main
struct SucceedAIApp: App {
    @StateObject private var viewModel = AppViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }.commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings") {
                    viewModel.openSettingsWindow()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
        Settings {
            UserSettingsView()
        }
    }
}
