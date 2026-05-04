import Foundation
import ServiceManagement

/// Wraps the modern `SMAppService.mainApp` API (macOS 13+) for "launch at
/// login" registration. macOS persists the user's choice across reboots — we
/// also mirror it in `UserDefaults.launchAtLogin` so the Settings toggle can
/// initialise without an extra system call.
enum LaunchAtLogin {
    /// True if the app is currently registered as a login item.
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Synchronise the system state with the desired flag. Returns true on
    /// success, false on failure (e.g. user denied via System Settings).
    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
            AppSettings.launchAtLogin = enabled
            return true
        } catch {
            NSLog("[Claudex] LaunchAtLogin.setEnabled(\(enabled)) failed: \(error)")
            return false
        }
    }
}
