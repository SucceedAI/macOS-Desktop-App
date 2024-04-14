// AXIsProcessTrustedWithOptions is part of the Application Services framework,
// which is a part of Carbon. Ensure it's correctly imported and used.
// However, this function should typically be available once you import AppKit
import AppKit
import Cocoa
import Carbon.HIToolbox

class GlobalKeystrokeManager {
    @Published var isLoading: Bool = false
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
            if !currentTypedString.contains(keystrokePrefixTrigger) {
                // Flush buffer if doesn't match with "/ai" command
                resetCommandState()
                return
            }

            //if event.keyCode == kVK_Return {
            // When Enter (Return) is pressed, process the query
            processQuery()

            // Once processed, reset the query to empty
            resetCommandState()
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
        isLoading = true // Set isLoading to true before making the API request

        aiProvider.query(actualQuery) { response in
            // Add a short delay before typing the response
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            //DispatchQueue.main.async {
                // Type the API response to end-user window
                self.replaceUserInput(with: response)

                // Note: placing `isLoading = false` inside the asyncAfter() block to ensure proper synchronization with the UI update
                self.isLoading = false // Set isLoading to false after typing the response
            }
        }
    }

    private func resetCommandState() {
        isCommandActive = false
        currentTypedString = ""
    }

    private func replaceUserInput(with response: String) {
        let source = CGEventSource(stateID: .combinedSessionState)

        // Select the user's input
        let selectAllKeyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_A), keyDown: true)
        let selectAllKeyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_A), keyDown: false)

        let commandKey = CGEventFlags.maskCommand
        selectAllKeyDown?.flags = commandKey
        selectAllKeyUp?.flags = commandKey

        selectAllKeyDown?.post(tap: CGEventTapLocation.cghidEventTap)
        selectAllKeyUp?.post(tap: CGEventTapLocation.cghidEventTap)

        // TODO Find a less-strict version when it doesn't remove the above texts from the user
        // Currently, it would erase everything from theb active window. Only CMD+Z can undo the ereased entries previously typed and deleted by Succeed AI
        // Delete the selected user's input
        let deleteKeyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_Delete), keyDown: true)
        let deleteKeyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_Delete), keyDown: false)
        deleteKeyDown?.post(tap: CGEventTapLocation.cghidEventTap)
        deleteKeyUp?.post(tap: CGEventTapLocation.cghidEventTap)

        // Type the response
        for character in response.unicodeScalars {
            let unicodeString = String(character).utf16.map { UniChar($0) }
            let keyDownEvent = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true)
            let keyUpEvent = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
            keyDownEvent?.keyboardSetUnicodeString(stringLength: unicodeString.count, unicodeString: unicodeString)
            keyUpEvent?.keyboardSetUnicodeString(stringLength: unicodeString.count, unicodeString: unicodeString)
            keyDownEvent?.post(tap: CGEventTapLocation.cghidEventTap)
            keyUpEvent?.post(tap: CGEventTapLocation.cghidEventTap)
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
