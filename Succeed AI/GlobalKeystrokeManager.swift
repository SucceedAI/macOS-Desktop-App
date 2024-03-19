import Cocoa
import Carbon.HIToolbox

class GlobalKeystrokeManager {
    @Published var uniqueKeystrokeTrigger: String = Config.uniqueKeystrokeTrigger

    private var currentTypedString: String = ""
    private var isCommandActive: Bool = false
    private var aiProvider: AIProvideable
    private var eventMonitor: Any?

    init(aiProvider: AIProvideable) {
        self.aiProvider = aiProvider
        triggerGlobalKeystrokeMonitoring()
    }

    deinit {
        stopGlobalKeystrokeMonitoring()
    }

    public func triggerGlobalKeystrokeMonitoring() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as CFString: true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options)

        // fail-early and exit the function as early as possible
        if !accessEnabled {
            print("Accessibility permissions not granted")
            return
        }

        // add the event to the event handler
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleEvent(event)
        }
    }

    private func stopGlobalKeystrokeMonitoring() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        eventMonitor = nil
    }

    private func handleEvent(_ event: NSEvent) {
        guard let characters = event.charactersIgnoringModifiers else { return }

        if event.keyCode == kVK_Delete && !currentTypedString.isEmpty {
            currentTypedString.removeLast()
        } else {
            if !isCommandActive && currentTypedString.hasPrefix(uniqueKeystrokeTrigger) {
                isCommandActive = true
            } else if isCommandActive && !currentTypedString.hasPrefix(uniqueKeystrokeTrigger) {
                isCommandActive = false
            }
            currentTypedString += characters

            if isCommandActive && event.keyCode == kVK_Return {
                processCommand()
            }
        }
    }

    private func processCommand() {
        let query = currentTypedString.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.hasPrefix(uniqueKeystrokeTrigger) {
            let trimmedQuery = String(query.dropFirst(uniqueKeystrokeTrigger.count)).trimmingCharacters(in: .whitespaces)
            aiProvider.query(trimmedQuery) { response in
                DispatchQueue.main.async {
                    self.insertText(response)
                }
            }
        }
        resetCommandState()
    }

    private func resetCommandState() {
        isCommandActive = false
        currentTypedString = ""
        commandCompletionTimer?.invalidate()
    }

    private func insertText(_ response: String) {
        // Calculate the number of backspaces needed to remove the typed query
        let numBackspaces = currentTypedString.count
        let backspaces = String(repeating: "\u{8}", count: numBackspaces)

        // Construct and execute the AppleScript
        let scriptText = """
                         tell application "System Events"
                             keystroke "\(backspaces)"
                             delay 0.1
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
