// AXIsProcessTrustedWithOptions is part of the Application Services framework,
// which is a part of Carbon. Ensure it's correctly imported and used.
// However, this function should typically be available once you import AppKit
import AppKit
import Cocoa
import Carbon.HIToolbox
import Combine

class GlobalKeystrokeManager {
    @Published var isLoading: Bool = false
    @Published var keystrokePrefixTrigger: String = Config.keystrokePrefixTrigger

    private var currentTypedString: String = ""
    private var isCommandActive: Bool = false
    private var aiProvider: AIProvideable
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    init(aiProvider: AIProvideable) {
        self.aiProvider = aiProvider
    }

    deinit {
        stopGlobalKeystrokeMonitoring()
    }

    @discardableResult
    public func triggerGlobalKeystrokeMonitoring() -> Bool {
        if eventTap != nil {
            return true
        }

        let accessEnabled = checkAndRequestAccessibilityPermission(prompt: true)

        if !accessEnabled {
            print("Accessibility permission is not granted. Cannot monitor global keystrokes.")
            return false
        }

        let eventMask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard let userInfo else {
                return Unmanaged.passUnretained(event)
            }

            let manager = Unmanaged<GlobalKeystrokeManager>
                .fromOpaque(userInfo)
                .takeUnretainedValue()

            return manager.handleEventTap(type: type, event: event)
        }

        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            print("Unable to create keyboard event tap.")
            return false
        }

        guard let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0) else {
            CFMachPortInvalidate(eventTap)
            print("Unable to create keyboard event tap run loop source.")
            return false
        }

        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)

        self.eventTap = eventTap
        self.runLoopSource = runLoopSource

        return true
    }

    private func handleEventTap(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }

            return Unmanaged.passUnretained(event)
        }

        guard type == .keyDown, let nsEvent = NSEvent(cgEvent: event) else {
            return Unmanaged.passUnretained(event)
        }

        if nsEvent.keyCode == kVK_Return {
            let didProcessCommand = processQuery(commandText: currentTypedString)
            resetCommandState()
            return didProcessCommand ? nil : Unmanaged.passUnretained(event)
        }

        if nsEvent.keyCode == kVK_Delete && !currentTypedString.isEmpty {
            currentTypedString.removeLast()
            isCommandActive = !currentTypedString.isEmpty
            return Unmanaged.passUnretained(event)
        }

        let ignoredModifiers: NSEvent.ModifierFlags = [.command, .control, .option]
        guard nsEvent.modifierFlags.intersection(ignoredModifiers).isEmpty,
              let characters = nsEvent.characters,
              !characters.isEmpty
        else {
            return Unmanaged.passUnretained(event)
        }

        trackTypedCharacters(characters)

        return Unmanaged.passUnretained(event)
    }

    private func trackTypedCharacters(_ characters: String) {
        currentTypedString += characters

        if currentTypedString.count > 1_000 {
            currentTypedString = String(currentTypedString.suffix(1_000))
        }

        if currentTypedString.hasPrefix(keystrokePrefixTrigger) {
            isCommandActive = true
            return
        }

        if keystrokePrefixTrigger.hasPrefix(currentTypedString) {
            isCommandActive = false
            return
        }

        if characters == String(keystrokePrefixTrigger.prefix(1)) {
            currentTypedString = characters
            isCommandActive = false
            return
        }

        resetCommandState()
    }

    private func processQuery(commandText: String) -> Bool {
        guard isCommandActive, commandText.hasPrefix(keystrokePrefixTrigger) else {
            return false
        }

        let actualQuery = String(commandText.dropFirst(keystrokePrefixTrigger.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !actualQuery.isEmpty else {
            return false
        }

        DispatchQueue.main.async {
            self.isLoading = true
        }

        aiProvider.query(actualQuery) { response in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.replaceUserInput(with: response, replacing: commandText)
                self.isLoading = false
            }
        }

        return true
    }

    private func resetCommandState() {
        isCommandActive = false
        currentTypedString = ""
    }

    private func replaceUserInput(with response: String, replacing commandText: String) {
        let source = CGEventSource(stateID: .combinedSessionState)

        for _ in commandText {
            let deleteKeyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_Delete), keyDown: true)
            let deleteKeyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_Delete), keyDown: false)
            deleteKeyDown?.post(tap: CGEventTapLocation.cghidEventTap)
            deleteKeyUp?.post(tap: CGEventTapLocation.cghidEventTap)
        }

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
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            self.runLoopSource = nil
        }

        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
            self.eventTap = nil
        }
    }

    func isAccessibilityPermissionGranted() -> Bool {
        AXIsProcessTrusted()
    }

    func checkAndRequestAccessibilityPermission(prompt: Bool) -> Bool {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt]
        return AXIsProcessTrustedWithOptions(options)
    }
}
