import Cocoa
import SwiftUI
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarItem: NSStatusItem?
    var viewModel: AppViewModel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Request notification permission
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("Notification permission granted.")
            } else if let error = error {
                print("Notification permission error: \(error)")
            }
        }

        // Initialize ViewModel and GlobalKeystrokeManager
        setupViewModel()
        setupGlobalKeystrokeManager()
        setupStatusBarItem()
    }
    
    private func setupViewModel() {
        let aiProvider = Config.apiServiceProvider.init(apiKey: Config.apiKey, apiUrl: Config.apiUrl)
        viewModel = AppViewModel(aiProvider: aiProvider)
    }

    private func setupGlobalKeystrokeManager() {
        viewModel?.initializeGlobalKeystrokeManager()
    }

    private func setupStatusBarItem() {
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusBarItem?.button {
            button.image = NSImage(systemSymbolName: Config.systemSymbolName, accessibilityDescription: Config.appTitle)
            button.action = #selector(statusBarButtonClicked(_:))
        }
    }

    @objc private func statusBarButtonClicked(_ sender: AnyObject?) {
        showStatusBarItemClickedNotification()
    }

    private func showStatusBarItemClickedNotification() {
        let content = UNMutableNotificationContent()
        content.title = Config.appTitle
        content.body = "The AI service is running. Use CMD+SHIFT+Enter to interact."
        content.sound = UNNotificationSound.default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            // Handle any error when scheduling the notification
        }
    }
}
