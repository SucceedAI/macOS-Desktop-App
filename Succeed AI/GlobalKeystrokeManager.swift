import Cocoa
import Carbon.HIToolbox

class GlobalKeystrokeManager {
    @Published var uniqueKeystrokeTrigger: String = Config.uniqueKeystrokeTrigger

    private var currentTypedString: String = ""
    private var onKeystrokeDetected: (String) -> Void
    private var isCommandActive: Bool = false
    private var aiProvider: AIProvideable

    init(aiProvider: AIProvideable, onKeystrokeDetected: @escaping (String) -> Void) {
        self.aiProvider = aiProvider
        self.onKeystrokeDetected = onKeystrokeDetected
        setupGlobalKeystrokeMonitoring()
    }

    public func setupGlobalKeystrokeMonitoring() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as CFString: true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options)

        // fail-early and exit the function as early as possible
        if !accessEnabled {
            // notify the user if accessibility permissions are not granted
            return
        }

        NSEvent.addGlobalMonitorForEvents(matching: [.keyUp, .keyDown]) { [weak self] event in
            self?.handleEvent(event)
        }
    }

    private func handleEvent(_ event: NSEvent) {
        guard let characters = event.charactersIgnoringModifiers else { return }
        
        let enterKey = event.keyCode == kVK_Return

        if enterKey && isCommandActive {
            isCommandActive = false
            let query = currentTypedString.trimmingCharacters(in: .whitespacesAndNewlines)
            // send data to API
            aiProvider.query(query) { response in
                DispatchQueue.main.async {
                    let fullCommandLength = self.uniqueKeystrokeTrigger.count + query.count
                    self.insertText(replacing: fullCommandLength, with: response)
                }
            }
            currentTypedString = ""
        } else if characters.starts(with: uniqueKeystrokeTrigger) {
            isCommandActive = true
            currentTypedString = characters
        } else if isCommandActive {
            currentTypedString += characters
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
