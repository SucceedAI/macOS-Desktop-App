// AXIsProcessTrustedWithOptions is part of the Application Services framework,
// which is a part of Carbon. Ensure it's correctly imported and used.
// However, this function should typically be available once you import AppKit
import AppKit
import Cocoa
import Carbon.HIToolbox
import Combine

class GlobalKeystrokeManager {
    @Published var isLoading: Bool = false

    private var currentTypedString: String = ""
    private var isCommandActive: Bool = false
    private var aiProvider: AIProvideable
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isReplacingText: Bool = false
    private var activeReplacementID: UUID?

    private var keystrokePrefixTrigger: String {
        UserSettings.commandTrigger()
    }

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

        if isReplacingText {
            return Unmanaged.passUnretained(event)
        }

        if nsEvent.keyCode == kVK_Return {
            let didProcessCommand = processQuery(commandText: currentTypedString)
            resetCommandState()
            return didProcessCommand ? nil : Unmanaged.passUnretained(event)
        }

        if nsEvent.keyCode == kVK_Delete && !currentTypedString.isEmpty {
            currentTypedString.removeLast()
            isCommandActive = currentTypedString.hasPrefix(keystrokePrefixTrigger)
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
        let trigger = keystrokePrefixTrigger
        guard isCommandActive, commandText.hasPrefix(trigger) else {
            return false
        }

        let actualQuery = String(commandText.dropFirst(trigger.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !actualQuery.isEmpty else {
            return false
        }

        let replacementID = UUID()
        activeReplacementID = replacementID
        isReplacingText = true
        removeUserInput(replacing: commandText)

        DispatchQueue.main.async {
            self.isLoading = true
        }

        scheduleReplacementFailsafe(replacementID: replacementID, commandText: commandText)

        aiProvider.query(actualQuery) { result in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                guard self.activeReplacementID == replacementID else {
                    return
                }

                switch result {
                case .success(let response):
                    self.insertResponse(response)
                case .failure(let error):
                    NSSound.beep()
                    self.insertResponse(commandText)
                    print(error.userMessage)
                }

                self.activeReplacementID = nil
                self.isReplacingText = false
                self.isLoading = false
            }
        }

        return true
    }

    private func resetCommandState() {
        isCommandActive = false
        currentTypedString = ""
    }

    private func removeUserInput(replacing commandText: String) {
        let source = CGEventSource(stateID: .combinedSessionState)

        for _ in commandText {
            let deleteKeyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_Delete), keyDown: true)
            let deleteKeyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_Delete), keyDown: false)
            deleteKeyDown?.post(tap: CGEventTapLocation.cghidEventTap)
            deleteKeyUp?.post(tap: CGEventTapLocation.cghidEventTap)
        }
    }

    private func scheduleReplacementFailsafe(replacementID: UUID, commandText: String) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 65) {
            guard self.activeReplacementID == replacementID else {
                return
            }

            NSSound.beep()
            self.insertResponse(commandText)
            self.activeReplacementID = nil
            self.isReplacingText = false
            self.isLoading = false
            print("SucceedAI timed out before the AI service returned a response.")
        }
    }

    private func insertResponse(_ response: String) {
        guard !response.isEmpty else { return }

        let pasteboard = NSPasteboard.general
        let snapshot = PasteboardSnapshot(pasteboard: pasteboard)

        pasteboard.clearContents()
        pasteboard.setString(response, forType: .string)
        let responseChangeCount = pasteboard.changeCount

        pasteFromClipboard()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
            guard pasteboard.changeCount == responseChangeCount else { return }
            snapshot.restore(to: pasteboard)
        }
    }

    private func pasteFromClipboard() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyDownEvent = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true)
        let keyUpEvent = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)
        keyDownEvent?.flags = .maskCommand
        keyUpEvent?.flags = .maskCommand
        keyDownEvent?.post(tap: .cghidEventTap)
        keyUpEvent?.post(tap: .cghidEventTap)
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

private struct PasteboardSnapshot {
    private let items: [[NSPasteboard.PasteboardType: Data]]

    init(pasteboard: NSPasteboard) {
        items = pasteboard.pasteboardItems?.map { item in
            var itemData: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    itemData[type] = data
                }
            }
            return itemData
        } ?? []
    }

    func restore(to pasteboard: NSPasteboard) {
        pasteboard.clearContents()

        let pasteboardItems = items.map { itemData in
            let item = NSPasteboardItem()
            for (type, data) in itemData {
                item.setData(data, forType: type)
            }
            return item
        }

        if !pasteboardItems.isEmpty {
            pasteboard.writeObjects(pasteboardItems)
        }
    }
}
