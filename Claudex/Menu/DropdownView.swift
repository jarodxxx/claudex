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
        ForEach(Array(toolSections.enumerated()), id: \.offset) { _, section in
            section
        }
    }

    @ViewBuilder
    private var categorisedContent: some View {
        let grouped = Dictionary(grouping: registry.enabled, by: \.category)
        let categories = ToolCategory.allCases.filter { grouped[$0] != nil }
        ForEach(Array(categories.enumerated()), id: \.element) { idx, cat in
            HStack {
                Image(systemName: cat.icon)
                Text(cat.rawValue.uppercased())
            }
            .font(.caption2.bold())
            .foregroundStyle(.secondary)
            .padding(.top, idx == 0 ? 0 : 6)

            let tools = grouped[cat] ?? []
            ForEach(tools, id: \.id) { tool in
                toolView(for: tool.id)
            }
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
            ClaudeSection(result: aggregator.stats.claude, showSonnet: AppSettings.showSonnet)
                .toolCard()
        case .rtk:
            if aggregator.stats.rtk != nil || ServiceConfig.current.rtkBinaryPath != nil {
                RTKSection(result: aggregator.stats.rtk)
                    .toolCard()
            }
        case .caveman:
            if aggregator.stats.caveman != nil {
                CavemanSection(result: aggregator.stats.caveman)
                    .toolCard()
            }
        case .mempalace:
            if aggregator.stats.memPalace != nil || ServiceConfig.current.memPalaceBinaryPath != nil {
                MemPalaceSection(result: aggregator.stats.memPalace)
                    .toolCard()
            }
        }
    }
}

// MARK: - Shared components

private extension View {
    func toolCard() -> some View {
        self
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(NSColor.windowBackgroundColor))
                    .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 1.5)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.secondary.opacity(0.18), lineWidth: 0.5)
            )
    }
}

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
                VStack(alignment: .leading, spacing: 8) {

                    // Output ratio bar
                    let ratio = min(s.compressionRatio * 100, 100)
                    barRow(label: "Output ratio", percent: ratio,
                           color: UsageColor.forSavings(100 - ratio))

                    // Cache hit rate bar
                    if s.cachedTokens > 0 {
                        let hit = s.cacheHitRate * 100
                        barRow(label: "Cache hit rate", percent: hit,
                               color: UsageColor.forSavings(hit))
                    }

                    Divider()

                    // Cost · model · projects summary
                    HStack(spacing: 6) {
                        Label(costLabel(s.estimatedCostUSD), systemImage: "dollarsign.circle")
                        Spacer()
                        if let model = s.dominantModel {
                            Text(shortModel(model))
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.15))
                                .clipShape(Capsule())
                        }
                        Label("\(s.activeProjects)", systemImage: "folder")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    Divider()

                    // Tokens — 4 colonnes séparées par traits fins
                    sectionLabel("Tokens")
                    HStack(spacing: 0) {
                        statTile(value: tok(s.inputTokens),         label: "input")
                        colDivider()
                        statTile(value: tok(s.cacheCreationTokens), label: "cache↑")
                        colDivider()
                        statTile(value: tok(s.cacheReadTokens),     label: "cache↓")
                        colDivider()
                        statTile(value: tok(s.outputTokens),        label: "output")
                    }
                    .fixedSize(horizontal: false, vertical: true)

                    Divider()

                    // Activity — 3 columns
                    sectionLabel("Activity")
                    HStack(spacing: 0) {
                        statTile(value: "\(s.sessionCount)",  label: "sessions")
                        statTile(value: tok(s.messageCount),  label: "turns")
                        statTile(value: tok(s.toolCallCount), label: "tools")
                    }
                }
                .font(.caption)
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func barRow(label: String, percent: Double, color: Color) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(String(format: "%.0f%%", percent)).monospacedDigit()
        }
        .font(.caption)
        UsageBar(percent: percent, color: color)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .tracking(0.5)
    }

    private func statTile(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.callout.bold()).monospacedDigit()
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
    }

    private func colDivider() -> some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.2))
            .frame(width: 0.5)
            .padding(.vertical, 2)
    }

    // Format token counts as compact strings: 1 234 → 1.2K, 1 234 567 → 1.2M
    private func tok(_ n: Int) -> String {
        switch n {
        case ..<1_000:         return "\(n)"
        case ..<1_000_000:     return String(format: "%.1fK", Double(n) / 1_000)
        case ..<1_000_000_000: return String(format: "%.1fM", Double(n) / 1_000_000)
        default:               return String(format: "%.1fB", Double(n) / 1_000_000_000)
        }
    }

    private func costLabel(_ usd: Double) -> String {
        if usd < 0.005 { return "<$0.01" }
        if usd >= 1000  { return String(format: "~$%.0f", usd) }
        return String(format: "~$%.2f", usd)
    }

    private func shortModel(_ id: String) -> String {
        let lower = id.lowercased()
        if lower.contains("haiku")  { return "Haiku" }
        if lower.contains("opus")   { return "Opus" }
        if lower.contains("sonnet") { return "Sonnet" }
        return id
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
