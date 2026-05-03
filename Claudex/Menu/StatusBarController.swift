import AppKit
import SwiftUI
import Combine

@MainActor
final class StatusBarController {
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private let aggregator: StatsAggregator
    private var cancellables = Set<AnyCancellable>()

    init(aggregator: StatsAggregator, openSettings: @escaping () -> Void) {
        self.aggregator = aggregator
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.popover = NSPopover()
        self.popover.behavior = .transient
        self.popover.appearance = NSAppearance(named: .aqua)
        self.popover.contentSize = NSSize(width: 360, height: 520)
        self.popover.contentViewController = NSHostingController(
            rootView: DropdownView(
                aggregator: aggregator,
                openSettings: openSettings,
                onRefresh: { Task { await aggregator.refresh() } }
            )
        )

        configureButton()
        observeAggregator()
        observeIconStyleChanges()
    }

    private func configureButton() {
        guard let button = statusItem.button else { return }
        renderIcon(percent: 0, status: .ok)
        button.imagePosition = .imageOnly
        button.target = self
        button.action = #selector(togglePopover(_:))
    }

    private func observeAggregator() {
        aggregator.$stats
            .receive(on: RunLoop.main)
            .sink { [weak self] stats in
                self?.updateIcon(with: stats)
            }
            .store(in: &cancellables)
    }

    private func observeIconStyleChanges() {
        NotificationCenter.default
            .publisher(for: .claudexIconStyleChanged)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.updateIcon(with: self.aggregator.stats)
            }
            .store(in: &cancellables)

        // Re-render whenever the user toggles between light/dark mode.
        DistributedNotificationCenter.default()
            .publisher(for: Notification.Name("AppleInterfaceThemeChangedNotification"))
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.updateIcon(with: self.aggregator.stats)
            }
            .store(in: &cancellables)
    }

    private func updateIcon(with stats: AggregatedStats) {
        let percent = Int(stats.maxUtilization.rounded())
        let status: UsageStatus
        switch stats.maxUtilization {
        case ..<75: status = .ok
        case 75..<90: status = .warning
        default: status = .critical
        }
        renderIcon(percent: percent, status: status)
    }

    private func renderIcon(percent: Int, status: UsageStatus) {
        statusItem.button?.image = StatusBarIcon.image(
            style: AppSettings.iconStyle,
            percent: percent,
            status: status
        )
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}
