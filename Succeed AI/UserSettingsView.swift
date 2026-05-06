import SwiftUI
import ServiceManagement

struct UserSettingsView: View {
    @AppStorage("startAtLogin") private var startAtLogin: Bool = false
    @State private var loginItemErrorMessage: String?
    @State private var isSyncingLoginItemState = false

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    launchCard
                    commandCard
                    permissionCard
                    supportCard
                }
                .padding(22)
            }
        }
        .frame(width: 560, height: 520)
        .background(settingsBackground)
        .onAppear {
            syncLoginItemStatus()
        }
    }

    private var header: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(LinearGradient(colors: [.teal, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .shadow(color: .teal.opacity(0.30), radius: 18, y: 8)
                Image(systemName: "sparkles")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 68, height: 68)

            VStack(alignment: .leading, spacing: 5) {
                Text("SucceedAI Settings")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                Text("Tune the menu bar assistant for a fast, focused macOS workflow.")
                    .font(.system(.callout, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(24)
        .background(.white.opacity(0.55))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(.black.opacity(0.06))
                .frame(height: 1)
        }
    }

    private var launchCard: some View {
        SettingsCard(tint: .green) {
            HStack(alignment: .top, spacing: 14) {
                SettingsIcon(systemName: "power.circle.fill", tint: .green)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Launch")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                    Text("Keep SucceedAI ready from the moment your Mac starts.")
                        .foregroundStyle(.secondary)
                    Toggle("Start SucceedAI at login", isOn: $startAtLogin)
                        .toggleStyle(.switch)
                        .onChange(of: startAtLogin) { _, newValue in
                            guard !isSyncingLoginItemState else { return }
                            handleStartAtLoginChange(newValue)
                        }

                    if let loginItemErrorMessage {
                        Text(loginItemErrorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer()
            }
        }
    }

    private var commandCard: some View {
        SettingsCard(tint: .teal) {
            HStack(alignment: .top, spacing: 14) {
                SettingsIcon(systemName: "keyboard.fill", tint: .teal)
                VStack(alignment: .leading, spacing: 10) {
                    Text("Command Trigger")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                    Text("Use the trigger below in any editable macOS text field, then press Return to replace it with an AI-generated response.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 10) {
                        Text(Config.keystrokePrefixTrigger)
                            .font(.system(.title3, design: .monospaced, weight: .bold))
                            .foregroundStyle(.teal)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(.teal.opacity(0.12), in: Capsule())
                        Text("Example: /ai rewrite this note more clearly")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
        }
    }

    private var permissionCard: some View {
        SettingsCard(tint: .orange) {
            HStack(alignment: .top, spacing: 14) {
                SettingsIcon(systemName: "hand.raised.fill", tint: .orange)
                VStack(alignment: .leading, spacing: 10) {
                    Text("macOS Permission")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                    Text("Accessibility is required so SucceedAI can detect /ai commands and type the response into the active app.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button {
                        openAccessibilitySettings()
                    } label: {
                        Label("Open Accessibility Settings", systemImage: "gearshape.fill")
                            .font(.system(.callout, design: .rounded, weight: .semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                }
                Spacer()
            }
        }
    }

    private var supportCard: some View {
        SettingsCard(tint: .blue) {
            HStack(alignment: .top, spacing: 14) {
                SettingsIcon(systemName: "lifepreserver.fill", tint: .blue)
                VStack(alignment: .leading, spacing: 10) {
                    Text("Support")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                    Text("Need help, have feedback, or want product updates?")
                        .foregroundStyle(.secondary)
                    HStack {
                        Button("Open Support") { openURL(Config.supportUrl) }
                        Button("Product News") { openURL(Config.socialMediaUrl) }
                    }
                    .buttonStyle(.bordered)
                }
                Spacer()
            }
        }
    }

    private var settingsBackground: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.96, green: 0.99, blue: 0.98), Color(red: 0.91, green: 0.96, blue: 1.0)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Circle()
                .fill(.teal.opacity(0.18))
                .frame(width: 260, height: 260)
                .blur(radius: 42)
                .offset(x: 260, y: -200)
            Circle()
                .fill(.blue.opacity(0.12))
                .frame(width: 260, height: 260)
                .blur(radius: 44)
                .offset(x: -260, y: 250)
        }
    }

    private func handleStartAtLoginChange(_ newValue: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if newValue {
                    if SMAppService.mainApp.status != .enabled {
                        try SMAppService.mainApp.register()
                    }
                } else if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }

                loginItemErrorMessage = nil
                setStartAtLoginState(SMAppService.mainApp.status == .enabled)
            } catch {
                loginItemErrorMessage = "Could not update login item: \(error.localizedDescription)"
                setStartAtLoginState(SMAppService.mainApp.status == .enabled)
            }
        } else {
            let success = SMLoginItemSetEnabled(Config.bundleIdentifier as CFString, newValue)
            if !success {
                loginItemErrorMessage = "Could not update login item."
                setStartAtLoginState(!newValue)
            } else {
                loginItemErrorMessage = nil
            }
        }
    }

    private func syncLoginItemStatus() {
        if #available(macOS 13.0, *) {
            setStartAtLoginState(SMAppService.mainApp.status == .enabled)
        }
    }

    private func setStartAtLoginState(_ isEnabled: Bool) {
        isSyncingLoginItemState = true
        startAtLogin = isEnabled
        DispatchQueue.main.async {
            isSyncingLoginItemState = false
        }
    }

    private func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }

    private func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }
}

private struct SettingsCard<Content: View>: View {
    var tint: Color
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(tint.opacity(0.16), lineWidth: 1)
        )
        .shadow(color: tint.opacity(0.10), radius: 20, y: 12)
    }
}

private struct SettingsIcon: View {
    var systemName: String
    var tint: Color

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 22, weight: .bold))
            .foregroundStyle(tint)
            .frame(width: 46, height: 46)
            .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
