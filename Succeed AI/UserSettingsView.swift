import SwiftUI
import ServiceManagement
import ApplicationServices

struct UserSettingsView: View {
    private enum SettingsTab: String, CaseIterable, Identifiable {
        case general = "General"
        case keys = "Keys"

        var id: String { rawValue }
    }

    @AppStorage("startAtLogin") private var startAtLogin: Bool = false
    @AppStorage(UserSettings.commandTriggerKey) private var commandTrigger: String = UserSettings.defaultCommandTrigger

    @State private var selectedTab: SettingsTab = .general
    @State private var commandTriggerDraft: String = UserSettings.defaultCommandTrigger
    @State private var loginItemErrorMessage: String?
    @State private var isSyncingLoginItemState = false
    @State private var accessibilityPermissionGranted = AXIsProcessTrusted()

    private var normalizedCommandTrigger: String {
        UserSettings.normalizedCommandTrigger(commandTriggerDraft)
    }

    private var commandTriggerError: String? {
        UserSettings.isValidCommandTrigger(commandTriggerDraft) ? nil : "Use at least two characters and no spaces, such as /ai or ;ai."
    }

    private var hasCommandTriggerChanges: Bool {
        normalizedCommandTrigger != UserSettings.validatedCommandTrigger(commandTrigger)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            tabPicker

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    switch selectedTab {
                    case .general:
                        launchCard
                        permissionCard
                        supportCard
                        versionCard
                    case .keys:
                        replacementShortcutCard
                        replacementPreviewCard
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 560, height: 540)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            syncLoginItemStatus()
            refreshAccessibilityStatus()
            commandTriggerDraft = UserSettings.validatedCommandTrigger(commandTrigger)
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(LinearGradient(colors: [.teal, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: "sparkles")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 2) {
                Text("SucceedAI Settings")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                Text("Configure launch, permissions, and replacement keys.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 22)
        .padding(.top, 20)
        .padding(.bottom, 14)
    }

    private var tabPicker: some View {
        Picker("Settings section", selection: $selectedTab) {
            ForEach(SettingsTab.allCases) { tab in
                Text(tab.rawValue).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 22)
        .padding(.bottom, 14)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(.black.opacity(0.08))
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
                    Text("Keep the menu bar assistant ready after login.")
                        .foregroundStyle(.secondary)
                    Toggle("Launch SucceedAI at login", isOn: $startAtLogin)
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

    private var permissionCard: some View {
        SettingsCard(tint: accessibilityPermissionGranted ? .green : .orange) {
            HStack(alignment: .top, spacing: 14) {
                SettingsIcon(systemName: accessibilityPermissionGranted ? "checkmark.seal.fill" : "hand.raised.fill", tint: accessibilityPermissionGranted ? .green : .orange)
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Accessibility")
                            .font(.system(.headline, design: .rounded, weight: .bold))
                        Spacer()
                        Text(accessibilityPermissionGranted ? "Enabled" : "Required")
                            .font(.caption.bold())
                            .foregroundStyle(accessibilityPermissionGranted ? .green : .orange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background((accessibilityPermissionGranted ? Color.green : Color.orange).opacity(0.12), in: Capsule())
                    }
                    Text("SucceedAI needs Accessibility permission to detect the command trigger and insert the AI response into the active app.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    PermissionStepList(appName: Config.appTitle)
                    HStack {
                        Button {
                            openAccessibilitySettings()
                        } label: {
                            Label("Open System Settings", systemImage: "gearshape.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(accessibilityPermissionGranted ? .green : .orange)

                        Button("Check Again") {
                            refreshAccessibilityStatus()
                        }
                        .buttonStyle(.bordered)
                    }
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
                    Text("Open support or product updates from the menu bar any time.")
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

    private var versionCard: some View {
        SettingsCard(tint: .gray) {
            HStack {
                SettingsIcon(systemName: "info.circle.fill", tint: .gray)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Version")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                    Text(appVersion)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
    }

    private var replacementShortcutCard: some View {
        SettingsCard(tint: .teal) {
            HStack(alignment: .top, spacing: 14) {
                SettingsIcon(systemName: "keyboard.fill", tint: .teal)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Replacement Trigger")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                    Text("Choose the text command that starts an AI replacement.")
                        .foregroundStyle(.secondary)

                    TextField("Trigger", text: $commandTriggerDraft)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .onSubmit(saveCommandTrigger)

                    if let commandTriggerError {
                        Text(commandTriggerError)
                            .font(.caption)
                            .foregroundStyle(.red)
                    } else {
                        Text("Saved trigger will be: \(normalizedCommandTrigger)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Button {
                            saveCommandTrigger()
                        } label: {
                            Label("Save Trigger", systemImage: "checkmark.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.teal)
                        .disabled(commandTriggerError != nil || !hasCommandTriggerChanges)

                        Button("Restore Default") {
                            commandTrigger = UserSettings.defaultCommandTrigger
                            commandTriggerDraft = UserSettings.defaultCommandTrigger
                        }
                        .buttonStyle(.bordered)
                    }
                }
                Spacer()
            }
        }
    }

    private var replacementPreviewCard: some View {
        SettingsCard(tint: .blue) {
            HStack(alignment: .top, spacing: 14) {
                SettingsIcon(systemName: "text.cursor", tint: .blue)
                VStack(alignment: .leading, spacing: 10) {
                    Text("Example")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                    Text("\(normalizedCommandTrigger)rewrite this note more clearly")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.blue)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    Text("Press Return after the command. SucceedAI removes the command and pastes the generated response in the same text field.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        guard let build, !build.isEmpty else { return version }
        return "\(version) (\(build))"
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

    private func saveCommandTrigger() {
        guard UserSettings.isValidCommandTrigger(commandTriggerDraft) else { return }
        commandTrigger = normalizedCommandTrigger
        commandTriggerDraft = commandTrigger
    }

    private func refreshAccessibilityStatus() {
        accessibilityPermissionGranted = AXIsProcessTrusted()
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

private struct PermissionStepList: View {
    var appName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            PermissionStep(number: "1", title: "Open Privacy & Security")
            PermissionStep(number: "2", title: "Choose Accessibility")
            PermissionStep(number: "3", title: "Enable \(appName)")
        }
    }
}

private struct PermissionStep: View {
    var number: String
    var title: String

    var body: some View {
        HStack(spacing: 8) {
            Text(number)
                .font(.system(.caption2, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(.orange.gradient, in: Circle())
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct SettingsCard<Content: View>: View {
    var tint: Color
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(tint.opacity(0.18), lineWidth: 1)
        )
    }
}

private struct SettingsIcon: View {
    var systemName: String
    var tint: Color

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 20, weight: .bold))
            .foregroundStyle(tint)
            .frame(width: 40, height: 40)
            .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
