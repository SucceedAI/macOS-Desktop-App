import SwiftUI

@main
struct SucceedAIApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            EmptyView().frame(width: 0, height: 0)
            Text("")
                .hidden()
        }.commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings") {
                    appDelegate.viewModel?.openSettingsWindow()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
        Settings {
            UserSettingsView()
        }
    }
}
