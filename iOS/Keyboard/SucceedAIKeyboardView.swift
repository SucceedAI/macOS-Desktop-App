import SwiftUI

struct SucceedAIKeyboardView: View {
    @ObservedObject var viewModel: KeyboardViewModel
    let nextKeyboard: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            header
            commandBar
            statusBar

            if viewModel.hasSelection {
                selectionActions
            } else {
                SucceedAITypingPad(
                    returnIsAI: viewModel.hasRunnableCommand,
                    isEnabled: !viewModel.isGenerating,
                    insertText: viewModel.insertKey,
                    deleteBackward: viewModel.deleteKey,
                    submitOrReturn: viewModel.handleReturnKey
                )
            }
        }
        .padding(10)
        .background(.ultraThinMaterial)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image("BrandMark")
                .resizable()
                .scaledToFit()
                .frame(width: 26, height: 26)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                .accessibilityHidden(true)
            Text("SucceedAI")
                .font(.headline)
            Text(viewModel.hasSelection ? "SELECTION" : viewModel.trigger)
                .font(.caption2.bold())
                .foregroundStyle(viewModel.hasSelection ? .green : .teal)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background((viewModel.hasSelection ? Color.green : .teal).opacity(0.1), in: Capsule())
            Spacer(minLength: 4)
            if !viewModel.hasSelection {
                presetMenu
            }
            Button(action: nextKeyboard) {
                Image(systemName: "globe")
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .accessibilityLabel("Next keyboard")
        }
    }

    private var presetMenu: some View {
        Menu {
            ForEach(WritingAction.quickActions) { action in
                Button(action.title) {
                    viewModel.performAction(action)
                }
            }
            Menu("Translate") {
                ForEach(WritingLanguage.allCases) { language in
                    Button(language.displayName) {
                        viewModel.performTranslation(to: language)
                    }
                }
            }
        } label: {
            Image(systemName: "wand.and.stars")
                .frame(width: 22, height: 22)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .accessibilityLabel("Writing presets")
        .accessibilityHint("Insert a prepared local AI command")
    }

    private var commandBar: some View {
        HStack(spacing: 8) {
            Button(viewModel.hasSelection ? "Selection ready" : "Insert \(viewModel.trigger)") {
                viewModel.insertTrigger()
            }
            .frame(maxWidth: .infinity)
            .buttonStyle(.bordered)
            .disabled(viewModel.isGenerating || viewModel.hasSelection)
            .accessibilityHint("Insert your configured trigger and type the request on this keyboard")

            Button {
                if viewModel.isGenerating {
                    viewModel.cancelGeneration()
                } else {
                    viewModel.replaceCommand()
                }
            } label: {
                HStack(spacing: 5) {
                    if viewModel.isGenerating { ProgressView().tint(.white) }
                    Label(commandButtonTitle, systemImage: commandButtonImage)
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(viewModel.isGenerating ? .orange : .teal)
            .disabled(!viewModel.isGenerating && !viewModel.hasPendingResult && !viewModel.hasRunnableCommand)
        }
        .controlSize(.small)
    }

    private var commandButtonTitle: String {
        if viewModel.isGenerating { return "Stop" }
        if viewModel.hasPendingResult { return "Insert result" }
        return "Run now"
    }

    private var commandButtonImage: String {
        if viewModel.isGenerating { return "stop.circle.fill" }
        if viewModel.hasPendingResult { return "text.badge.checkmark" }
        return "wand.and.sparkles"
    }

    private var statusBar: some View {
        HStack(alignment: .center, spacing: 7) {
            Label(
                viewModel.status,
                systemImage: viewModel.isError ? "exclamationmark.triangle.fill" : "lock.shield.fill"
            )
            .font(.caption2)
            .foregroundStyle(viewModel.isError ? .orange : .secondary)
            .lineLimit(2)
            .frame(maxWidth: .infinity, minHeight: 30, alignment: .leading)

            if viewModel.hasPendingResult {
                Button("Discard", action: viewModel.discardPendingResult)
                    .font(.caption2.bold())
                    .buttonStyle(.borderless)
            }
            if viewModel.hasUndoableEdit {
                Button {
                    viewModel.undoLastEdit()
                } label: {
                    Label("Undo", systemImage: "arrow.uturn.backward")
                }
                .font(.caption2.bold())
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .accessibilityHint("Restore the original text if the result and cursor are unchanged")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 9))
    }

    private var selectionActions: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("TRANSFORM THE UNCHANGED SELECTION — ONE TAP")
                .font(.caption2.bold())
                .foregroundStyle(.green)
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4),
                spacing: 6
            ) {
                ForEach(WritingAction.quickActions) { action in
                    Button {
                        viewModel.performAction(action)
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: action.systemImage)
                            Text(compactTitle(for: action))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .font(.caption2.bold())
                        .frame(maxWidth: .infinity, minHeight: 36)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.roundedRectangle(radius: 9))
                    .controlSize(.small)
                    .disabled(viewModel.isGenerating)
                    .accessibilityLabel(action.title)
                    .accessibilityHint("Transform the selected text locally")
                }
                translationMenu
            }
        }
    }

    private var translationMenu: some View {
        Menu {
            ForEach(WritingLanguage.allCases) { language in
                Button(language.displayName) {
                    viewModel.performTranslation(to: language)
                }
            }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: "character.bubble")
                Text("Translate")
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .font(.caption2.bold())
            .frame(maxWidth: .infinity, minHeight: 36)
        }
        .menuStyle(.button)
        .buttonBorderShape(.roundedRectangle(radius: 9))
        .controlSize(.small)
        .frame(maxWidth: .infinity)
        .disabled(viewModel.isGenerating)
        .accessibilityHint("Choose the target language")
    }

    private func compactTitle(for action: WritingAction) -> String {
        switch action {
        case .reply: "Reply"
        case .summarize: "Summary"
        case .actionItems: "Actions"
        case .plan: "Plan"
        default: action.title
        }
    }
}

private struct SucceedAITypingPad: View {
    let returnIsAI: Bool
    let isEnabled: Bool
    let insertText: (String) -> Void
    let deleteBackward: () -> Void
    let submitOrReturn: () -> Void

    @State private var showsSymbols = false
    @State private var isUppercase = false

    private let letterRows = [
        ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"],
        ["a", "s", "d", "f", "g", "h", "j", "k", "l"],
        ["z", "x", "c", "v", "b", "n", "m"],
    ]
    private let symbolRows = [
        ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"],
        ["-", "/", ":", ";", "(", ")", "$", "&", "@", "\""],
        [".", ",", "?", "!", "'", "[", "]"],
    ]

    var body: some View {
        VStack(spacing: 5) {
            keyRow(rows[0])
            keyRow(rows[1])
                .padding(.horizontal, 14)
            HStack(spacing: 5) {
                if !showsSymbols {
                    specialKey(systemImage: isUppercase ? "shift.fill" : "shift") {
                        isUppercase.toggle()
                    }
                }
                keyButtons(rows[2])
                specialKey(systemImage: "delete.left", action: deleteBackward)
            }
            HStack(spacing: 5) {
                specialKey(title: showsSymbols ? "ABC" : "123") {
                    showsSymbols.toggle()
                    isUppercase = false
                }
                if !showsSymbols {
                    textKey(",")
                }
                Button {
                    insertText(" ")
                } label: {
                    Text("space")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(KeyboardKeyStyle())
                if !showsSymbols {
                    textKey(".")
                }
                Button(action: submitOrReturn) {
                    Label(returnIsAI ? "AI Return" : "return", systemImage: returnIsAI ? "sparkles" : "return")
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(KeyboardKeyStyle(isProminent: returnIsAI))
                .accessibilityHint(returnIsAI ? "Generate locally and replace the unchanged command" : "Insert a new line")
            }
        }
        .font(.callout)
        .disabled(!isEnabled)
    }

    private var rows: [[String]] {
        showsSymbols ? symbolRows : letterRows
    }

    private func keyRow(_ keys: [String]) -> some View {
        HStack(spacing: 5) {
            keyButtons(keys)
        }
    }

    @ViewBuilder
    private func keyButtons(_ keys: [String]) -> some View {
        ForEach(keys, id: \.self) { key in
            textKey(key)
        }
    }

    private func textKey(_ key: String) -> some View {
        let output = !showsSymbols && isUppercase ? key.uppercased() : key
        return Button {
            insertText(output)
            if !showsSymbols && isUppercase { isUppercase = false }
        } label: {
            Text(output)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(KeyboardKeyStyle())
        .frame(height: 36)
    }

    private func specialKey(
        title: String? = nil,
        systemImage: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Group {
                if let systemImage {
                    Image(systemName: systemImage)
                } else {
                    Text(title ?? "")
                        .font(.caption.bold())
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(KeyboardKeyStyle(isSpecial: true))
        .frame(width: 48, height: 36)
    }
}

private struct KeyboardKeyStyle: ButtonStyle {
    var isSpecial = false
    var isProminent = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(minHeight: 36)
            .foregroundStyle(isProminent ? Color.white : Color.primary)
            .background(
                isProminent
                    ? Color.teal.opacity(configuration.isPressed ? 0.72 : 1)
                    : Color.secondary.opacity(configuration.isPressed ? 0.24 : (isSpecial ? 0.16 : 0.09)),
                in: RoundedRectangle(cornerRadius: 7, style: .continuous)
            )
    }
}
