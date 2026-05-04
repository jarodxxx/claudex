import SwiftUI
import AppKit

struct DropdownView: View {
    @ObservedObject var aggregator: StatsAggregator
    let openSettings: () -> Void
    let onRefresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Claudex").font(.headline)
                Spacer()
                Button(action: onRefresh) {
                    if aggregator.isRefreshing {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .buttonStyle(.borderless)
                .disabled(aggregator.isRefreshing)
                .help("Refresh now")
            }

            Divider()

            ClaudeSection(result: aggregator.stats.claude, showSonnet: AppSettings.showSonnet)
            Divider()
            RTKSection(result: aggregator.stats.rtk)
            Divider()
            MemPalaceSection(result: aggregator.stats.memPalace)

            Spacer(minLength: 8)

            HStack(spacing: 8) {
                ToolbarButton(systemImage: "gearshape", title: "Settings", action: openSettings)
                Spacer()
                ToolbarButton(systemImage: "power", title: "Quit") { NSApp.terminate(nil) }
            }
        }
        .padding(16)
        .frame(width: 360)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

private struct ToolbarButton: View {
    let systemImage: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .labelStyle(.titleAndIcon)
                .font(.caption)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }
}

private struct ClaudeSection: View {
    let result: Result<ClaudeUsage, Error>?
    let showSonnet: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Claude", systemImage: "brain.head.profile")
                    .font(.subheadline.bold())
                Spacer()
                Button {
                    if let url = URL(string: "https://claude.ai") { NSWorkspace.shared.open(url) }
                } label: {
                    Image(systemName: "arrow.up.right.square")
                }
                .buttonStyle(.borderless)
                .help("Open claude.ai in your browser")
            }

            switch result {
            case .none:
                Text("Not configured").foregroundStyle(.secondary).font(.caption)
            case .failure(let error):
                Text("Error: \(String(describing: error))").foregroundStyle(.red).font(.caption)
            case .success(let usage):
                ClaudeUsageRow(label: "Session", period: usage.sessionUsage)
                if showSonnet, let sonnet = usage.sonnetUsage {
                    ClaudeUsageRow(label: "Sonnet", period: sonnet)
                }
                ClaudeUsageRow(label: "Weekly", period: usage.weeklyUsage)
            }
        }
    }
}

private struct ClaudeUsageRow: View {
    let label: String
    let period: PeriodUsage

    private static let labelWidth: CGFloat = 56
    private static let percentWidth: CGFloat = 40

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(label)
                .frame(width: Self.labelWidth, alignment: .leading)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    UsageBar(
                        percent: period.utilization,
                        color: UsageColor.forUsage(period.utilization)
                    )
                    Text("\(Int(period.utilization.rounded()))%")
                        .frame(width: Self.percentWidth, alignment: .trailing)
                        .monospacedDigit()
                }
                Text("Resets \(relativeReset(period.resetAt))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .font(.caption)
    }

    private func relativeReset(_ date: Date) -> String {
        let delta = date.timeIntervalSinceNow

        // Already past: about to reset
        if delta < 60 { return "imminent" }

        // Under 2 hours: precise "1h 24min" / "47min" so the user knows
        // exactly how much they have left.
        if delta < 2 * 3600 {
            let totalMinutes = Int(delta / 60)
            let hours = totalMinutes / 60
            let minutes = totalMinutes % 60
            if hours > 0 {
                return minutes == 0 ? "in \(hours)h" : "in \(hours)h \(minutes)min"
            }
            return "in \(minutes)min"
        }

        // 2 hours or more: locale-aware relative format ("in 4 hr", "in 2 days")
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

/// Custom progress bar — `ProgressView(.linear).tint(...)` is silently ignored
/// on macOS so we render the bar ourselves to guarantee the color.
private struct UsageBar: View {
    let percent: Double
    let color: Color

    var body: some View {
        Capsule()
            .fill(Color.gray.opacity(0.18))
            .frame(height: 6)
            .overlay(alignment: .leading) {
                GeometryReader { geo in
                    Capsule()
                        .fill(color)
                        .frame(
                            width: geo.size.width * CGFloat(min(max(percent, 0), 100)) / 100,
                            height: 6
                        )
                }
            }
    }
}

/// Single source of truth for the green/orange/red mapping. Shared between
/// the menu bar icon (`StatusBarIcon`) and the popover bars so a 55 % quota
/// looks the same color in both places.
enum UsageColor {
    /// "Higher = worse" — used for Claude quotas.
    static func forUsage(_ percent: Double) -> Color {
        switch percent {
        case ..<50:   return Color(NSColor.systemGreen)
        case 50..<90: return Color(NSColor.systemOrange)
        default:      return Color(NSColor.systemRed)
        }
    }

    /// "Higher = better" — used for RTK savings.
    static func forSavings(_ percent: Double) -> Color {
        switch percent {
        case ..<25:   return Color(NSColor.systemRed)
        case 25..<50: return Color(NSColor.systemOrange)
        default:      return Color(NSColor.systemGreen)
        }
    }
}

private struct RTKSection: View {
    let result: Result<RTKStats, Error>?
    @State private var isFetchingHistory = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("RTK", systemImage: "bolt.fill")
                    .font(.subheadline.bold())
                Spacer()
                Button {
                    fetchHistory()
                } label: {
                    if isFetchingHistory {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "list.bullet.rectangle")
                    }
                }
                .buttonStyle(.borderless)
                .disabled(AppSettings.rtkBinaryPath == nil || isFetchingHistory)
                .help("Show rtk gain --history output")
            }

            switch result {
            case .none:
                Text("Not detected").foregroundStyle(.secondary).font(.caption)
            case .failure(let error):
                Text("Error: \(String(describing: error))").foregroundStyle(.red).font(.caption)
            case .success(let stats):
                let pct = stats.summary.avgSavingsPct
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Savings")
                        Spacer()
                        Text(String(format: "%.1f%%", pct)).monospacedDigit()
                    }
                    .font(.caption)
                    UsageBar(percent: pct, color: UsageColor.forSavings(pct))
                }

                HStack(spacing: 16) {
                    statTile(
                        value: stats.summary.totalSaved.formatted(),
                        label: "tokens saved"
                    )
                    statTile(
                        value: stats.summary.totalCommands.formatted(),
                        label: "commands"
                    )
                }
                .font(.caption)
            }
        }
    }

    private func statTile(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value).font(.callout.bold()).monospacedDigit()
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func fetchHistory() {
        guard let path = AppSettings.rtkBinaryPath else { return }
        isFetchingHistory = true
        Task {
            let result = await CommandRunner.shared.runWithNotification(
                title: "RTK history",
                executable: path,
                arguments: ["gain", "--history"]
            )
            let body = result.succeeded ? result.stdout : result.stderr
            CommandOutputWindow.show(title: "RTK history", output: body)
            isFetchingHistory = false
        }
    }
}

private struct MemPalaceSection: View {
    let result: Result<MemPalaceStats, Error>?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("MemPalace", systemImage: "books.vertical.fill")
                .font(.subheadline.bold())

            switch result {
            case .none:
                Text("Not detected").foregroundStyle(.secondary).font(.caption)
            case .failure(let error):
                Text("Error: \(String(describing: error))").foregroundStyle(.red).font(.caption)
            case .success(let stats):
                Text("Total drawers: \(stats.totalDrawers.formatted())").font(.caption)
                if !stats.wings.isEmpty {
                    Text("Wings: \(stats.wings.count)").font(.caption).foregroundStyle(.secondary)
                    ForEach(stats.wings.prefix(5), id: \.name) { wing in
                        HStack {
                            Text("• \(wing.name)").foregroundStyle(.secondary)
                            Spacer()
                            Text("\(wing.totalDrawers.formatted())").monospacedDigit()
                        }
                        .font(.caption)
                    }
                }
            }
        }
    }
}
