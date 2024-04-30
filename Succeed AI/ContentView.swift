import SwiftUI

struct ContentView: View {
    @State private var showSettings = false

    var body: some View {
        VStack {
            Text("Main Content")
                .padding()

            Button("Open Settings") {
                showSettings.toggle()
            }
            .padding()
        }
        .sheet(isPresented: $showSettings) {
            UserSettingsView()
        }
        .padding()
    }
}
