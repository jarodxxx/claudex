import Foundation

protocol ProcessRunning {
    func run(executable: String, arguments: [String]) throws -> ProcessOutput
}

struct ProcessOutput {
    let exitCode: Int32
    let stdout: Data
    let stderr: Data
}

struct SystemProcessRunner: ProcessRunning {
    func run(executable: String, arguments: [String]) throws -> ProcessOutput {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        return ProcessOutput(
            exitCode: process.terminationStatus,
            stdout: stdoutPipe.fileHandleForReading.readDataToEndOfFile(),
            stderr: stderrPipe.fileHandleForReading.readDataToEndOfFile()
        )
    }
}

enum RTKReaderError: Error {
    case binaryNotConfigured
    case nonZeroExit(code: Int32, stderr: String)
    case decodingFailed(underlying: Error, raw: String)
}

struct RTKReader {
    let binaryPath: String
    let runner: ProcessRunning

    init(binaryPath: String, runner: ProcessRunning = SystemProcessRunner()) {
        self.binaryPath = binaryPath
        self.runner = runner
    }

    func fetchStats() throws -> RTKStats {
        let output = try runner.run(
            executable: binaryPath,
            arguments: ["gain", "--all", "--format", "json"]
        )

        guard output.exitCode == 0 else {
            let stderr = String(data: output.stderr, encoding: .utf8) ?? ""
            throw RTKReaderError.nonZeroExit(code: output.exitCode, stderr: stderr)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            return try decoder.decode(RTKStats.self, from: output.stdout)
        } catch {
            let raw = String(data: output.stdout, encoding: .utf8) ?? ""
            throw RTKReaderError.decodingFailed(underlying: error, raw: raw)
        }
    }
}
