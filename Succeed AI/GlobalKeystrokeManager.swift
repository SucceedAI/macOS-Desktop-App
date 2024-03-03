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
        
        // fail-fast and exit the function as early as possible
        if !accessEnabled {
            // If not enabled, you will want to notify your UI layer to alert the user.
            // This can be done via a callback, NotificationCenter, etc.
            return
        }
        
        
        // add the event to the event handler
        NSEvent.addGlobalMonitorForEvents(
            matching: [.keyUp, .keyDown],
            handler: { (event) in
            self.handleEvent(event)
        })
    }

    private func handleEvent(_ event: NSEvent) {
        guard let characters = event.characters else { return }

        if isCommandActive {
            if event.keyCode == kVK_Return || event.keyCode == kVK_Space {
                // End of command
                isCommandActive = false
                let query = currentTypedString.trimmingCharacters(in: .whitespaces)
                if query.hasPrefix(uniqueKeystrokeTrigger) {
                    let actualQuery = String(query.dropFirst(4))
                    aiProvider.sendQuery(actualQuery) { response in
                        self.onKeystrokeDetected(response)
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
    
    func checkAccessibilityPermission() -> Bool {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as CFString: false]
        return AXIsProcessTrustedWithOptions(options)
    }

    func requestAccessibilityPermission() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as CFString: true]
        _ = AXIsProcessTrustedWithOptions(options)
    }
}
