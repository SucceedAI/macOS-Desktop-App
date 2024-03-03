import SwiftUI

@main
struct SucceedAIApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView(aiService: MistralAIProvider())
        }
    }
}
