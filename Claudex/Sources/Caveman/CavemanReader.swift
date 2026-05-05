import Foundation

enum CavemanReaderError: Error {
    case noSessionsFound
    case unparseableData
}

/// Reads token savings from Claude Code session JSONL files directly —
/// no dependency on Caveman being installed, no CLI invocation needed.
///
/// Claude Code writes one JSONL file per conversation under:
///   ~/.claude/projects/<hash>/<uuid>.jsonl
///
/// Each line is a JSON object. Lines where `role == "assistant"` contain
/// `usage.input_tokens` and `usage.output_tokens`. We aggregate all sessions
/// touched in the last 24 h (configurable) and treat the reduction vs. raw
/// input as the "Caveman savings" — a proxy for how much compression was
/// achieved in your Claude Code sessions.
struct CavemanReader {
    /// How far back (seconds) to look for sessions. Default 24 h.
    let lookback: TimeInterval

    init(lookback: TimeInterval = 24 * 3600) {
        self.lookback = lookback
    }

    func fetchStats() throws -> CavemanStats {
        let projectsDir = URL(fileURLWithPath: AppSettings.claudeProjectsPath)

        guard FileManager.default.fileExists(atPath: projectsDir.path) else {
            throw CavemanReaderError.noSessionsFound
        }

        let cutoff = Date().addingTimeInterval(-lookback)
        var totalInput = 0
        var totalCached = 0
        var totalOutput = 0
        var sessionsRead = 0

        let modDateKey = URLResourceKey.contentModificationDateKey
        let enumerator = FileManager.default.enumerator(
            at: projectsDir,
            includingPropertiesForKeys: [modDateKey],
            options: [.skipsHiddenFiles]
        )

        while let url = enumerator?.nextObject() as? URL {
            guard url.pathExtension == "jsonl" else { continue }
            let mdate = (try? url.resourceValues(forKeys: [modDateKey]))?.contentModificationDate
            guard let mdate, mdate >= cutoff else { continue }

            if let counts = Self.parseJSONL(at: url) {
                totalInput  += counts.input
                totalCached += counts.cached
                totalOutput += counts.output
                sessionsRead += 1
            }
        }

        guard sessionsRead > 0 else { throw CavemanReaderError.noSessionsFound }

        return CavemanStats(
            inputTokens: totalInput,
            cachedTokens: totalCached,
            outputTokens: totalOutput,
            sessionCount: sessionsRead
        )
    }

    // MARK: - JSONL parser

    private static func parseJSONL(at url: URL) -> (input: Int, cached: Int, output: Int)? {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        var input = 0; var cached = 0; var output = 0

        for line in content.split(separator: "\n", omittingEmptySubsequences: true) {
            guard let data = line.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { continue }

            // Claude Code JSONL: tokens live in obj["message"]["usage"]
            let usage = (obj["message"] as? [String: Any])?["usage"] as? [String: Any]
                     ?? obj["usage"] as? [String: Any]
            guard let usage else { continue }

            input  += usage["input_tokens"]              as? Int ?? 0
            cached += usage["cache_creation_input_tokens"] as? Int ?? 0
            cached += usage["cache_read_input_tokens"]     as? Int ?? 0
            output += usage["output_tokens"]              as? Int ?? 0
        }

        guard input > 0 || output > 0 else { return nil }
        return (input, cached, output)
    }
}
