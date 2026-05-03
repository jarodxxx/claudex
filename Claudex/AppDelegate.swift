import AppKit
import Combine
import UserNotifications

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private var statusBarController: StatusBarController?
    private var refreshScheduler: RefreshScheduler?
    private var usageNotifier: UsageNotifier?
    private var onboardingWindow: OnboardingWindow?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Register as the notification center delegate so banners appear even
        // when Claudex is the foreground app (otherwise macOS silently drops
        // notifications from the active app).
        UNUserNotificationCenter.current().delegate = self

        let aggregator = StatsAggregator()
        statusBarController = StatusBarController(
            aggregator: aggregator,
            openSettings: { SettingsWindow.show() }
        )
        refreshScheduler = RefreshScheduler(aggregator: aggregator)
        usageNotifier = UsageNotifier(aggregator: aggregator)
        usageNotifier?.start()

        // Onboarding: shown once at first launch only. From there on the
        // long-lived configuration surface is the Settings window.
        if !AppSettings.onboardingCompleted {
            showOnboarding()
        } else {
            refreshScheduler?.start()
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .list])
    }

    func showOnboarding() {
        let window = OnboardingWindow { [weak self] in
            self?.onboardingWindow?.close()
            self?.onboardingWindow = nil
            self?.refreshScheduler?.start()
        }
        onboardingWindow = window
        window.show()
    }
}
