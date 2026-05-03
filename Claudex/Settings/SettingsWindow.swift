import AppKit
import SwiftUI

/// Standalone Settings window with the General / Notifications / About tabs.
/// Distinct from the first-launch onboarding wizard — this is the long-lived
/// configuration surface accessible from the popover's "Settings" button.
@MainActor
final class SettingsWindow {
    private static var current: SettingsWindow?

    private let window: NSWindow

    static func show() {
        if let existing = current {
            existing.bringToFront()
            return
        }
        let instance = SettingsWindow()
        instance.present()
        current = instance
    }

    private init() {
        let view = SettingsRootView()
        let host = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: host)
        window.title = "Claudex Settings"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 560, height: 620))
        window.isReleasedWhenClosed = false
        window.center()
        self.window = window

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowWillClose(_:)),
            name: NSWindow.willCloseNotification,
            object: window
        )
    }

    private func present() {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func bringToFront() {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    @objc private func windowWillClose(_ notification: Notification) {
        NotificationCenter.default.removeObserver(self)
        SettingsWindow.current = nil
    }
}

private struct SettingsRootView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gearshape") }
            NotificationsSettingsView()
                .tabItem { Label("Notifications", systemImage: "bell") }
            AboutSettingsView()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .padding(20)
        .frame(width: 560, height: 620)
    }
}
