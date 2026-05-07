import SwiftUI

@main
struct SucceedAIApp: App {
    @StateObject private var viewModel: AppViewModel

    init() {
        let aiProvider = Config.apiServiceProvider.init(apiKey: Config.apiKey, apiUrl: Config.apiUrl)
        _viewModel = StateObject(wrappedValue: AppViewModel(aiProvider: aiProvider))
    }

    var body: some Scene {
        MenuBarExtra(Config.appTitle, systemImage: viewModel.isLoading ? Config.loadingIconSymbolName : Config.appIconSymbolName) {
            StatusPanelView(viewModel: viewModel)
        }
        .menuBarExtraStyle(.window)
    }
}

private struct StatusPanelView: View {
    @ObservedObject var viewModel: AppViewModel
    @AppStorage(UserSettings.commandTriggerKey) private var commandTrigger: String = UserSettings.defaultCommandTrigger

    private var isConfigured: Bool {
        let key = Config.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        return !key.isEmpty && key != "api_key"
    }

    private var displayTrigger: String {
        UserSettings.validatedCommandTrigger(commandTrigger).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            hero
            statusCard
            workflowCard
            actionGrid
        }
        .padding(18)
        .frame(width: 420)
        .background(panelBackground)
    }

    private var hero: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(LinearGradient(colors: [.teal, .mint], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .shadow(color: .teal.opacity(0.28), radius: 16, y: 8)
                Image(systemName: "sparkles")
                    .font(.system(size: 25, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 58, height: 58)

            VStack(alignment: .leading, spacing: 6) {
                Text("SucceedAI")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                Text("Instant AI in any macOS text field.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
                Text("Type \(displayTrigger), describe the task, press Return.")
                    .font(.system(.caption, design: .monospaced, weight: .semibold))
                    .foregroundStyle(.teal)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.teal.opacity(0.12), in: Capsule())
            }

            Spacer()
        }
    }

    @ViewBuilder
    private var statusCard: some View {
        if !viewModel.isAccessibilityPermissionGranted() {
            PanelCard(tint: .orange) {
                Label("Accessibility permission required", systemImage: "hand.raised.fill")
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                Text("macOS needs your approval before SucceedAI can detect and replace commands in other apps.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                PermissionStepList(appName: Config.appTitle)
                PrimaryPanelButton(title: "Grant Permission", systemImage: "lock.open.fill") {
                    _ = viewModel.checkAndRequestAccessibilityPermission()
                }
            }
        } else if !isConfigured {
            PanelCard(tint: .orange) {
                Label("API key needed", systemImage: "key.horizontal.fill")
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                Text("The app builds correctly, but AI responses require a production API key in the local Config.swift before release.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        } else {
            PanelCard(tint: viewModel.isMonitoring ? .green : .teal) {
                HStack {
                    Label(viewModel.isMonitoring ? "Service running" : "Ready to start", systemImage: viewModel.isMonitoring ? "checkmark.seal.fill" : "bolt.fill")
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                    Spacer()
                    Text(viewModel.isMonitoring ? "Live" : "Idle")
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundStyle(viewModel.isMonitoring ? .green : .teal)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background((viewModel.isMonitoring ? Color.green : Color.teal).opacity(0.12), in: Capsule())
                }
                Text(viewModel.isMonitoring ? "SucceedAI is listening for \(displayTrigger) commands across macOS." : "Start the service when you want SucceedAI available everywhere.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                PrimaryPanelButton(title: viewModel.isMonitoring ? "Keep Running" : "Start AI Service", systemImage: viewModel.isMonitoring ? "waveform.path" : "play.fill") {
                    viewModel.startGlobalKeystrokeMonitoring()
                }
                .disabled(viewModel.isMonitoring)
            }
        }
    }

    private var workflowCard: some View {
        PanelCard(tint: .blue) {
            Text("How it works")
                .font(.system(.headline, design: .rounded, weight: .semibold))
            WorkflowRow(number: "1", title: "Open any app", detail: "Mail, Notes, Slack, a browser, or any editable text field.")
            WorkflowRow(number: "2", title: "Type your command", detail: "Example: \(displayTrigger) rewrite this message with a warmer tone")
            WorkflowRow(number: "3", title: "Press Return", detail: "SucceedAI replaces the command with the generated response.")
        }
    }

    private var actionGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            SecondaryPanelButton(title: "Settings", systemImage: "slider.horizontal.3") {
                viewModel.openSettingsWindow()
            }
            SecondaryPanelButton(title: "Support", systemImage: "questionmark.bubble.fill") {
                openURL(Config.supportUrl)
            }
            SecondaryPanelButton(title: "Product News", systemImage: "play.rectangle.fill") {
                openURL(Config.socialMediaUrl)
            }
            SecondaryPanelButton(title: "Quit", systemImage: "power") {
                NSApplication.shared.terminate(nil)
            }
        }
    }

    private var panelBackground: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.95, green: 0.99, blue: 0.98), Color(red: 0.90, green: 0.96, blue: 1.0)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Circle()
                .fill(.teal.opacity(0.18))
                .frame(width: 180, height: 180)
                .blur(radius: 28)
                .offset(x: 170, y: -190)
            Circle()
                .fill(.blue.opacity(0.12))
                .frame(width: 220, height: 220)
                .blur(radius: 36)
                .offset(x: -170, y: 230)
        }
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
        .padding(.vertical, 2)
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

private struct PanelCard<Content: View>: View {
    var tint: Color
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(tint.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: tint.opacity(0.12), radius: 18, y: 10)
    }
}

private struct WorkflowRow: View {
    var number: String
    var title: String
    var detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number)
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(.blue.gradient, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.callout, design: .rounded, weight: .semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct PrimaryPanelButton: View {
    var title: String
    var systemImage: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(.callout, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(LinearGradient(colors: [.teal, .blue], startPoint: .leading, endPoint: .trailing), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct SecondaryPanelButton: View {
    var title: String
    var systemImage: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(.callout, design: .rounded, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(.white.opacity(0.8), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
