import SwiftUI

@main
struct SucceedAIApp: App {

    //** Replace with your actual AI service provider **//
    //@StateObject private var viewModel = AppViewModel(aiProvider: ServerApiProvider())
    @StateObject private var viewModel = AppViewModel(aiProvider: Config.apiServiceProvider.init(apiKey: Config.mistralApiKey))

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
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
