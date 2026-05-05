import SwiftUI
import AppKit

struct DropdownView: View {
    @ObservedObject var aggregator: StatsAggregator
    @ObservedObject var registry: ToolRegistry
    let openSettings: () -> Void
    let onRefresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
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

            // Tool sections — flat or categorised depending on total height
            if registry.shouldCategorize {
                categorisedContent
            } else {
                flatContent
            }

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

    // MARK: - Content layouts

    @ViewBuilder
    private var flatContent: some View {
        let sections = toolSections
        ForEach(Array(sections.enumerated()), id: \.offset) { idx, section in
            section
            if idx < sections.count - 1 { Divider() }
        }
    }

    @ViewBuilder
    private var categorisedContent: some View {
        let grouped = Dictionary(grouping: registry.enabled, by: \.category)
        let categories = ToolCategory.allCases.filter { grouped[$0] != nil }
        ForEach(Array(categories.enumerated()), id: \.element) { idx, cat in
            // Category header
            HStack {
                Image(systemName: cat.icon)
                Text(cat.rawValue.uppercased())
            }
            .font(.caption2.bold())
            .foregroundStyle(.secondary)
            .padding(.top, idx == 0 ? 0 : 6)

            // Tools in this category
            let tools = grouped[cat] ?? []
            ForEach(Array(tools.enumerated()), id: \.element.id) { i, tool in
                toolView(for: tool.id)
                if i < tools.count - 1 { Divider().padding(.leading, 8) }
            }
            if idx < categories.count - 1 { Divider() }
        }
    }

    // Each enabled tool → its view (only if result is non-nil)
    private var toolSections: [AnyView] {
        registry.enabled.compactMap { tool in
            let view = toolView(for: tool.id)
            return AnyView(view)
        }
    }

    @ViewBuilder
    private func toolView(for id: ToolID) -> some View {
        switch id {
        case .claude:
            // Always show when enabled — result nil = not yet fetched or not configured
            ClaudeSection(result: aggregator.stats.claude, showSonnet: AppSettings.showSonnet)
        case .rtk:
            // Hide only if no binary at all (never detected, user didn't configure)
            if aggregator.stats.rtk != nil || ServiceConfig.current.rtkBinaryPath != nil {
                RTKSection(result: aggregator.stats.rtk)
            }
        case .caveman:
            // Hide only if no sessions found (reader uses JSONL, no binary required)
            if aggregator.stats.caveman != nil {
                CavemanSection(result: aggregator.stats.caveman)
            }
        case .mempalace:
            if aggregator.stats.memPalace != nil || ServiceConfig.current.memPalaceBinaryPath != nil {
                MemPalaceSection(result: aggregator.stats.memPalace)
            }
        }
    }
}

// MARK: - Shared components

private struct ToolbarButton: View {
    let systemImage: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage).labelStyle(.titleAndIcon).font(.caption)
        }
        .buttonStyle(.bordered).controlSize(.small)
    }
}

// MARK: - Claude

private struct ClaudeSection: View {
    let result: Result<ClaudeUsage, Error>?
    let showSonnet: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Claude", systemImage: "brain.head.profile").font(.subheadline.bold())
                Spacer()
                Button {
                    if let url = URL(string: "https://claude.ai") { NSWorkspace.shared.open(url) }
                } label: { Image(systemName: "arrow.up.right.square") }
                .buttonStyle(.borderless).help("Open claude.ai")
            }
            switch result {
            case .none:
                Text("Not configured").foregroundStyle(.secondary).font(.caption)
            case .failure(let e):
                Text("Error: \(String(describing: e))").foregroundStyle(.red).font(.caption)
            case .success(let usage):
                ClaudeUsageRow(label: "Session", period: usage.sessionUsage)
                if showSonnet, let s = usage.sonnetUsage { ClaudeUsageRow(label: "Sonnet", period: s) }
                ClaudeUsageRow(label: "Weekly", period: usage.weeklyUsage)
            }
        }
    }
}

private struct ClaudeUsageRow: View {
    let label: String
    let period: PeriodUsage

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label).frame(width: 56, alignment: .leading).font(.caption)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    UsageBar(percent: period.utilization, color: UsageColor.forUsage(period.utilization))
                    Text("\(Int(period.utilization.rounded()))%")
                        .frame(width: 40, alignment: .trailing).monospacedDigit().font(.caption)
                }
                Text("Resets \(relativeReset(period.resetAt))")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private func relativeReset(_ date: Date) -> String {
        let delta = date.timeIntervalSinceNow
        if delta < 60 { return "imminent" }
        if delta < 2 * 3600 {
            let totalMinutes = Int(delta / 60)
            let h = totalMinutes / 60; let m = totalMinutes % 60
            if h > 0 { return m == 0 ? "in \(h)h" : "in \(h)h \(m)min" }
            return "in \(m)min"
        }
        let fmt = RelativeDateTimeFormatter(); fmt.unitsStyle = .abbreviated
        return fmt.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - RTK

private struct RTKSection: View {
    let result: Result<RTKStats, Error>?
    @State private var isFetchingHistory = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("RTK", systemImage: "bolt.fill").font(.subheadline.bold())
                Spacer()
                Button { fetchHistory() } label: {
                    if isFetchingHistory { ProgressView().controlSize(.small) }
                    else { Image(systemName: "list.bullet.rectangle") }
                }
                .buttonStyle(.borderless)
                .disabled(AppSettings.rtkBinaryPath == nil || isFetchingHistory)
                .help("Show rtk gain --history")
            }
            switch result {
            case .none:
                Text("Not detected").foregroundStyle(.secondary).font(.caption)
            case .failure(let e):
                Text("Error: \(String(describing: e))").foregroundStyle(.red).font(.caption)
            case .success(let s):
                let pct = s.summary.avgSavingsPct
                VStack(alignment: .leading, spacing: 4) {
                    HStack { Text("Savings"); Spacer(); Text(String(format: "%.1f%%", pct)).monospacedDigit() }
                        .font(.caption)
                    UsageBar(percent: pct, color: UsageColor.forSavings(pct))
                }
                HStack(spacing: 16) {
                    statTile(value: s.summary.totalSaved.formatted(), label: "tokens saved")
                    statTile(value: s.summary.totalCommands.formatted(), label: "commands")
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
            let r = await CommandRunner.shared.runWithNotification(
                title: "RTK history", executable: path, arguments: ["gain", "--history"])
            CommandOutputWindow.show(title: "RTK history", output: r.succeeded ? r.stdout : r.stderr)
            isFetchingHistory = false
        }
    }
}

// MARK: - Caveman

private struct CavemanSection: View {
    let result: Result<CavemanStats, Error>?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Caveman", systemImage: "hammer.fill").font(.subheadline.bold())
            switch result {
            case .none:
                EmptyView()
            case .failure(let e):
                Text("Error: \(String(describing: e))").foregroundStyle(.red).font(.caption)
            case .success(let s):
                VStack(alignment: .leading, spacing: 6) {
                    // compression ratio bar (output/input — lower is terser)
                    let ratio = min(s.compressionRatio * 100, 100)
                    HStack {
                        Text("Output ratio")
                        Spacer()
                        Text(String(format: "%.0f%%", ratio)).monospacedDigit()
                    }
                    .font(.caption)
                    UsageBar(percent: ratio, color: UsageColor.forSavings(100 - ratio))

                    HStack(spacing: 16) {
                        statTile(value: s.totalInputTokens.formatted(), label: "input (24h)")
                        statTile(value: s.outputTokens.formatted(), label: "output")
                        statTile(value: "\(s.sessionCount)", label: "sessions")
                    }
                    .font(.caption)
                }
            }
        }
    }

    private func statTile(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value).font(.callout.bold()).monospacedDigit()
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }
}

// MARK: - MemPalace

private struct MemPalaceSection: View {
    let result: Result<MemPalaceStats, Error>?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("MemPalace", systemImage: "books.vertical.fill").font(.subheadline.bold())
            switch result {
            case .none:
                Text("Not detected").foregroundStyle(.secondary).font(.caption)
            case .failure(let e):
                Text("Error: \(String(describing: e))").foregroundStyle(.red).font(.caption)
            case .success(let s):
                Text("Total drawers: \(s.totalDrawers.formatted())").font(.caption)
                if !s.wings.isEmpty {
                    Text("Wings: \(s.wings.count)").font(.caption).foregroundStyle(.secondary)
                    ForEach(s.wings.prefix(5), id: \.name) { wing in
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

// MARK: - Shared bar + color

private struct UsageBar: View {
    let percent: Double
    let color: Color
    var body: some View {
        Capsule().fill(Color.gray.opacity(0.18)).frame(height: 6)
            .overlay(alignment: .leading) {
                GeometryReader { geo in
                    Capsule().fill(color)
                        .frame(width: geo.size.width * CGFloat(min(max(percent, 0), 100)) / 100, height: 6)
                }
            }
    }
}

enum UsageColor {
    static func forUsage(_ p: Double) -> Color {
        p < 50 ? Color(NSColor.systemGreen) : p < 90 ? Color(NSColor.systemOrange) : Color(NSColor.systemRed)
    }
    static func forSavings(_ p: Double) -> Color {
        p < 25 ? Color(NSColor.systemRed) : p < 50 ? Color(NSColor.systemOrange) : Color(NSColor.systemGreen)
    }
}
