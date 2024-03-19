import Cocoa
import Carbon.HIToolbox

class GlobalKeystrokeManager {
    @Published var uniqueKeystrokeTrigger: String = Config.uniqueKeystrokeTrigger

    private var currentTypedString: String = ""
    private var isCommandActive: Bool = true // false
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
        guard let characters = event.characters else { return }

        // Appending the typed character
        currentTypedString += characters
        
        let enterKey = event.keyCode == kVK_Return

        if enterKey && isCommandActive {
            // End of command processing
            isCommandActive = false
            let query = currentTypedString.trimmingCharacters(in: .whitespacesAndNewlines)
            if query.hasPrefix(uniqueKeystrokeTrigger) {
                let trimmedQuery = String(query.dropFirst(uniqueKeystrokeTrigger.count)).trimmingCharacters(in: .whitespaces)
                aiProvider.query(trimmedQuery) { response in
                    DispatchQueue.main.async {
                        let fullCommandLength = self.uniqueKeystrokeTrigger.count + trimmedQuery.count
                        self.insertText(replacing: fullCommandLength, with: response)
                    }
                }
            }
            currentTypedString = ""
        } else if characters.starts(with: uniqueKeystrokeTrigger) {
        //} else if characters == "/" {
            // Start of command
            isCommandActive = true
            currentTypedString = characters
        } else if isCommandActive {
            // Continue accumulating characters
            currentTypedString += characters
        }
    }
    
    private func insertText(replacing queryLength: Int, with response: String) {
        let backspaces = String(repeating: "\u{8}", count: queryLength)
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
