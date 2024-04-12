// AXIsProcessTrustedWithOptions is part of the Application Services framework,
// which is a part of Carbon. Ensure it's correctly imported and used.
// However, this function should typically be available once you import AppKit
import AppKit
import Cocoa
import Carbon.HIToolbox

class GlobalKeystrokeManager {
    @Published var keystrokePrefixTrigger: String = Config.keystrokePrefixTrigger

    private var currentTypedString: String = ""
    private var isCommandActive: Bool = false
    private var aiProvider: AIProvideable
    private var eventMonitor: Any?

    init(aiProvider: AIProvideable) {
        self.aiProvider = aiProvider
    }

    deinit {
        stopGlobalKeystrokeMonitoring()
    }

    public func triggerGlobalKeystrokeMonitoring() {
        let accessEnabled = checkAndRequestAccessibilityPermission()

        // fail-early and exit the function as early as possible
        if !accessEnabled {
            print("Ouch! Accessibility permissions is not granted. Cannot procceed to the request event")

            // Logic to notify the user about granting permissions goes here
            return
        }

        // add the event to the event handler
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleEvent(event)
        }
    }

    private func handleEvent(_ event: NSEvent) {
        guard let characters = event.charactersIgnoringModifiers else { return }

        // If ENTER key pressed
        if isCommandActive && characters == "\r" {
            print("Pressed enter")
            print(currentTypedString)

            if currentTypedString.hasPrefix(keystrokePrefixTrigger) {
                print("yes")
                //if event.keyCode == kVK_Return {
                // When Enter (Return) is pressed, process the query
                processQuery()

                // Once processed, reset the query to empty
                resetCommandState()
            } else {
                // Flush buffer if prefix doesn't match with "/ai"
                resetCommandState()
            }
        } else if event.keyCode == kVK_Delete && !currentTypedString.isEmpty {
            // Handle backspace
            currentTypedString.removeLast()
        } else {
            // Append new characters to the current string
            currentTypedString += characters

            isCommandActive = true
        }
    }

    private func processQuery() {
        let actualQuery = String(currentTypedString.dropFirst(keystrokePrefixTrigger.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        print("Waiting for a response from the server")

        aiProvider.query(actualQuery) { response in
            DispatchQueue.main.async {
                self.insertText(response)
            }
        }
    }

    private func resetCommandState() {
        isCommandActive = false
        currentTypedString = ""
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

    private func stopGlobalKeystrokeMonitoring() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        eventMonitor = nil
    }

    func checkAndRequestAccessibilityPermission() -> Bool {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        return AXIsProcessTrustedWithOptions(options)
    }
}
