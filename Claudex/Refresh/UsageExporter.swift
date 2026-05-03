import Foundation

/// Writes the aggregated stats to `~/.claudex/usage.json` so other tools can
/// consume them. Schema mirrors `~/.claudemeter/usage.json` for the Claude
/// section, with two extra optional sections (`rtk`, `mempalace`).
enum UsageExporter {
    static var fileURL: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".claudex/usage.json")
    }

    static func write(_ stats: AggregatedStats) {
        let payload = ExportPayload(
            lastUpdated: Date(),
            claude: extractClaude(stats),
            rtk: extractRTK(stats),
            mempalace: extractMemPalace(stats)
        )

        do {
            try ensureDirectory()
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(payload)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // Export is best-effort; never fail the refresh cycle over it.
        }
    }

    private static func ensureDirectory() throws {
        let dir = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    private static func extractClaude(_ stats: AggregatedStats) -> ClaudeUsage? {
        if case let .success(usage)? = stats.claude { return usage }
        return nil
    }

    private static func extractRTK(_ stats: AggregatedStats) -> RTKStats? {
        if case let .success(rtk)? = stats.rtk { return rtk }
        return nil
    }

    private static func extractMemPalace(_ stats: AggregatedStats) -> MemPalaceStats? {
        if case let .success(mem)? = stats.memPalace { return mem }
        return nil
    }
}

private struct ExportPayload: Codable {
    let lastUpdated: Date
    let claude: ClaudeUsage?
    let rtk: RTKStats?
    let mempalace: MemPalaceStats?

    enum CodingKeys: String, CodingKey {
        case lastUpdated = "last_updated"
        case claude
        case rtk
        case mempalace
    }
}
