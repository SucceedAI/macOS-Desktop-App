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
        print("Waiting for a response from the server")

        aiProvider.query(actualQuery) { response in
            // Add a short delay before typing the response
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            //DispatchQueue.main.async {
                // Type the API response to end-user window
                self.replaceUserInput(with: response)
            }
        }
    }

    private func resetCommandState() {
        isCommandActive = false
        currentTypedString = ""
    }

    private func replaceUserInput(with response: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.declareTypes([.string], owner: nil)
        pasteboard.setString(response, forType: .string)
        
        let source = CGEventSource(stateID: .combinedSessionState)
        
        // Move the cursor to the beginning of the line
        let moveToBeginningKeyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_Home), keyDown: true)
        let moveToBeginningKeyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_Home), keyDown: false)
        moveToBeginningKeyDown?.post(tap: .cghidEventTap)
        moveToBeginningKeyUp?.post(tap: .cghidEventTap)
        
        // Select the "/ai <QUERY>" text
        let selectTextKeyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_RightShift), keyDown: true)
        let selectTextKeyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_RightShift), keyDown: false)
        
        selectTextKeyDown?.post(tap: .cghidEventTap)
        for _ in 0..<currentTypedString.count {
            let moveRightKeyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_RightArrow), keyDown: true)
            let moveRightKeyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_RightArrow), keyDown: false)
            moveRightKeyDown?.post(tap: .cghidEventTap)
            moveRightKeyUp?.post(tap: .cghidEventTap)
        }
        selectTextKeyUp?.post(tap: .cghidEventTap)
        
        // Delete the selected "/ai <QUERY>" text
        let deleteKeyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_Delete), keyDown: true)
        let deleteKeyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_Delete), keyDown: false)
        deleteKeyDown?.post(tap: .cghidEventTap)
        deleteKeyUp?.post(tap: .cghidEventTap)
        
        // Type the response
        for char in response {
            let keyDownEvent = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true)
            let keyUpEvent = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
            let unicodeString = String(char).utf16.map { UniChar($0) }
            keyDownEvent?.keyboardSetUnicodeString(stringLength: unicodeString.count, unicodeString: unicodeString)
            keyUpEvent?.keyboardSetUnicodeString(stringLength: unicodeString.count, unicodeString: unicodeString)
            keyDownEvent?.post(tap: .cghidEventTap)
            keyUpEvent?.post(tap: .cghidEventTap)
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
