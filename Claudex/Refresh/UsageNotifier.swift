import Foundation
import Combine

/// Watches the aggregator and posts macOS notifications when a Claude quota
/// crosses a configured threshold (warning / critical) or resets.
///
/// State is in-memory: at first launch we record the baseline and notify only
/// on subsequent threshold crossings, so the user isn't immediately spammed
/// if they were already at 95 % when starting Claudex.
@MainActor
final class UsageNotifier {
    private let aggregator: StatsAggregator
    private var cancellable: AnyCancellable?

    /// Last observed utilization per period — used to detect "crossed upward"
    /// transitions and quota resets.
    private var lastSession: Double?
    private var lastSonnet: Double?
    private var lastWeekly: Double?

    /// Set of (period, threshold) pairs we've already notified for in the
    /// current "uphill phase". Cleared when usage drops back below the
    /// threshold so the next climb re-arms the notification.
    private var armed: Set<String> = []

    init(aggregator: StatsAggregator) {
        self.aggregator = aggregator
    }

    func start() {
        cancellable = aggregator.$stats
            .receive(on: RunLoop.main)
            .sink { [weak self] stats in
                self?.handle(stats)
            }
    }

    func stop() {
        cancellable?.cancel()
        cancellable = nil
    }

    private func handle(_ stats: AggregatedStats) {
        guard AppSettings.notificationsEnabled else { return }
        guard case let .success(usage) = stats.claude else { return }

        check(period: "Session", current: usage.sessionUsage.utilization, last: &lastSession)
        if let sonnet = usage.sonnetUsage {
            check(period: "Sonnet", current: sonnet.utilization, last: &lastSonnet)
        }
        check(period: "Weekly", current: usage.weeklyUsage.utilization, last: &lastWeekly)
    }

    private func check(period: String, current: Double, last: inout Double?) {
        defer { last = current }

        // First observation: baseline only, no notification.
        guard let previous = last else { return }

        let warning = AppSettings.warningThreshold
        let critical = AppSettings.criticalThreshold

        // Crossed warning upward
        if current >= warning && previous < warning {
            postThresholdReached(period: period, percent: current, level: .warning)
        }

        // Crossed critical upward
        if current >= critical && previous < critical {
            postThresholdReached(period: period, percent: current, level: .critical)
        }

        // Reset detection: a large drop (>= 50pp) typically means the quota
        // window rolled over. Only notify if the user opted in.
        if AppSettings.notifyOnSessionReset && previous - current >= 50 {
            postReset(period: period, previous: previous)
            armed.remove("\(period)-warning")
            armed.remove("\(period)-critical")
        }

        // Re-arm thresholds once usage drops back below them so a future
        // climb triggers the notification again.
        if current < warning { armed.remove("\(period)-warning") }
        if current < critical { armed.remove("\(period)-critical") }
    }

    private enum Level { case warning, critical }

    private func postThresholdReached(period: String, percent: Double, level: Level) {
        let key = "\(period)-\(level == .warning ? "warning" : "critical")"
        guard !armed.contains(key) else { return }
        armed.insert(key)

        let title: String
        let body: String
        switch level {
        case .warning:
            title = "Claude \(period) usage warning"
            body = "You've reached \(Int(percent.rounded()))% of your \(period.lowercased()) quota."
        case .critical:
            title = "Claude \(period) usage critical"
            body = "Critical: \(Int(percent.rounded()))% of your \(period.lowercased()) quota used."
        }

        Task {
            await NotificationPresenter.shared.notify(title: title, body: body)
        }
    }

    private func postReset(period: String, previous: Double) {
        Task {
            await NotificationPresenter.shared.notify(
                title: "Claude \(period) quota reset",
                body: "Your \(period.lowercased()) usage was reset. Welcome back to a clean slate."
            )
        }
    }

    // MARK: - Test

    /// Sends a sample notification immediately and reports back what happened.
    /// Used by the Settings panel "Send Test Notification" button.
    static func sendTestNotification() async -> String {
        await NotificationPresenter.shared.diagnose(
            title: "Claudex test notification",
            body: "If you can read this, notifications are working."
        )
    }
}
