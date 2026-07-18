import AppKit
import SwiftUI

@main
struct SucceedAIApp: App {
    @StateObject private var viewModel: AppViewModel

    init() {
        let provider = LocalFoundationModelProvider()
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--screenshot-selection") {
            let previewSelection = FocusedSelectionSnapshot(
                selectedText: "Thanks for waiting we fixed it and you can try again"
            ) { _ in true }
            _viewModel = StateObject(
                wrappedValue: AppViewModel(
                    aiProvider: provider,
                    selectionCapture: { previewSelection },
                    automaticallyStartMonitoring: false
                )
            )
            return
        }
#endif
        _viewModel = StateObject(wrappedValue: AppViewModel(aiProvider: provider))
    }

    var body: some Scene {
        MenuBarExtra(
            Config.appTitle,
            systemImage: viewModel.isLoading ? Config.loadingIconSymbolName : Config.appIconSymbolName
        ) {
            StatusPanelView(viewModel: viewModel)
        }
        .menuBarExtraStyle(.window)
    }
}

private struct StatusPanelView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: AppViewModel
    @AppStorage(UserSettings.commandTriggerKey) private var commandTrigger = UserSettings.defaultCommandTrigger
    @State private var quickPrompt = ""
    @State private var selectedAction: WritingAction = .custom
    @State private var targetLanguage: WritingLanguage = .french

    private var displayTrigger: String {
        UserSettings.validatedCommandTrigger(commandTrigger).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    hero
                    readinessCard
                    selectionActionCard
                    quickComposer
                    tipStrip
                    footer
                }
                .padding(16)
            }
            .onChange(of: viewModel.quickResult) { _, result in
                guard !result.isEmpty else { return }
                withAnimation(.easeOut(duration: 0.24)) {
                    proxy.scrollTo("quick-result", anchor: .center)
                }
            }
        }
        .frame(width: 440, height: 650)
        .background(panelBackground)
        .onAppear { viewModel.refreshState() }
    }

    private var hero: some View {
        HStack(spacing: 13) {
            Image("BrandMark")
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                .shadow(color: .blue.opacity(0.28), radius: 14, y: 7)
            .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 7) {
                    Text("SucceedAI")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                    Text("LOCAL")
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .foregroundStyle(.teal)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(.teal.opacity(0.12), in: Capsule())
                }
                Text("Private AI, right where you type.")
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(.secondary)
                Text("No account · No cloud · Works offline")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    @ViewBuilder
    private var readinessCard: some View {
        if viewModel.isLoading {
            PanelCard(tint: .blue) {
                StatusHeading(
                    title: "Writing locally",
                    systemImage: "hourglass.circle.fill",
                    tint: .blue,
                    badge: "WORKING"
                )
                Text("SucceedAI is completing your request on this device. Nothing is sent to a server.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Keep the original field unchanged until the response appears.")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.blue)
                }
            }
        } else if !viewModel.aiAvailability.isAvailable {
            PanelCard(tint: .orange) {
                StatusHeading(
                    title: viewModel.aiAvailability.title,
                    systemImage: "apple.intelligence",
                    tint: .orange,
                    badge: "ACTION NEEDED"
                )
                Text(viewModel.aiAvailability.detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Button {
                    viewModel.openAppleIntelligenceSettings()
                } label: {
                    Label("Open Apple Intelligence Settings", systemImage: "gear")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }
        } else if !viewModel.permissions.isComplete {
            PanelCard(tint: .orange) {
                StatusHeading(
                    title: "Finish one-time setup",
                    systemImage: "hand.raised.fill",
                    tint: .orange,
                    badge: permissionBadge
                )
                Text("Allow SucceedAI to recognize your trigger and replace it with locally generated text. Keystrokes are never stored or sent anywhere.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                PermissionRow(title: "Recognize the trigger", isGranted: viewModel.permissions.canListen)
                PermissionRow(title: "Insert the response", isGranted: viewModel.permissions.canInsert)
                Button {
                    viewModel.startGlobalKeystrokeMonitoring()
                } label: {
                    Label("Grant Permissions", systemImage: "lock.open.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }
        } else {
            PanelCard(tint: .green) {
                StatusHeading(
                    title: viewModel.isReadyEverywhere ? "Ready in every app" : "Ready to start",
                    systemImage: viewModel.isReadyEverywhere ? "checkmark.seal.fill" : "bolt.fill",
                    tint: viewModel.isReadyEverywhere ? .green : .teal,
                    badge: viewModel.isReadyEverywhere ? "LIVE" : "IDLE"
                )
                Text("Select text and open SucceedAI for one-tap outcomes—or type \(displayTrigger), add an instruction, and press Return.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    Text("\(displayTrigger) rewrite this warmly")
                        .font(.system(.caption, design: .monospaced, weight: .semibold))
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "return")
                }
                .foregroundStyle(.teal)
                .padding(9)
                .background(.teal.opacity(0.09), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
        }
    }

    @ViewBuilder
    private var selectionActionCard: some View {
        if let selectedText = viewModel.capturedSelectionText {
            PanelCard(tint: .purple) {
                StatusHeading(
                    title: "Selection ready",
                    systemImage: "selection.pin.in.out",
                    tint: .purple,
                    badge: "ONE TAP"
                )

                Text(selectedText)
                    .font(.callout)
                    .lineLimit(3)
                    .textSelection(.enabled)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.purple.opacity(0.065), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                if viewModel.isSelectionGenerating {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Transforming the unchanged selection locally…")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.purple)
                        Spacer()
                        Button("Stop") { viewModel.cancelSelectionGeneration() }
                            .controlSize(.small)
                    }
                } else if !viewModel.selectionResult.isEmpty {
                    if let message = viewModel.selectionErrorMessage {
                        Label(message, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text(viewModel.selectionResult)
                        .font(.callout)
                        .textSelection(.enabled)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.orange.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    HStack {
                        Button("Discard") { viewModel.discardSelectionResult() }
                            .controlSize(.small)
                        Spacer()
                        Button {
                            viewModel.copySelectionResult()
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                        }
                        .controlSize(.small)
                        Button {
                            retryPendingSelectionAfterDismissal()
                        } label: {
                            Label("Insert ready result", systemImage: "text.badge.checkmark")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.purple)
                        .controlSize(.small)
                    }
                } else {
                    Text("Choose an outcome. The panel closes while the local model works, then only this unchanged selection is replaced.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 7),
                            GridItem(.flexible(), spacing: 7),
                        ],
                        alignment: .leading,
                        spacing: 7
                    ) {
                        ForEach(WritingAction.quickActions) { action in
                            Button {
                                runSelectionAction(action)
                            } label: {
                                Label(action.title, systemImage: action.systemImage)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.bordered)
                            .buttonBorderShape(.roundedRectangle(radius: 8))
                            .controlSize(.small)
                            .disabled(viewModel.isLoading || !viewModel.aiAvailability.isAvailable)
                            .accessibilityHint("Transform the selected text locally")
                        }
                        selectionTranslationMenu
                    }

                    if let message = viewModel.selectionErrorMessage {
                        Label(message, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }
            .id("selection-actions")
        }
    }

    private var quickComposer: some View {
        PanelCard(tint: .blue) {
            HStack {
                Label("Quick Compose", systemImage: "wand.and.sparkles")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                Spacer()
                Text("ON-DEVICE")
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .foregroundStyle(.blue)
            }

            HStack(spacing: 7) {
                Label(selectedAction.title, systemImage: selectedAction.systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.teal)
                if selectedAction == .translate {
                    Text(targetLanguage.displayName)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.teal)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(.teal.opacity(0.1), in: Capsule())
                }
                Spacer()
            }
            Text(selectedAction.guidance(targetLanguage: targetLanguage))
                .font(.caption)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ActionChip(.custom)
                    ForEach(WritingAction.quickActions) { action in
                        ActionChip(action)
                    }
                    translationMenu
                }
            }

            TextField(
                selectedAction.promptPlaceholder(targetLanguage: targetLanguage)
                    .replacingOccurrences(of: "\n", with: " "),
                text: $quickPrompt,
                axis: .vertical
            )
                .textFieldStyle(.plain)
                .lineLimit(2...4)
                .padding(11)
                .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                .onSubmit(generate)

            Button {
                if viewModel.isQuickGenerating {
                    viewModel.cancelQuickGeneration()
                } else {
                    generate()
                }
            } label: {
                HStack {
                    if viewModel.isQuickGenerating { ProgressView().controlSize(.small) }
                    Label(
                        viewModel.isQuickGenerating ? "Stop generation" : (viewModel.isLoading ? "Busy in another app…" : "Generate"),
                        systemImage: viewModel.isQuickGenerating ? "stop.circle.fill" : "sparkles"
                    )
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(viewModel.isQuickGenerating ? .orange : .teal)
            .disabled(
                !viewModel.isQuickGenerating && (
                    quickPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    viewModel.isLoading ||
                    !viewModel.aiAvailability.isAvailable
                )
            )
            .keyboardShortcut(.return, modifiers: .command)

            if let errorMessage = viewModel.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !viewModel.quickResult.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(viewModel.quickResult)
                        .font(.callout)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    HStack {
                        Spacer()
                        Button {
                            viewModel.copyQuickResult()
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        Button {
                            quickPrompt = viewModel.quickResult
                            selectedAction = .custom
                            viewModel.clearQuickResult()
                        } label: {
                            Label("Continue", systemImage: "arrow.triangle.2.circlepath")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .padding(11)
                .background(.blue.opacity(0.07), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                .id("quick-result")
            }

        }
    }

    private var tipStrip: some View {
        HStack(spacing: 9) {
            Image(systemName: "lightbulb.max.fill")
                .foregroundStyle(.yellow)
            Text("Select text for one-tap Polish, Reply, Summary, Actions, Plan, or Translate—entirely on device.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 4)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            FooterButton("Settings", icon: "slider.horizontal.3") { viewModel.openSettingsWindow() }
            FooterButton("Shortcuts", icon: "command") { openURL("shortcuts://") }
            FooterButton("Privacy", icon: "lock.shield.fill") { openURL(Config.privacyUrl) }
            Spacer()
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
            }
            .buttonStyle(.borderless)
            .help("Quit SucceedAI")
        }
    }

    private var permissionBadge: String {
        let count = [viewModel.permissions.canListen, viewModel.permissions.canInsert].filter { $0 }.count
        return "\(count)/2"
    }

    private func generate() {
        viewModel.generateQuickResult(
            selectedAction.request(
                sourceText: quickPrompt,
                targetLanguage: targetLanguage
            )
        )
    }

    private func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }

    private func runSelectionAction(
        _ action: WritingAction,
        targetLanguage: WritingLanguage = .english
    ) {
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            _ = viewModel.transformCapturedSelection(
                with: action,
                targetLanguage: targetLanguage
            )
        }
    }

    private func retryPendingSelectionAfterDismissal() {
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            _ = viewModel.insertPendingSelectionResult()
        }
    }

    private func ActionChip(_ action: WritingAction) -> some View {
        Button {
            selectedAction = action
        } label: {
            HStack(spacing: 5) {
                Label(action.title, systemImage: action.systemImage)
                if selectedAction == action {
                    Image(systemName: "checkmark")
                        .font(.caption2.bold())
                }
            }
        }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .buttonBorderShape(.capsule)
            .tint(selectedAction == action ? .teal : .secondary)
            .accessibilityValue(selectedAction == action ? "Selected" : "Not selected")
    }

    private var translationMenu: some View {
        Menu {
            ForEach(WritingLanguage.allCases) { language in
                Button(language.displayName) {
                    targetLanguage = language
                    selectedAction = .translate
                }
            }
        } label: {
            HStack(spacing: 5) {
                Label(
                    selectedAction == .translate ? targetLanguage.displayName : "Translate",
                    systemImage: WritingAction.translate.systemImage
                )
                if selectedAction == .translate {
                    Image(systemName: "checkmark")
                        .font(.caption2.bold())
                }
            }
        }
        .menuStyle(.button)
        .controlSize(.small)
        .fixedSize()
        .tint(selectedAction == .translate ? .teal : .secondary)
        .accessibilityHint("Choose the target language")
    }

    private var selectionTranslationMenu: some View {
        Menu {
            ForEach(WritingLanguage.allCases) { language in
                Button(language.displayName) {
                    targetLanguage = language
                    runSelectionAction(.translate, targetLanguage: language)
                }
            }
        } label: {
            Label("Translate", systemImage: WritingAction.translate.systemImage)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .menuStyle(.button)
        .controlSize(.small)
        .frame(maxWidth: .infinity)
        .disabled(viewModel.isLoading || !viewModel.aiAvailability.isAvailable)
        .accessibilityHint("Choose a target language and translate the selected text locally")
    }

    private var panelBackground: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial)
            LinearGradient(
                colors: [.teal.opacity(0.08), .blue.opacity(0.045), .clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .ignoresSafeArea()
    }
}

private struct PanelCard<Content: View>: View {
    let tint: Color
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) { content }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .stroke(tint.opacity(0.18), lineWidth: 1)
            }
            .shadow(color: tint.opacity(0.08), radius: 12, y: 6)
    }
}

private struct StatusHeading: View {
    let title: String
    let systemImage: String
    let tint: Color
    let badge: String

    var body: some View {
        HStack {
            Label(title, systemImage: systemImage)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(tint)
            Spacer()
            Text(badge)
                .font(.system(size: 9, weight: .black, design: .rounded))
                .foregroundStyle(tint)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(tint.opacity(0.11), in: Capsule())
        }
    }
}

private struct PermissionRow: View {
    let title: String
    let isGranted: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isGranted ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isGranted ? .green : .secondary)
            Text(title).font(.caption)
            Spacer()
            Text(isGranted ? "Allowed" : "Required")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(isGranted ? .green : .secondary)
        }
    }
}

private struct FooterButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    init(_ title: String, icon: String, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.semibold))
        }
        .buttonStyle(.borderless)
    }
}
