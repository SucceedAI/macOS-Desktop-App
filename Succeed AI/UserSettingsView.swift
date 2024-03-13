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
                        DispatchQueue.main.async {
                            handleStartAtLoginChange(newShowSetting)
                        }
                    }
            }
            Section(header: Text("Appearance")) {
                Slider(value: $fontSizePreference, in: 10...24, step: 1) {
                    Text("Font Size")
                }
                Text("Font size: \(Int(fontSizePreference))")
            }
        }
        .padding()
        .frame(width: 300, height: 200)
        .navigationTitle("Settings")
    }

    private func handleStartAtLoginChange(_ newValue: Bool) {
        // Logic for handling "Start at Login" goes here
        print("Start at login set to: \(newValue)")
        let success = SMLoginItemSetEnabled(Config.bundleIdentifier as CFString, true)

        if !success {
            // Handle the error here
            print("Failed to \(newValue ? "enable" : "disable") start at login")
        }
    }
}
