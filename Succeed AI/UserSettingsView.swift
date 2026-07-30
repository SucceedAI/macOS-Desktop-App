import AppKit
import ServiceManagement
import SwiftUI

struct UserSettingsView: View {
    private enum SettingsTab: String, CaseIterable, Identifiable {
        case general = "General"
        case localAI = "Local AI"
        var id: String { rawValue }
    }

    @ObservedObject var viewModel: AppViewModel
    @AppStorage("startAtLogin") private var startAtLogin = false
    @State private var selectedTab: SettingsTab = .general
    @State private var loginItemErrorMessage: String?
    @State private var isSyncingLoginItemState = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Picker("Settings section", selection: $selectedTab) {
                ForEach(SettingsTab.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    switch selectedTab {
                    case .general:
                        launchCard
                        workflowCard
                        linksCard
                    case .localAI:
                        localAICard
                        privacyCard
                        compatibilityCard
                    }
                }
                .padding(22)
            }
        }
        .frame(width: 620, height: 620)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            syncLoginItemStatus()
            viewModel.refreshState()
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image("BrandMark")
                .resizable()
                .scaledToFit()
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                .shadow(color: .blue.opacity(0.24), radius: 10, y: 5)
            VStack(alignment: .leading, spacing: 3) {
                Text("SucceedAI Settings")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                Text("Fast, private writing help without invasive permissions")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(appVersion)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(22)
    }

    private var launchCard: some View {
        SettingsCard(tint: .green, icon: "power.circle.fill", title: "Always within reach") {
            Text("Keep SucceedAI ready in the menu bar after you sign in.")
                .foregroundStyle(.secondary)
            Toggle("Launch SucceedAI at login", isOn: $startAtLogin)
                .toggleStyle(.switch)
                .onChange(of: startAtLogin) { _, value in
                    guard !isSyncingLoginItemState else { return }
                    updateLoginItem(value)
                }
            if let loginItemErrorMessage {
                Label(loginItemErrorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private var workflowCard: some View {
        SettingsCard(tint: .purple, icon: "doc.on.clipboard.fill", title: "Copy, transform, paste") {
            Text("Copy text from any app, choose Use Copied Text in SucceedAI, generate the outcome you need, then copy the finished result. SucceedAI never monitors keystrokes or controls other apps.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                FeatureBadge(icon: "doc.on.doc", title: "Copy")
                FeatureBadge(icon: "wand.and.sparkles", title: "Transform")
                FeatureBadge(icon: "doc.on.clipboard", title: "Paste")
                FeatureBadge(icon: "command", title: "Shortcuts")
            }
        }
    }

    private var linksCard: some View {
        SettingsCard(tint: .blue, icon: "questionmark.bubble.fill", title: "Help and information") {
            HStack {
                Button("Support") { openURL(Config.supportUrl) }
                Button("Privacy") { openURL(Config.privacyUrl) }
                Button("Website") { openURL(Config.productUrl) }
            }
            .buttonStyle(.bordered)
        }
    }

    private var localAICard: some View {
        SettingsCard(
            tint: viewModel.aiAvailability.isAvailable ? .green : .orange,
            icon: "apple.intelligence",
            title: viewModel.aiAvailability.title
        ) {
            Text(viewModel.aiAvailability.detail)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 9) {
                FeatureBadge(icon: "wifi.slash", title: "Offline")
                FeatureBadge(icon: "lock.shield.fill", title: "Private")
                FeatureBadge(icon: "bolt.fill", title: "Optimized")
                FeatureBadge(icon: "dollarsign.slash", title: "No API fees")
            }
            if !viewModel.aiAvailability.isAvailable {
                Button("Open Apple Intelligence Settings") { viewModel.openAppleIntelligenceSettings() }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
            }
        }
    }

    private var privacyCard: some View {
        SettingsCard(tint: .teal, icon: "lock.shield.fill", title: "Nothing leaves this Mac") {
            Text("Prompts and generated responses are processed by the language model built into macOS. SucceedAI has no backend, analytics SDK, user account, API key, or network entitlement.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var compatibilityCard: some View {
        SettingsCard(tint: .gray, icon: "desktopcomputer", title: "Compatibility") {
            Text("Requires macOS 26 or later, an Apple silicon Mac with Apple Intelligence support, and Apple Intelligence enabled in System Settings.")
                .foregroundStyle(.secondary)
        }
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "v\(version) (\(build))"
    }

    private func updateLoginItem(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            loginItemErrorMessage = nil
            setLoginState(SMAppService.mainApp.status == .enabled)
        } catch {
            loginItemErrorMessage = "Could not update login item: \(error.localizedDescription)"
            setLoginState(SMAppService.mainApp.status == .enabled)
        }
    }

    private func syncLoginItemStatus() {
        setLoginState(SMAppService.mainApp.status == .enabled)
    }

    private func setLoginState(_ enabled: Bool) {
        isSyncingLoginItemState = true
        startAtLogin = enabled
        DispatchQueue.main.async { isSyncingLoginItemState = false }
    }

    private func openURL(_ value: String) {
        guard let url = URL(string: value) else { return }
        NSWorkspace.shared.open(url)
    }
}

private struct SettingsCard<Content: View>: View {
    let tint: Color
    let icon: String
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            Label(title, systemImage: icon)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(tint)
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 14).stroke(tint.opacity(0.16)) }
    }
}

private struct FeatureBadge: View {
    let icon: String
    let title: String

    var body: some View {
        Label(title, systemImage: icon)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.teal)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(.teal.opacity(0.09), in: Capsule())
    }
}
