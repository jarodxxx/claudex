import Foundation
import Combine

struct AggregatedStats {
    var claude: Result<ClaudeUsage, Error>?
    var rtk: Result<RTKStats, Error>?
    var caveman: Result<CavemanStats, Error>?
    var memPalace: Result<MemPalaceStats, Error>?

    /// Utilization that drives the menu bar icon — quota with earliest reset.
    var iconUtilization: Double {
        guard case let .success(usage)? = claude else { return 0 }
        var candidates: [(percent: Double, reset: Date)] = [
            (usage.sessionUsage.utilization, usage.sessionUsage.resetAt),
            (usage.weeklyUsage.utilization, usage.weeklyUsage.resetAt),
        ]
        if let sonnet = usage.sonnetUsage {
            candidates.append((sonnet.utilization, sonnet.resetAt))
        }
        return candidates
            .min(by: { ($0.reset, -$0.percent) < ($1.reset, -$1.percent) })
            .map(\.percent) ?? 0
    }
}

@MainActor
final class StatsAggregator: ObservableObject {
    @Published private(set) var stats = AggregatedStats()
    @Published private(set) var isRefreshing = false

    func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }

        let config = ServiceConfig.current
        let registry = ToolRegistry.shared

        async let claudeResult: Result<ClaudeUsage, Error>? =
            registry.isEnabled(.claude) && config.claudeConfigured
                ? Self.run { try await ClaudeClient().fetchUsage() }
                : nil

        async let rtkResult: Result<RTKStats, Error>? =
            registry.isEnabled(.rtk)
                ? await readRTK(config: config)
                : nil

        async let cavemanResult: Result<CavemanStats, Error>? =
            registry.isEnabled(.caveman)
                ? await readCaveman(config: config)  // reads ~/.claude/projects/ JSONL directly
                : nil

        async let memResult: Result<MemPalaceStats, Error>? =
            registry.isEnabled(.mempalace)
                ? await readMemPalace(config: config)
                : nil

        let (c, r, cv, m) = await (claudeResult, rtkResult, cavemanResult, memResult)
        let aggregated = AggregatedStats(claude: c, rtk: r, caveman: cv, memPalace: m)
        stats = aggregated
        UsageExporter.write(aggregated)
    }

    private func readRTK(config: ServiceConfig) async -> Result<RTKStats, Error>? {
        guard let path = config.rtkBinaryPath else { return nil }
        return await Self.run { try RTKReader(binaryPath: path).fetchStats() }
    }

    private func readCaveman(config: ServiceConfig) async -> Result<CavemanStats, Error>? {
        // CavemanReader reads Claude Code session JSONL files directly —
        // no binary required, always attempted when the tool is enabled.
        return await Self.run { try CavemanReader().fetchStats() }
    }

    private func readMemPalace(config: ServiceConfig) async -> Result<MemPalaceStats, Error>? {
        guard let path = config.memPalaceBinaryPath else { return nil }
        return await Self.run { try MemPalaceReader(binaryPath: path).fetchStats() }
    }

    private static func run<T>(_ work: @Sendable () async throws -> T) async -> Result<T, Error> {
        do { return .success(try await work()) }
        catch { return .failure(error) }
    }
}
