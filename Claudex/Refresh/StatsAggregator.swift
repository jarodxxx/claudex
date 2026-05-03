import Foundation
import Combine

struct AggregatedStats {
    var claude: Result<ClaudeUsage, Error>?
    var rtk: Result<RTKStats, Error>?
    var memPalace: Result<MemPalaceStats, Error>?

    var maxUtilization: Double {
        guard case let .success(usage)? = claude else { return 0 }
        let sonnet = usage.sonnetUsage?.utilization ?? 0
        return max(usage.sessionUsage.utilization, sonnet, usage.weeklyUsage.utilization)
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
