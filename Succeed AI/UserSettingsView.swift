import SwiftUI
import ServiceManagement

struct UserSettingsView: View {
    @AppStorage("fontSizePreference") private var fontSizePreference: Double = 14.0
    @AppStorage("startAtLogin") private var startAtLogin: Bool = false

    var body: some View {
        Form {
            Section(header: Text("General")) {
                Toggle("Start at Login", isOn: $startAtLogin)
                    .onChange(of: startAtLogin) { newShowSetting, _ in
                        // Code to enable/disable helper app
                        SMLoginItemSetEnabled(Config.bundleIdentifier as CFString, newShowSetting)
                    }
            }
        }
        Form {
            Section(header: Text("Appearance")) {
                Slider(value: $fontSizePreference, in: 10...24, step: 1) {
                    Text("Font Size")
                }
                Text("Font size: \(Int(fontSizePreference))")
            }
        }
        .padding()
        .frame(width: 200, height: 200)
        .navigationTitle("Settings")
    }
}
