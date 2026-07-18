import AppKit
import ApplicationServices
import Carbon.HIToolbox
import Combine

struct TextCommandContext: Equatable {
    let commandText: String
    let utf16Range: NSRange

    static func find(
        in text: String,
        selectionRange: NSRange,
        trigger: String,
        expectedCommandText: String?,
        expectedCommandAnchorText: String? = nil
    ) -> TextCommandContext? {
        let nsText = text as NSString
        guard !trigger.isEmpty,
              selectionRange.location != NSNotFound,
              selectionRange.length == 0,
              selectionRange.location <= nsText.length else { return nil }

        if let expectedCommandText,
           expectedCommandText.hasPrefix(trigger) {
            let expectedLength = (expectedCommandText as NSString).length
            if expectedLength <= selectionRange.location {
                let expectedRange = NSRange(
                    location: selectionRange.location - expectedLength,
                    length: expectedLength
                )
                if nsText.substring(with: expectedRange) == expectedCommandText {
                    return TextCommandContext(
                        commandText: expectedCommandText,
                        utf16Range: expectedRange
                    )
                }
            }
        }

        if let expectedCommandAnchorText,
           expectedCommandAnchorText.hasPrefix(trigger),
           !expectedCommandAnchorText.isEmpty {
            let anchorRange = nsText.range(
                of: expectedCommandAnchorText,
                options: .backwards,
                range: NSRange(location: 0, length: selectionRange.location)
            )
            if anchorRange.location != NSNotFound {
                let commandRange = NSRange(
                    location: anchorRange.location,
                    length: selectionRange.location - anchorRange.location
                )
                let commandText = nsText.substring(with: commandRange)
                if commandText.hasPrefix(trigger) {
                    return TextCommandContext(commandText: commandText, utf16Range: commandRange)
                }
            }
        }

        let maximumSearchLength = 20_000
        let searchStart = max(0, selectionRange.location - maximumSearchLength)
        let searchRange = NSRange(
            location: searchStart,
            length: selectionRange.location - searchStart
        )
        let triggerRange = nsText.range(of: trigger, options: .backwards, range: searchRange)
        guard triggerRange.location != NSNotFound else { return nil }

        let commandRange = NSRange(
            location: triggerRange.location,
            length: selectionRange.location - triggerRange.location
        )
        let commandText = nsText.substring(with: commandRange)
        guard commandText.hasPrefix(trigger) else { return nil }
        return TextCommandContext(commandText: commandText, utf16Range: commandRange)
    }
}

struct TextSelectionContext: Equatable {
    static let maximumUTF16Length = 20_000

    let selectedText: String
    let utf16Range: NSRange

    static func find(in text: String, selectionRange: NSRange) -> TextSelectionContext? {
        let nsText = text as NSString
        guard selectionRange.location != NSNotFound,
              selectionRange.location >= 0,
              selectionRange.length > 0,
              selectionRange.length <= maximumUTF16Length,
              NSMaxRange(selectionRange) <= nsText.length else { return nil }

        let selectedText = nsText.substring(with: selectionRange)
        guard !selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return TextSelectionContext(selectedText: selectedText, utf16Range: selectionRange)
    }

    func replacementPreservingBoundaryWhitespace(_ response: String) -> String {
        let leadingWhitespace = selectedText.prefix(while: \.isWhitespace)
        let trailingWhitespace = selectedText.reversed().prefix(while: \.isWhitespace).reversed()
        let finishedText = response.trimmingCharacters(in: .whitespacesAndNewlines)
        return String(leadingWhitespace) + finishedText + String(trailingWhitespace)
    }
}

struct AutomationPermissionState: Equatable {
    let canListen: Bool
    let canInsert: Bool

    var isComplete: Bool { canListen && canInsert }

    static var current: AutomationPermissionState {
        AutomationPermissionState(
            canListen: CGPreflightListenEventAccess(),
            canInsert: CGPreflightPostEventAccess()
        )
    }
}

final class GlobalKeystrokeManager {
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    private(set) var isMonitoring = false

    private var currentTypedString = ""
    private var isCommandActive = false
    private var commandBufferIsReliable = true
    private var commandAnchorText: String?
    private let aiProvider: AIProvideable
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isReplacingText = false
    private var activeReplacementID: UUID?
    private var activeGenerationTask: Task<Void, Never>?
    private var sourceApplicationProcessIdentifier: pid_t?
    private var sourceTextSnapshot: FocusedTextSnapshot?
    private var replacementWasInterrupted = false
    private var isPostingReplacementEvents = false
    private var lastExternalApplicationProcessIdentifier: pid_t?
    private var workspaceActivationObserver: NSObjectProtocol?

    private var keystrokePrefixTrigger: String { UserSettings.commandTrigger() }
    var permissionState: AutomationPermissionState { .current }

    init(aiProvider: AIProvideable) {
        self.aiProvider = aiProvider
        rememberExternalApplication(NSWorkspace.shared.frontmostApplication)
        workspaceActivationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                as? NSRunningApplication
            self?.rememberExternalApplication(application)
        }
    }

    deinit {
        if let workspaceActivationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(workspaceActivationObserver)
        }
        stopMonitoring()
    }

    func captureFocusedSelection() -> FocusedSelectionSnapshot? {
        rememberExternalApplication(NSWorkspace.shared.frontmostApplication)
        if let processIdentifier = lastExternalApplicationProcessIdentifier,
           let snapshot = FocusedSelectionSnapshot.capture(
               processIdentifier: processIdentifier
           ) {
            return snapshot
        }
        return FocusedSelectionSnapshot.capture()
    }

    func requestPermissions() -> AutomationPermissionState {
        if !CGPreflightListenEventAccess() {
            _ = CGRequestListenEventAccess()
        }
        if !CGPreflightPostEventAccess() {
            _ = CGRequestPostEventAccess()
        }
        return .current
    }

    @discardableResult
    func startMonitoring() -> Bool {
        if eventTap != nil {
            isMonitoring = true
            return true
        }

        guard permissionState.isComplete else {
            isMonitoring = false
            return false
        }

        let eventMask = [
            CGEventType.keyDown,
            .leftMouseDown,
            .rightMouseDown,
            .otherMouseDown,
        ].reduce(CGEventMask(0)) { mask, eventType in
            mask | CGEventMask(1 << eventType.rawValue)
        }
        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard let userInfo else { return Unmanaged.passUnretained(event) }
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
            isMonitoring = false
            return false
        }

        guard let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0) else {
            CFMachPortInvalidate(eventTap)
            isMonitoring = false
            return false
        }

        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        self.eventTap = eventTap
        self.runLoopSource = runLoopSource
        isMonitoring = true
        return true
    }

    private func handleEventTap(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap { CGEvent.tapEnable(tap: eventTap, enable: true) }
            return Unmanaged.passUnretained(event)
        }

        if isReplacingText {
            if !isPostingReplacementEvents && Self.isInteractionEvent(type) {
                replacementWasInterrupted = true
                activeGenerationTask?.cancel()
                errorMessage = "Generation stopped because you continued working. Your original command is unchanged."
                finishReplacement()
            }
            return Unmanaged.passUnretained(event)
        }

        if Self.isMouseEvent(type) {
            resetCommandState()
            return Unmanaged.passUnretained(event)
        }

        guard type == .keyDown, let nsEvent = NSEvent(cgEvent: event) else {
            return Unmanaged.passUnretained(event)
        }

        if nsEvent.keyCode == kVK_Return {
            let bufferedCommand = commandBufferIsReliable ? currentTypedString : nil
            let didProcessCommand = processQuery(bufferedCommandText: bufferedCommand)
            resetCommandState()
            return didProcessCommand ? nil : Unmanaged.passUnretained(event)
        }

        if nsEvent.keyCode == kVK_Escape {
            resetCommandState()
            return Unmanaged.passUnretained(event)
        }

        if nsEvent.keyCode == kVK_Delete && isCommandActive {
            if commandBufferIsReliable && !currentTypedString.isEmpty {
                currentTypedString.removeLast()
                isCommandActive = currentTypedString.hasPrefix(keystrokePrefixTrigger)
            }
            return Unmanaged.passUnretained(event)
        }

        if nsEvent.modifierFlags.contains(.command) {
            if isCommandActive && nsEvent.keyCode == kVK_ANSI_V {
                appendPastedTextToCommandBuffer()
            } else if isCommandActive {
                commandBufferIsReliable = false
            }
            return Unmanaged.passUnretained(event)
        }

        if isCommandActive && Self.isNavigationKey(nsEvent.keyCode) {
            commandBufferIsReliable = false
            return Unmanaged.passUnretained(event)
        }

        let ignoredModifiers: NSEvent.ModifierFlags = [.control, .option]
        guard nsEvent.modifierFlags.intersection(ignoredModifiers).isEmpty,
              let characters = nsEvent.characters,
              !characters.isEmpty else {
            if isCommandActive { commandBufferIsReliable = false }
            return Unmanaged.passUnretained(event)
        }

        trackTypedCharacters(characters)
        return Unmanaged.passUnretained(event)
    }

    private func trackTypedCharacters(_ characters: String) {
        currentTypedString += characters
        if currentTypedString.utf16.count > 20_000 {
            currentTypedString = String(currentTypedString.prefix(20_000))
            commandBufferIsReliable = false
        }

        if isCommandActive {
            return
        } else if currentTypedString.hasPrefix(keystrokePrefixTrigger) {
            isCommandActive = true
        } else if keystrokePrefixTrigger.hasPrefix(currentTypedString) {
            isCommandActive = false
        } else if characters == String(keystrokePrefixTrigger.prefix(1)) {
            currentTypedString = characters
            isCommandActive = false
        } else {
            resetCommandState()
        }
    }

    private func processQuery(bufferedCommandText: String?) -> Bool {
        let trigger = keystrokePrefixTrigger
        guard isCommandActive else { return false }

        let snapshot = FocusedTextSnapshot.capture(
            trigger: trigger,
            expectedCommandText: bufferedCommandText,
            expectedCommandAnchorText: commandAnchorText
        )
        guard let commandText = snapshot?.commandContext.commandText ?? bufferedCommandText,
              commandText.hasPrefix(trigger) else { return false }
        let query = String(commandText.dropFirst(trigger.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return false }

        let replacementID = UUID()
        activeReplacementID = replacementID
        isReplacingText = true
        sourceApplicationProcessIdentifier = NSWorkspace.shared.frontmostApplication?.processIdentifier
        sourceTextSnapshot = snapshot
        replacementWasInterrupted = false
        isPostingReplacementEvents = false
        errorMessage = nil
        DispatchQueue.main.async { self.isLoading = true }
        scheduleReplacementFailsafe(replacementID: replacementID)

        activeGenerationTask = aiProvider.query(query) { result in
            DispatchQueue.main.async {
                guard self.activeReplacementID == replacementID else { return }
                switch result {
                case .success(let response):
                    guard self.canSafelyApplyReplacement else {
                        NSSound.beep()
                        self.errorMessage = "Nothing was changed because you switched apps or continued typing. Run the command again when you are ready."
                        self.finishReplacement()
                        return
                    }
                    self.applyReplacement(commandText: commandText, response: response, replacementID: replacementID)
                    return
                case .failure(let error):
                    NSSound.beep()
                    self.errorMessage = error.userMessage
                }
                self.finishReplacement()
            }
        }
        return true
    }

    private func resetCommandState() {
        isCommandActive = false
        currentTypedString = ""
        commandBufferIsReliable = true
        commandAnchorText = nil
    }

    private func removeUserInput(replacing commandText: String) {
        let source = CGEventSource(stateID: .combinedSessionState)
        for _ in commandText {
            CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_Delete), keyDown: true)?.post(tap: .cghidEventTap)
            CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_Delete), keyDown: false)?.post(tap: .cghidEventTap)
        }
    }

    private func applyReplacement(commandText: String, response: String, replacementID: UUID) {
        if let sourceTextSnapshot, sourceTextSnapshot.replaceCommand(with: response) {
            finishReplacement()
            return
        }

        isPostingReplacementEvents = true
        removeUserInput(replacing: commandText)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            guard self.activeReplacementID == replacementID else { return }
            self.insertResponse(response)
            self.finishReplacement()
        }
    }

    private func scheduleReplacementFailsafe(replacementID: UUID) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 35) {
            guard self.activeReplacementID == replacementID else { return }
            self.activeGenerationTask?.cancel()
            NSSound.beep()
            self.errorMessage = "Local generation timed out. Your original command was left untouched."
            self.finishReplacement()
        }
    }

    private func finishReplacement() {
        activeReplacementID = nil
        activeGenerationTask = nil
        isReplacingText = false
        sourceApplicationProcessIdentifier = nil
        sourceTextSnapshot = nil
        replacementWasInterrupted = false
        isPostingReplacementEvents = false
        isLoading = false
    }

    private var canSafelyApplyReplacement: Bool {
        guard Self.shouldApplyReplacement(
            sourceProcessIdentifier: sourceApplicationProcessIdentifier,
            currentProcessIdentifier: NSWorkspace.shared.frontmostApplication?.processIdentifier,
            wasInterrupted: replacementWasInterrupted
        ) else { return false }
        return sourceTextSnapshot?.isStillValid() ?? true
    }

    static func shouldApplyReplacement(
        sourceProcessIdentifier: pid_t?,
        currentProcessIdentifier: pid_t?,
        wasInterrupted: Bool
    ) -> Bool {
        guard !wasInterrupted,
              let sourceProcessIdentifier,
              let currentProcessIdentifier else { return false }
        return sourceProcessIdentifier == currentProcessIdentifier
    }

    private static func isInteractionEvent(_ type: CGEventType) -> Bool {
        switch type {
        case .keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown:
            return true
        default:
            return false
        }
    }

    private static func isMouseEvent(_ type: CGEventType) -> Bool {
        switch type {
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            return true
        default:
            return false
        }
    }

    private static func isNavigationKey(_ keyCode: UInt16) -> Bool {
        switch Int(keyCode) {
        case kVK_LeftArrow, kVK_RightArrow, kVK_UpArrow, kVK_DownArrow,
             kVK_Home, kVK_End, kVK_PageUp, kVK_PageDown:
            return true
        default:
            return false
        }
    }

    private func appendPastedTextToCommandBuffer() {
        guard commandBufferIsReliable,
              let pastedText = NSPasteboard.general.string(forType: .string) else {
            commandBufferIsReliable = false
            return
        }
        let combinedLength = currentTypedString.utf16.count + pastedText.utf16.count
        guard combinedLength <= 20_000 else {
            commandBufferIsReliable = false
            return
        }
        if commandAnchorText == nil {
            commandAnchorText = currentTypedString
        }
        currentTypedString += pastedText
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
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }

    private func stopMonitoring() {
        activeGenerationTask?.cancel()
        activeGenerationTask = nil
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            self.runLoopSource = nil
        }
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
            self.eventTap = nil
        }
        isMonitoring = false
    }

    private func rememberExternalApplication(_ application: NSRunningApplication?) {
        guard let application,
              application.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            return
        }
        lastExternalApplicationProcessIdentifier = application.processIdentifier
    }
}

private struct FocusedTextSnapshot {
    let element: AXUIElement
    let documentUTF16Length: Int
    let documentHashValue: Int
    let selectionRange: NSRange
    let commandContext: TextCommandContext

    static func capture(
        trigger: String,
        expectedCommandText: String?,
        expectedCommandAnchorText: String?
    ) -> FocusedTextSnapshot? {
        guard let element = focusedElement(),
              let documentText = textValue(of: element),
              let selectionRange = selectedTextRange(of: element),
              let commandContext = TextCommandContext.find(
                  in: documentText,
                  selectionRange: selectionRange,
                  trigger: trigger,
                  expectedCommandText: expectedCommandText,
                  expectedCommandAnchorText: expectedCommandAnchorText
              ) else { return nil }

        return FocusedTextSnapshot(
            element: element,
            documentUTF16Length: (documentText as NSString).length,
            documentHashValue: documentText.hashValue,
            selectionRange: selectionRange,
            commandContext: commandContext
        )
    }

    func isStillValid() -> Bool {
        guard let currentElement = Self.focusedElement(),
              CFEqual(currentElement, element),
              let currentText = Self.textValue(of: currentElement),
              (currentText as NSString).length == documentUTF16Length,
              currentText.hashValue == documentHashValue,
              Self.commandText(
                  in: currentText,
                  range: commandContext.utf16Range
              ) == commandContext.commandText,
              Self.selectedTextRange(of: currentElement) == selectionRange else { return false }
        return true
    }

    func replaceCommand(with response: String) -> Bool {
        guard !response.isEmpty, isStillValid() else { return false }

        var commandRange = CFRange(
            location: commandContext.utf16Range.location,
            length: commandContext.utf16Range.length
        )
        guard let commandRangeValue = AXValueCreate(.cfRange, &commandRange) else { return false }

        let selectionError = AXUIElementSetAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            commandRangeValue
        )
        guard selectionError == .success else { return false }

        let replacementError = AXUIElementSetAttributeValue(
            element,
            kAXSelectedTextAttribute as CFString,
            response as CFString
        )
        if replacementError == .success {
            return true
        }

        var originalRange = CFRange(
            location: selectionRange.location,
            length: selectionRange.length
        )
        if let originalRangeValue = AXValueCreate(.cfRange, &originalRange) {
            AXUIElementSetAttributeValue(
                element,
                kAXSelectedTextRangeAttribute as CFString,
                originalRangeValue
            )
        }
        return false
    }

    private static func focusedElement() -> AXUIElement? {
        let systemWideElement = AXUIElementCreateSystemWide()
        var rawElement: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            systemWideElement,
            kAXFocusedUIElementAttribute as CFString,
            &rawElement
        ) == .success,
        let rawElement,
        CFGetTypeID(rawElement) == AXUIElementGetTypeID() else { return nil }
        return (rawElement as! AXUIElement)
    }

    private static func textValue(of element: AXUIElement) -> String? {
        var rawValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            kAXValueAttribute as CFString,
            &rawValue
        ) == .success,
        let rawValue else { return nil }
        if let string = rawValue as? String { return string }
        if let attributedString = rawValue as? NSAttributedString { return attributedString.string }
        return nil
    }

    private static func selectedTextRange(of element: AXUIElement) -> NSRange? {
        var rawRange: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            &rawRange
        ) == .success,
        let rawRange,
        CFGetTypeID(rawRange) == AXValueGetTypeID() else { return nil }

        let rangeValue = rawRange as! AXValue
        guard AXValueGetType(rangeValue) == .cfRange else { return nil }
        var range = CFRange()
        guard AXValueGetValue(rangeValue, .cfRange, &range),
              range.location >= 0,
              range.length >= 0 else { return nil }
        return NSRange(location: range.location, length: range.length)
    }

    private static func commandText(in documentText: String, range: NSRange) -> String? {
        let nsText = documentText as NSString
        guard range.location != NSNotFound,
              range.location >= 0,
              range.length >= 0,
              NSMaxRange(range) <= nsText.length else { return nil }
        return nsText.substring(with: range)
    }
}

struct FocusedSelectionSnapshot {
    let selectedText: String
    private let replacement: (String) -> Bool

    init(selectedText: String, replacement: @escaping (String) -> Bool) {
        self.selectedText = selectedText
        self.replacement = replacement
    }

    static func capture(processIdentifier: pid_t? = nil) -> FocusedSelectionSnapshot? {
        guard let context = AccessibilitySelectionContext.capture(
            processIdentifier: processIdentifier
        ) else { return nil }
        return FocusedSelectionSnapshot(selectedText: context.selection.selectedText) {
            context.replaceSelection(with: $0)
        }
    }

    func replaceSelection(with response: String) -> Bool {
        replacement(response)
    }
}

private struct AccessibilitySelectionContext {
    let element: AXUIElement
    let sourceProcessIdentifier: pid_t
    let documentUTF16Length: Int
    let documentHashValue: Int
    let selection: TextSelectionContext

    static func capture(processIdentifier: pid_t?) -> AccessibilitySelectionContext? {
        guard let element = focusedElement(processIdentifier: processIdentifier),
              let documentText = textValue(of: element),
              let selectionRange = selectedTextRange(of: element),
              let selection = TextSelectionContext.find(
                  in: documentText,
                  selectionRange: selectionRange
              ) else { return nil }

        var processIdentifier = pid_t()
        guard AXUIElementGetPid(element, &processIdentifier) == .success else { return nil }
        return AccessibilitySelectionContext(
            element: element,
            sourceProcessIdentifier: processIdentifier,
            documentUTF16Length: (documentText as NSString).length,
            documentHashValue: documentText.hashValue,
            selection: selection
        )
    }

    func replaceSelection(with response: String) -> Bool {
        let replacement = selection.replacementPreservingBoundaryWhitespace(response)
        guard !replacement.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              isStillValid() else { return false }

        var selectionRange = CFRange(
            location: selection.utf16Range.location,
            length: selection.utf16Range.length
        )
        guard let selectionRangeValue = AXValueCreate(.cfRange, &selectionRange),
              AXUIElementSetAttributeValue(
                  element,
                  kAXSelectedTextRangeAttribute as CFString,
                  selectionRangeValue
              ) == .success else { return false }

        return AXUIElementSetAttributeValue(
            element,
            kAXSelectedTextAttribute as CFString,
            replacement as CFString
        ) == .success
    }

    private func isStillValid() -> Bool {
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == sourceProcessIdentifier,
              let currentElement = Self.focusedElement(
                  processIdentifier: sourceProcessIdentifier
              ),
              CFEqual(currentElement, element),
              let currentText = Self.textValue(of: currentElement),
              (currentText as NSString).length == documentUTF16Length,
              currentText.hashValue == documentHashValue,
              Self.selectedTextRange(of: currentElement) == selection.utf16Range,
              TextSelectionContext.find(
                  in: currentText,
                  selectionRange: selection.utf16Range
              ) == selection else { return false }
        return true
    }

    private static func focusedElement(processIdentifier: pid_t?) -> AXUIElement? {
        let applicationElement = processIdentifier.map(AXUIElementCreateApplication)
            ?? AXUIElementCreateSystemWide()
        var rawElement: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            applicationElement,
            kAXFocusedUIElementAttribute as CFString,
            &rawElement
        ) == .success,
        let rawElement,
        CFGetTypeID(rawElement) == AXUIElementGetTypeID() else { return nil }
        return (rawElement as! AXUIElement)
    }

    private static func textValue(of element: AXUIElement) -> String? {
        var rawValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            kAXValueAttribute as CFString,
            &rawValue
        ) == .success,
        let rawValue else { return nil }
        if let string = rawValue as? String { return string }
        if let attributedString = rawValue as? NSAttributedString { return attributedString.string }
        return nil
    }

    private static func selectedTextRange(of element: AXUIElement) -> NSRange? {
        var rawRange: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            &rawRange
        ) == .success,
        let rawRange,
        CFGetTypeID(rawRange) == AXValueGetTypeID() else { return nil }

        let rangeValue = rawRange as! AXValue
        guard AXValueGetType(rangeValue) == .cfRange else { return nil }
        var range = CFRange()
        guard AXValueGetValue(rangeValue, .cfRange, &range),
              range.location >= 0,
              range.length >= 0 else { return nil }
        return NSRange(location: range.location, length: range.length)
    }
}

private struct PasteboardSnapshot {
    private let items: [[NSPasteboard.PasteboardType: Data]]

    init(pasteboard: NSPasteboard) {
        items = pasteboard.pasteboardItems?.map { item in
            Dictionary(uniqueKeysWithValues: item.types.compactMap { type in
                item.data(forType: type).map { (type, $0) }
            })
        } ?? []
    }

    func restore(to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        let pasteboardItems = items.map { itemData in
            let item = NSPasteboardItem()
            for (type, data) in itemData { item.setData(data, forType: type) }
            return item
        }
        if !pasteboardItems.isEmpty { pasteboard.writeObjects(pasteboardItems) }
    }
}
