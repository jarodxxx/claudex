import Foundation

enum AppSettings {
    private static let defaults = UserDefaults.standard

    enum Key {
        static let rtkBinaryPath = "rtkBinaryPath"
        static let memPalaceBinaryPath = "memPalaceBinaryPath"
        static let refreshIntervalSeconds = "refreshIntervalSeconds"
        static let onboardingCompleted = "onboardingCompleted"
        static let claudeOrgUUID = "claudeOrgUUID"
        static let iconStyle = "iconStyle"
        static let showSonnet = "showSonnet"
        static let notificationsEnabled = "notificationsEnabled"
        static let warningThreshold = "warningThreshold"
        static let criticalThreshold = "criticalThreshold"
        static let notifyOnSessionReset = "notifyOnSessionReset"
    }

    static var rtkBinaryPath: String? {
        get { defaults.string(forKey: Key.rtkBinaryPath) }
        set { defaults.set(newValue, forKey: Key.rtkBinaryPath) }
    }

    static var memPalaceBinaryPath: String? {
        get { defaults.string(forKey: Key.memPalaceBinaryPath) }
        set { defaults.set(newValue, forKey: Key.memPalaceBinaryPath) }
    }

    static var refreshIntervalSeconds: TimeInterval {
        get {
            let value = defaults.double(forKey: Key.refreshIntervalSeconds)
            return value > 0 ? value : 300
        }
        set { defaults.set(newValue, forKey: Key.refreshIntervalSeconds) }
    }

    static var onboardingCompleted: Bool {
        get { defaults.bool(forKey: Key.onboardingCompleted) }
        set { defaults.set(newValue, forKey: Key.onboardingCompleted) }
    }

    /// Cached Claude organization UUID — avoids re-fetching `/organizations`
    /// on every refresh. Cleared on sign-out.
    static var claudeOrgUUID: String? {
        get { defaults.string(forKey: Key.claudeOrgUUID) }
        set { defaults.set(newValue, forKey: Key.claudeOrgUUID) }
    }

    static var iconStyle: IconStyle {
        get {
            guard let raw = defaults.string(forKey: Key.iconStyle),
                  let style = IconStyle(rawValue: raw) else {
                return .gauge
            }
            return style
        }
        set { defaults.set(newValue.rawValue, forKey: Key.iconStyle) }
    }

    static var showSonnet: Bool {
        get {
            if defaults.object(forKey: Key.showSonnet) == nil { return true }
            return defaults.bool(forKey: Key.showSonnet)
        }
        set { defaults.set(newValue, forKey: Key.showSonnet) }
    }

    static var notificationsEnabled: Bool {
        get {
            if defaults.object(forKey: Key.notificationsEnabled) == nil { return true }
            return defaults.bool(forKey: Key.notificationsEnabled)
        }
        set { defaults.set(newValue, forKey: Key.notificationsEnabled) }
    }

    static var warningThreshold: Double {
        get {
            let v = defaults.double(forKey: Key.warningThreshold)
            return v > 0 ? v : 75
        }
        set { defaults.set(newValue, forKey: Key.warningThreshold) }
    }

    static var criticalThreshold: Double {
        get {
            let v = defaults.double(forKey: Key.criticalThreshold)
            return v > 0 ? v : 90
        }
        set { defaults.set(newValue, forKey: Key.criticalThreshold) }
    }

    static var notifyOnSessionReset: Bool {
        get {
            if defaults.object(forKey: Key.notifyOnSessionReset) == nil { return true }
            return defaults.bool(forKey: Key.notifyOnSessionReset)
        }
        set { defaults.set(newValue, forKey: Key.notifyOnSessionReset) }
    }
}

extension Notification.Name {
    /// Posted when settings change in a way that should trigger an immediate
    /// refresh (Claude sign-in/out, RTK/MemPalace path change, …).
    static let claudexShouldRefresh = Notification.Name("claudex.shouldRefresh")
    /// Posted when the menu bar icon style changes.
    static let claudexIconStyleChanged = Notification.Name("claudex.iconStyleChanged")
}
