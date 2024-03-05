import SwiftUI

struct UserSettingsView: View {
    @AppStorage("fontSizePreference") private var fontSizePreference: Double = 14.0

    var body: some View {
        Form {
            Section(header: Text("Appearance")) {
                Slider(value: $fontSizePreference, in: 10...24, step: 1) {
                    Text("Font Size")
                }
                Text("Font size: \(Int(fontSizePreference))")
            }

            // Add more settings here as needed
        }
        .padding()
        .frame(width: 400, height: 400)
        .navigationTitle("Settings")
    }
}
