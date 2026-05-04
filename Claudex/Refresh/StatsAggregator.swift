import Foundation
import Combine

struct AggregatedStats {
    var claude: Result<ClaudeUsage, Error>?
    var rtk: Result<RTKStats, Error>?
    var memPalace: Result<MemPalaceStats, Error>?

    /// Utilization that drives the menu bar icon. We pick the quota whose
    /// reset is *closest in time* — that's the one that will affect the user
    /// soonest. Example: if Session is at 26 % (resets in 3 h) and Weekly is
    /// at 63 % (resets in 4 h), we surface 26 % because the 5-hour window is
    /// the next constraint to hit.
    var iconUtilization: Double {
        guard case let .success(usage)? = claude else { return 0 }
        var candidates: [(percent: Double, reset: Date)] = [
            (usage.sessionUsage.utilization, usage.sessionUsage.resetAt),
            (usage.weeklyUsage.utilization, usage.weeklyUsage.resetAt),
        ]
        if let sonnet = usage.sonnetUsage {
            candidates.append((sonnet.utilization, sonnet.resetAt))
        }
        // Earliest reset wins. Ties (same Date) fall back to the higher %.
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

        async let claudeResult: Result<ClaudeUsage, Error>? = config.claudeConfigured
            ? Self.run { try await ClaudeClient().fetchUsage() }
            : nil
        async let rtkResult: Result<RTKStats, Error>? = await readRTK(config: config)
        async let memResult: Result<MemPalaceStats, Error>? = await readMemPalace(config: config)

        let (c, r, m) = await (claudeResult, rtkResult, memResult)
        let aggregated = AggregatedStats(claude: c, rtk: r, memPalace: m)
        stats = aggregated
        UsageExporter.write(aggregated)
    }

    private func readRTK(config: ServiceConfig) async -> Result<RTKStats, Error>? {
        guard let path = config.rtkBinaryPath else { return nil }
        return await Self.run { try RTKReader(binaryPath: path).fetchStats() }
    }

    private func readMemPalace(config: ServiceConfig) async -> Result<MemPalaceStats, Error>? {
        guard let path = config.memPalaceBinaryPath else { return nil }
        return await Self.run { try MemPalaceReader(binaryPath: path).fetchStats() }
    }

    private static func run<T>(_ work: @Sendable () async throws -> T) async -> Result<T, Error> {
        do {
            return .success(try await work())
        } catch {
            return .failure(error)
        }
    }
}
