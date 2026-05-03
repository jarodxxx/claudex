import Foundation

enum MemPalaceReaderError: Error {
    case binaryNotConfigured
    case nonZeroExit(code: Int32, stderr: String)
    case unparseableOutput(raw: String)
}

struct MemPalaceReader {
    let binaryPath: String
    let runner: ProcessRunning

    init(binaryPath: String, runner: ProcessRunning = SystemProcessRunner()) {
        self.binaryPath = binaryPath
        self.runner = runner
    }

    func fetchStats() throws -> MemPalaceStats {
        let output = try runner.run(executable: binaryPath, arguments: ["status"])

        guard output.exitCode == 0 else {
            let stderr = String(data: output.stderr, encoding: .utf8) ?? ""
            throw MemPalaceReaderError.nonZeroExit(code: output.exitCode, stderr: stderr)
        }

        let raw = String(data: output.stdout, encoding: .utf8) ?? ""
        return try Self.parse(raw)
    }

    /// `mempalace status` does not expose a JSON flag, so we parse its plain
    /// text output. Format observed (May 2026):
    ///
    ///     ===
    ///       MemPalace Status — 30486 drawers
    ///     ===
    ///
    ///       WING: foo
    ///         ROOM: general    9767 drawers
    ///         ROOM: legal       210 drawers
    ///       WING: bar
    ///         ROOM: general    6379 drawers
    ///
    /// We tolerate optional whitespace and the en-dash / hyphen variant.
    static func parse(_ text: String) throws -> MemPalaceStats {
        var totalDrawers = 0
        var wings: [String: [MemPalaceRoom]] = [:]
        var wingOrder: [String] = []
        var currentWing: String?

        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }

            if line.lowercased().contains("mempalace status") {
                if let total = extractTrailingDrawerCount(from: line) {
                    totalDrawers = total
                }
                continue
            }

            if let wingName = stripPrefix("WING:", from: line) {
                currentWing = wingName
                if wings[wingName] == nil {
                    wings[wingName] = []
                    wingOrder.append(wingName)
                }
                continue
            }

            if let roomDescriptor = stripPrefix("ROOM:", from: line),
               let wing = currentWing {
                let (name, count) = extractRoomNameAndCount(roomDescriptor)
                wings[wing, default: []].append(MemPalaceRoom(name: name, drawers: count))
            }
        }

        guard totalDrawers > 0 || !wings.isEmpty else {
            throw MemPalaceReaderError.unparseableOutput(raw: text)
        }

        let orderedWings = wingOrder.map { name in
            MemPalaceWing(name: name, rooms: wings[name] ?? [])
        }

        return MemPalaceStats(totalDrawers: totalDrawers, wings: orderedWings)
    }

    private static func stripPrefix(_ prefix: String, from line: String) -> String? {
        guard line.hasPrefix(prefix) else { return nil }
        return line.dropFirst(prefix.count).trimmingCharacters(in: .whitespaces)
    }

    private static func extractTrailingDrawerCount(from line: String) -> Int? {
        // Capture the last integer in the line.
        let scalars = Array(line)
        var idx = scalars.count - 1
        while idx >= 0, !scalars[idx].isNumber { idx -= 1 }
        let endIdx = idx
        while idx >= 0, scalars[idx].isNumber { idx -= 1 }
        let startIdx = idx + 1
        guard startIdx <= endIdx else { return nil }
        return Int(String(scalars[startIdx...endIdx]))
    }

    private static func extractRoomNameAndCount(_ descriptor: String) -> (name: String, count: Int) {
        // descriptor is e.g. "general               9767 drawers"
        let parts = descriptor.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        guard let count = parts.compactMap(Int.init).last else {
            return (descriptor, 0)
        }
        let name = parts.prefix { Int($0) == nil }.joined(separator: " ")
        return (name, count)
    }
}
