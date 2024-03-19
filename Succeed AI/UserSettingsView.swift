import SwiftUI
import ServiceManagement

struct UserSettingsView: View {
    @AppStorage("fontSizePreference") private var fontSizePreference: Double = 14.0
    @AppStorage("startAtLogin") private var startAtLogin: Bool = false

    var body: some View {
        Form {
            Section(header: Text("General")) {
                Toggle("Start at Login", isOn: $startAtLogin)
                    .onChange(of: startAtLogin) { newValue, _ in
                        DispatchQueue.main.async {
                            handleStartAtLoginChange(newValue)
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
        .onAppear {
            startAtLogin = isAppSetToStartAtLogin()
        }
    }

    private func handleStartAtLoginChange(_ newValue: Bool) {
        let success = SMLoginItemSetEnabled(Config.bundleIdentifier as CFString, newValue)
        if !success {
            print("Failed to \(newValue ? "enable" : "disable") start at login")
        }
    }

    private func isAppSetToStartAtLogin() -> Bool {
        return UserDefaults.standard.bool(forKey: "startAtLogin")
    }
}
