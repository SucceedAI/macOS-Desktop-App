import Cocoa
import Carbon.HIToolbox

class GlobalKeystrokeManager {
    // can be change by another unique keystroke event ID
    @Published var uniqueKeystrokeTrigger: String = "/ai "

    private var currentTypedString: String = ""
    private var onKeystrokeDetected: (String) -> Void
    private var isCommandActive: Bool = false
    private var aiProvider: AIProvideable

    init(aiProvider: AIProvideable, onKeystrokeDetected: @escaping (String) -> Void) {
        self.aiProvider = aiProvider
        self.onKeystrokeDetected = onKeystrokeDetected
        setupGlobalKeystrokeMonitoring()
    }

    private func setupGlobalKeystrokeMonitoring() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as CFString: true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options)
        
        // fail-early and exit the function as early as possible
        if !accessEnabled {
            // If not enabled, you will want to notify your UI layer to alert the user.
            // This can be done via a callback, NotificationCenter, etc.
            return
        }
        
        // add the event to the event handler
        NSEvent.addGlobalMonitorForEvents(matching: [.keyUp, .keyDown]) { [weak self] event in
            self?.handleEvent(event)
        }
    }

    private func handleEvent(_ event: NSEvent) {
        guard let characters = event.charactersIgnoringModifiers else { return }

        if isCommandActive {
            if event.keyCode == kVK_Return {
                isCommandActive = false
                let trimmedString = currentTypedString.trimmingCharacters(in: .whitespacesAndNewlines)
                let uniqueKeystrokeTrigger = Config.uniqueKeystrokeTrigger
                if trimmedString.hasPrefix(uniqueKeystrokeTrigger) {
                    let actualQuery = String(trimmedString.dropFirst(uniqueKeystrokeTrigger.count)).trimmingCharacters(in: .whitespaces)

                    // send data to API
                    aiProvider.query(actualQuery) { response in
                        DispatchQueue.main.async {
                            let fullCommandLength = uniqueKeystrokeTrigger.count + actualQuery.count
                            self.insertText(replacing: fullCommandLength, with: response)
                        }
                    }
                }
                currentTypedString = ""
            } else {
                // Append characters to the current query
                currentTypedString += characters
            }
        } else if characters == "/" {
            // Start of command
            isCommandActive = true
            currentTypedString = characters
        }
    }

    private func insertText(replacing queryLength: Int, with response: String) {
        let backspaces = String(repeating: "\u{8}", count: queryLength)
        let scriptText = """
                         tell application "System Events"
                             keystroke "\(backspaces)"
                             delay 0.2
                             keystroke "\(response)"
                         end tell
                         """
        executeAppleScript(scriptText)
    }

    private func executeAppleScript(_ scriptText: String) {
        var error: NSDictionary?
        if let script = NSAppleScript(source: scriptText) {
            script.executeAndReturnError(&error)
        }

        if let error = error {
            print("AppleScript Error: \(error)")
        }
    }

    func checkAccessibilityPermission() -> Bool {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as CFString: false]
        return AXIsProcessTrustedWithOptions(options)
    }

    func requestAccessibilityPermission() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as CFString: true]
        _ = AXIsProcessTrustedWithOptions(options)
    }
}
