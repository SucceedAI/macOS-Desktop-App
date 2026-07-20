import SwiftUI
import UIKit

struct SucceedAIHomeView: View {
    @StateObject private var viewModel = iOSComposerViewModel()
    @State private var selectedTab: Int
    @FocusState private var isComposerFocused: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        let tab = arguments.contains("--screenshot-keyboard") ? 1 : arguments.contains("--screenshot-privacy") ? 2 : 0
        _selectedTab = State(initialValue: tab)
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack { composer }
                .tabItem { Label("Compose", systemImage: "sparkles") }
                .tag(0)
            NavigationStack { keyboardSetup }
                .tabItem { Label("Keyboard", systemImage: "keyboard") }
                .tag(1)
            NavigationStack { privacy }
                .tabItem { Label("Privacy", systemImage: "lock.shield") }
                .tag(2)
        }
        .tint(.teal)
        .onAppear {
#if DEBUG
            let arguments = ProcessInfo.processInfo.arguments
            if let triggerFlag = arguments.firstIndex(of: "--ui-test-keyboard-trigger"),
               arguments.indices.contains(triggerFlag + 1) {
                _ = KeyboardTriggerSettings.save(arguments[triggerFlag + 1])
            }
            if arguments.contains("--screenshot-keyboard-command") {
                viewModel.prompt = "/ai rewrite this launch update so it sounds clear and confident"
            }
#endif
            viewModel.refresh()
#if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--screenshot-keyboard-surface") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    isComposerFocused = true
                }
            }
#endif
        }
    }

    private var composer: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    hero
                    modelStatus
                    composerCard
                    shortcutsCard
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaPadding(.bottom, 64)
            .background(pageBackground)
            .onChange(of: viewModel.result) { _, result in
                guard !result.isEmpty else { return }
                withAnimation(.easeOut(duration: 0.28)) {
                    proxy.scrollTo("composer-result", anchor: .top)
                }
            }
#if DEBUG
            .onAppear {
                guard ProcessInfo.processInfo.arguments.contains("--screenshot-actions") else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    proxy.scrollTo("composer-card", anchor: .top)
                }
            }
#endif
        }
        .navigationTitle("Succeed AI")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    isComposerFocused = false
                }
                .accessibilityIdentifier("composer-keyboard-done")
            }
        }
    }

    private var hero: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 14) {
                    heroBrandMark
                    heroCopy
                }
            } else {
                HStack(alignment: .top, spacing: 15) {
                    heroBrandMark
                    heroCopy
                }
            }
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private var heroBrandMark: some View {
        Image("BrandMark")
            .resizable()
            .scaledToFit()
            .frame(width: 58, height: 58)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: .blue.opacity(0.22), radius: 11, y: 6)
            .accessibilityHidden(true)
    }

    private var heroCopy: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Handle the writing tasks that slow you down.")
                .font(.title2.bold())
            Text("Reply, proofread, plan, summarize, and translate without prompt engineering.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("PRIVACY FIRST")
                .font(.caption2.weight(.black))
                .foregroundStyle(.teal)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(.teal.opacity(0.1), in: Capsule())
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var modelStatus: some View {
        Group {
            if viewModel.isGenerating {
                HStack(spacing: 12) {
                    ProgressView()
                        .tint(.teal)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Writing locally").font(.headline)
                        Text("SucceedAI is completing your request on this device. Nothing is sent to a server.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            } else {
                HStack(spacing: 12) {
                    Image(systemName: viewModel.availability.isAvailable ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(viewModel.availability.isAvailable ? .green : .orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.availability.title).font(.headline)
                        Text(viewModel.availability.detail).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }
        }
        .padding(15)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var composerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            composerHeader
            Text(viewModel.selectedAction.guidance(
                targetLanguage: viewModel.targetLanguage,
                targetTone: viewModel.targetTone
            ))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                Text("WHAT DO YOU NEED DONE?")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                LazyVGrid(columns: actionColumns, spacing: 8) {
                    actionButton(.custom)
                    ForEach(WritingAction.quickActions) { action in
                        actionButton(action)
                    }
                    toneMenu
                    translationMenu
                }
            }

            TextEditor(text: $viewModel.prompt)
                .focused($isComposerFocused)
                .accessibilityIdentifier("composer-editor")
                .frame(minHeight: 150)
                .padding(10)
                .scrollContentBackground(.hidden)
                .background(.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
                .overlay(alignment: .topLeading) {
                    if viewModel.prompt.isEmpty {
                        Text(viewModel.selectedAction.promptPlaceholder(
                            targetLanguage: viewModel.targetLanguage,
                            targetTone: viewModel.targetTone
                        ))
                            .foregroundStyle(.tertiary)
                            .padding(16)
                            .allowsHitTesting(false)
                    }
                }

            Button {
                if viewModel.isGenerating {
                    viewModel.cancelGeneration()
                } else {
                    isComposerFocused = false
                    viewModel.generate()
                }
            } label: {
                HStack {
                    if viewModel.isGenerating { ProgressView().tint(.white) }
                    Label(
                        viewModel.isGenerating ? "Stop generation" : "Generate locally",
                        systemImage: viewModel.isGenerating ? "stop.circle.fill" : "sparkles"
                    )
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
            }
            .buttonStyle(.borderedProminent)
            .tint(viewModel.isGenerating ? .orange : .teal)
            .disabled(
                !viewModel.isGenerating && (
                    viewModel.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    !viewModel.availability.isAvailable
                )
            )

            if let errorMessage = viewModel.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }

            if !viewModel.result.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Label(viewModel.resultActionTitle, systemImage: "checkmark.circle.fill")
                        .font(.caption.bold())
                        .foregroundStyle(.teal)
                    Text(viewModel.result).textSelection(.enabled)
                    HStack {
                        Button { viewModel.copyResult() } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                        }
                        ShareLink(item: viewModel.result) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                        Button { viewModel.refineResult() } label: {
                            Label("Edit draft", systemImage: "pencil")
                        }
                    }
                    .buttonStyle(.bordered)
                    resultRefinementMenu
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.teal.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
                .id("composer-result")
            }

        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .id("composer-card")
    }

    private var keyboardSetup: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SettingsHero(icon: "keyboard.fill", title: "Use SucceedAI in any app", detail: "Type and run a custom AI command without switching keyboards, or transform an unchanged selection in one tap. Everything stays on device.")
                KeyboardTransformationPreview()
                KeyboardTriggerSettingsCard()
                VStack(alignment: .leading, spacing: 14) {
                    SetupStep(number: 1, title: "Enable the keyboard", detail: "In Settings, go to General › Keyboard › Keyboards › Add New Keyboard, then choose SucceedAI.")
                    SetupStep(number: 2, title: "Run a custom command", detail: "With the SucceedAI keyboard active, tap Insert Trigger, type the request on its built-in keys, then press AI Return. No keyboard round trip is needed.")
                    SetupStep(number: 3, title: "Or select what you wrote", detail: "Highlight text in Mail, Messages, Notes, or another compatible app, switch to SucceedAI, and tap the outcome. Only the unchanged selection is replaced.")
                    SetupStep(number: 4, title: "Undo with confidence", detail: "Tap Undo within 90 seconds to restore the original text. SucceedAI refuses if the document, result, or cursor changed.")
                    Button {
                        UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
                    } label: {
                        Label("Open SucceedAI Settings", systemImage: "gear")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.teal)
                }
                .padding(18)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22))
                Text("Full Access is not required. SucceedAI has no server and does not transmit what you type.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }
            .padding()
        }
        .safeAreaPadding(.bottom, 64)
        .background(pageBackground)
        .navigationTitle("Keyboard")
    }

    private var shortcutsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Automate with Shortcuts", systemImage: "command")
                .font(.headline)
            Text("Use dedicated Proofread, Polish, Shorten, Change Tone, Summarize, Draft Reply, Action Items, Plan, Translate, or Transform Text actions in Siri and multi-step workflows. Each action accepts the previous step’s output and stays on device.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button {
                guard let url = URL(string: "shortcuts://") else { return }
                UIApplication.shared.open(url)
            } label: {
                Label("Open Shortcuts", systemImage: "arrow.up.forward.app")
            }
            .buttonStyle(.bordered)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var privacy: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SettingsHero(icon: "lock.shield.fill", title: "Your writing stays yours", detail: "SucceedAI uses Apple’s built-in on-device language model. Prompts and responses never leave your device.")
                PrivacyRow(icon: "wifi.slash", title: "Works offline", detail: "No connection is needed after Apple Intelligence is ready.")
                PrivacyRow(icon: "person.crop.circle.badge.xmark", title: "No account", detail: "There is no sign-up, subscription, tracking profile, or license server.")
                PrivacyRow(icon: "server.rack", title: "No backend", detail: "No API keys, proxy service, prompt logs, or cloud processing.")
            }
            .padding()
        }
        .safeAreaPadding(.bottom, 64)
        .background(pageBackground)
        .navigationTitle("Privacy")
    }

    private var pageBackground: some View {
        LinearGradient(colors: [.teal.opacity(0.09), .blue.opacity(0.05), Color(uiColor: .systemBackground)], startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()
    }

    @ViewBuilder
    private var composerHeader: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) {
                selectedActionLabel
                if viewModel.selectedAction == .translate { translationLanguageBadge }
                if viewModel.selectedAction == .tone { toneBadge }
                onDeviceBadge
            }
        } else {
            HStack(spacing: 8) {
                selectedActionLabel
                if viewModel.selectedAction == .translate { translationLanguageBadge }
                if viewModel.selectedAction == .tone { toneBadge }
                Spacer()
                onDeviceBadge
            }
        }
    }

    private var selectedActionLabel: some View {
        Label(viewModel.selectedAction.title, systemImage: viewModel.selectedAction.systemImage)
            .font(.headline)
            .foregroundStyle(.teal)
    }

    private var translationLanguageBadge: some View {
        Text(viewModel.targetLanguage.displayName)
            .font(.caption2.bold())
            .foregroundStyle(.teal)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.teal.opacity(0.1), in: Capsule())
    }

    private var toneBadge: some View {
        Text(viewModel.targetTone.displayName)
            .font(.caption2.bold())
            .foregroundStyle(.teal)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.teal.opacity(0.1), in: Capsule())
    }

    private var onDeviceBadge: some View {
        Text("PRIVATE ON-DEVICE")
            .font(.caption2.weight(.black))
            .foregroundStyle(.teal)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var actionColumns: [GridItem] {
        if dynamicTypeSize.isAccessibilitySize {
            return [GridItem(.flexible())]
        }
        let columnCount = horizontalSizeClass == .regular ? 4 : 2
        return Array(repeating: GridItem(.flexible(), spacing: 8), count: columnCount)
    }

    private func actionButton(_ action: WritingAction) -> some View {
        Button { viewModel.selectAction(action) } label: {
            HStack(spacing: 10) {
                Image(systemName: action.systemImage)
                Text(action.outcomeTitle)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 2)
                if viewModel.selectedAction == action {
                    Image(systemName: "checkmark")
                        .font(.caption2.bold())
                }
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.roundedRectangle(radius: 12))
        .tint(viewModel.selectedAction == action ? .teal : .secondary)
        .accessibilityValue(viewModel.selectedAction == action ? "Selected" : "Not selected")
        .accessibilityHint(action.guidance(
            targetLanguage: viewModel.targetLanguage,
            targetTone: viewModel.targetTone
        ))
    }

    private var toneMenu: some View {
        Menu {
            ForEach(WritingTone.allCases) { tone in
                Button(tone.displayName) {
                    viewModel.selectTone(tone)
                }
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: WritingAction.tone.systemImage)
                Text(
                    viewModel.selectedAction == .tone
                        ? "Tone · \(viewModel.targetTone.displayName)"
                        : WritingAction.tone.outcomeTitle
                )
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 2)
                if viewModel.selectedAction == .tone {
                    Image(systemName: "checkmark")
                        .font(.caption2.bold())
                }
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.roundedRectangle(radius: 12))
        .tint(viewModel.selectedAction == .tone ? .teal : .secondary)
        .frame(maxWidth: .infinity)
        .accessibilityLabel("Change Tone")
        .accessibilityValue(
            viewModel.selectedAction == .tone
                ? "Selected, \(viewModel.targetTone.displayName)"
                : "Not selected"
        )
        .accessibilityHint("Choose the tone for the result")
    }

    private var translationMenu: some View {
        Menu {
            ForEach(WritingLanguage.allCases) { language in
                Button(language.displayName) {
                    viewModel.selectTranslation(language)
                }
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: WritingAction.translate.systemImage)
                Text(
                    viewModel.selectedAction == .translate
                        ? "Translate · \(viewModel.targetLanguage.displayName)"
                        : WritingAction.translate.outcomeTitle
                )
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 2)
                if viewModel.selectedAction == .translate {
                    Image(systemName: "checkmark")
                        .font(.caption2.bold())
                }
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.roundedRectangle(radius: 12))
        .tint(viewModel.selectedAction == .translate ? .teal : .secondary)
        .frame(maxWidth: .infinity)
        .accessibilityLabel("Translate")
        .accessibilityValue(
            viewModel.selectedAction == .translate
                ? "Selected, target language \(viewModel.targetLanguage.displayName)"
                : "Not selected"
        )
        .accessibilityHint("Choose the target language")
    }

    private var resultRefinementMenu: some View {
        Menu {
            Button("Another version") {
                viewModel.generate()
            }
            Divider()
            Button("Proofread") {
                viewModel.refineResult(with: .proofread)
            }
            Button("Polish") {
                viewModel.refineResult(with: .polish)
            }
            Button("Shorten") {
                viewModel.refineResult(with: .shorten)
            }
            Menu("Change Tone") {
                ForEach(WritingTone.allCases) { tone in
                    Button(tone.displayName) {
                        viewModel.refineResult(with: .tone, targetTone: tone)
                    }
                }
            }
            Menu("Translate") {
                ForEach(WritingLanguage.allCases) { language in
                    Button(language.displayName) {
                        viewModel.refineResult(
                            with: .translate,
                            targetLanguage: language
                        )
                    }
                }
            }
        } label: {
            Label("Refine this result locally", systemImage: "arrow.triangle.2.circlepath")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(.teal)
        .accessibilityHint("Run another local writing pass without copying and pasting")
    }
}

private struct KeyboardTransformationPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select. Tap. Done.")
                .font(.headline)
            VStack(alignment: .leading, spacing: 8) {
                Label("SELECTED TEXT", systemImage: "selection.pin.in.out")
                    .font(.caption2.bold())
                    .foregroundStyle(.indigo)
                Text("Thanks for waiting we fixed it and you can try again")
                    .font(.subheadline)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.indigo.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(.indigo.opacity(0.28), lineWidth: 1)
                    )
                HStack {
                    Label("Polish", systemImage: WritingAction.polish.systemImage)
                        .font(.caption.bold())
                        .foregroundStyle(.teal)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.teal.opacity(0.1), in: Capsule())
                    Image(systemName: "arrow.right")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Label("On-device", systemImage: "lock.shield.fill")
                        .font(.caption.bold())
                        .foregroundStyle(.green)
                }
                Text("Thanks for your patience. We have fixed the issue, and you can try again now.")
                    .font(.body.weight(.medium))
                HStack {
                    Spacer()
                    Label("Undo ready", systemImage: "arrow.uturn.backward")
                        .font(.caption.bold())
                        .foregroundStyle(.indigo)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.indigo.opacity(0.09), in: Capsule())
                }
                Text("If the document or selection changes while SucceedAI works, nothing is overwritten.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [.indigo.opacity(0.09), .blue.opacity(0.07), .purple.opacity(0.08)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct KeyboardTriggerSettingsCard: View {
    @State private var draft: String
    @State private var savedTrigger: String
    @State private var confirmation: String?
    @FocusState private var isEditing: Bool

    init() {
        let trigger = KeyboardTriggerSettings.load()
        _draft = State(initialValue: trigger)
        _savedTrigger = State(initialValue: trigger)
    }

    private var normalizedDraft: String? {
        KeyboardTriggerSettings.validated(draft)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Your keyboard trigger", systemImage: "command")
                .font(.headline)
            Text("Choose a short, uncommon trigger. It must start with /, ;, :, !, @, or # and contain no spaces.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            TextField("/ai", text: $draft)
                .accessibilityIdentifier("keyboard-trigger-field")
                .focused($isEditing)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.body.monospaced())
                .padding(10)
                .background(.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
                .onChange(of: draft) { _, _ in confirmation = nil }

            HStack {
                Button("Save trigger") {
                    guard let trigger = normalizedDraft,
                          KeyboardTriggerSettings.save(trigger) else { return }
                    savedTrigger = trigger
                    draft = trigger
                    confirmation = "Saved. SucceedAI Keyboard will use \(trigger) the next time it appears."
                    isEditing = false
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
                .accessibilityIdentifier("keyboard-trigger-save")
                .buttonStyle(.borderedProminent)
                .tint(.teal)
                .disabled(normalizedDraft == nil || normalizedDraft == savedTrigger)

                Button("Restore /ai") {
                    KeyboardTriggerSettings.restoreDefault()
                    draft = KeyboardTriggerSettings.defaultTrigger
                    savedTrigger = KeyboardTriggerSettings.defaultTrigger
                    confirmation = "Restored /ai."
                    isEditing = false
                }
                .buttonStyle(.bordered)
            }

            if let confirmation {
                Label(confirmation, systemImage: "checkmark.circle.fill")
                    .font(.footnote)
                    .foregroundStyle(.green)
            } else if normalizedDraft == nil {
                Label("Use 2 to 12 characters, start with punctuation, and do not include spaces.", systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            } else {
                Text("Saved trigger: \(savedTrigger) · Full Access remains off.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct SettingsHero: View {
    let icon: String
    let title: String
    let detail: String
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon).font(.system(size: 34, weight: .bold)).foregroundStyle(.teal)
            Text(title).font(.largeTitle.bold())
            Text(detail).foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
    }
}

private struct SetupStep: View {
    let number: Int
    let title: String
    let detail: String
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)").font(.headline).foregroundStyle(.white).frame(width: 32, height: 32).background(.teal, in: Circle())
            VStack(alignment: .leading, spacing: 3) { Text(title).font(.headline); Text(detail).font(.subheadline).foregroundStyle(.secondary) }
        }
    }
}

private struct PrivacyRow: View {
    let icon: String
    let title: String
    let detail: String
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon).font(.title2).foregroundStyle(.teal).frame(width: 38)
            VStack(alignment: .leading, spacing: 3) { Text(title).font(.headline); Text(detail).foregroundStyle(.secondary) }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
    }
}
