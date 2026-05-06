import Foundation

enum CavemanReaderError: Error {
    case noSessionsFound
    case unparseableData
}

/// Reads token stats from Claude Code session JSONL files directly —
/// no dependency on Caveman being installed, no CLI invocation needed.
///
/// Claude Code writes one JSONL file per conversation under:
///   ~/.claude/projects/<hash>/<uuid>.jsonl
///
/// Each line is a JSON object. Lines where `role == "assistant"` contain
/// usage data, model info, and tool_use content blocks. We aggregate all
/// sessions touched in the last 24 h (configurable).
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
        var totalCacheCreation = 0
        var totalCacheRead = 0
        var totalOutput = 0
        var sessionsRead = 0
        var totalMessages = 0
        var totalToolCalls = 0
        var projectDirs = Set<URL>()
        var modelUsage: [String: Int] = [:]

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

            if let parsed = Self.parseJSONL(at: url) {
                totalInput         += parsed.input
                totalCacheCreation += parsed.cacheCreation
                totalCacheRead     += parsed.cacheRead
                totalOutput        += parsed.output
                totalMessages      += parsed.messages
                totalToolCalls     += parsed.toolCalls
                sessionsRead       += 1
                projectDirs.insert(url.deletingLastPathComponent())
                for (model, tokens) in parsed.modelUsage {
                    modelUsage[model, default: 0] += tokens
                }
            }
        }

        guard sessionsRead > 0 else { throw CavemanReaderError.noSessionsFound }

        return CavemanStats(
            inputTokens:         totalInput,
            cacheCreationTokens: totalCacheCreation,
            cacheReadTokens:     totalCacheRead,
            outputTokens:        totalOutput,
            sessionCount:        sessionsRead,
            messageCount:        totalMessages,
            toolCallCount:       totalToolCalls,
            activeProjects:      projectDirs.count,
            modelUsage:          modelUsage
        )
    }

    // MARK: - JSONL parser

    private struct ParseResult {
        var input: Int = 0
        var cacheCreation: Int = 0
        var cacheRead: Int = 0
        var output: Int = 0
        var messages: Int = 0
        var toolCalls: Int = 0
        var modelUsage: [String: Int] = [:]
    }

    private static func parseJSONL(at url: URL) -> ParseResult? {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        var result = ParseResult()

        for line in content.split(separator: "\n", omittingEmptySubsequences: true) {
            guard let data = line.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { continue }

            // Support both obj["message"]["usage"] and obj["usage"]
            let message = obj["message"] as? [String: Any]
            let role = (message?["role"] ?? obj["role"]) as? String
            guard role == "assistant" else { continue }

            let usage = message?["usage"] as? [String: Any] ?? obj["usage"] as? [String: Any]
            guard let usage else { continue }

            let inp = usage["input_tokens"]                as? Int ?? 0
            let cc  = usage["cache_creation_input_tokens"] as? Int ?? 0
            let cr  = usage["cache_read_input_tokens"]     as? Int ?? 0
            let out = usage["output_tokens"]               as? Int ?? 0

            guard inp > 0 || out > 0 else { continue }

            result.input         += inp
            result.cacheCreation += cc
            result.cacheRead     += cr
            result.output        += out
            result.messages      += 1

            // Count tool_use content blocks
            let contentBlocks = (message?["content"] ?? obj["content"]) as? [[String: Any]] ?? []
            result.toolCalls += contentBlocks.filter { ($0["type"] as? String) == "tool_use" }.count

            // Track model usage by token volume
            if let model = (message?["model"] ?? obj["model"]) as? String {
                result.modelUsage[model, default: 0] += inp + out
            }
        }

        guard result.input > 0 || result.output > 0 else { return nil }
        return result
    }
}
