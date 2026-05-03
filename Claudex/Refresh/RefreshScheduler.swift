import Foundation
import Combine

@MainActor
final class RefreshScheduler {
    private let aggregator: StatsAggregator
    private var timerCancellable: AnyCancellable?
    private var notificationCancellable: AnyCancellable?

    init(aggregator: StatsAggregator) {
        self.aggregator = aggregator
        notificationCancellable = NotificationCenter.default
            .publisher(for: .claudexShouldRefresh)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.triggerRefresh() }
    }

    func start() {
        triggerRefresh()
        scheduleTimer()
    }

    func stop() {
        timerCancellable?.cancel()
        timerCancellable = nil
    }

    func triggerRefresh() {
        Task { await aggregator.refresh() }
    }

    private func scheduleTimer() {
        let interval = AppSettings.refreshIntervalSeconds
        timerCancellable = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.triggerRefresh()
            }
    }
}
