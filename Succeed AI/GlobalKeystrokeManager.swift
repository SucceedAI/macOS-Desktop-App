import Foundation
import SwiftUI
import Carbon.HIToolbox
import AppKit
import CoreGraphics

class GlobalKeystrokeManager {
    // can be change by another unique keystroke event ID
    private var uniqueKeystrokeTrigger: String = "/ai "

    
    private var eventMonitor: Any?
    private let aiService: AIProvideable
    private var currentTypedString: String = ""

    init(aiService: AIProvideable) {
        self.aiService = aiService
        setupGlobalKeystrokeMonitoring()
    }

    private func setupGlobalKeystrokeMonitoring() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String : true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options)

        if !accessEnabled {
                Alert(
                    title: Text("Accessibility Permission Not Granted").font(.largeTitle),
                    message: Text("Accessibility permission needs to be granted. Allow the app in System Settings -> Privacy & Security -> -> Accessibility."),
                    dismissButton: .default(Text("OK"))
                )
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

        // Appending the typed character
        currentTypedString += characters

        // Check if it matches the unique keystroke pattern
        if currentTypedString.hasPrefix(uniqueKeystrokeTrigger) {
            let query = String(currentTypedString.dropFirst(4)) // Remove '/ai ' prefix
            aiService.sendQuery(query) { response in
                // Handle the response, e.g., show it in UI or use it in some way
                DispatchQueue.main.async {
                    // Example: print the response
                    print(response)
                }
            }
            currentTypedString = "" // Reset the typed string
        }

        // Reset if space or return key is pressed
        if event.keyCode == kVK_Space || event.keyCode == kVK_Return {
            currentTypedString = ""
        }
    }
}
