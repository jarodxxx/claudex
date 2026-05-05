import Foundation

struct ServiceConfig {
    let claudeConfigured: Bool
    let claudeBinaryPath: String?
    let rtkBinaryPath: String?
    let memPalaceBinaryPath: String?

    var rtkConfigured: Bool { rtkBinaryPath != nil }
    var memPalaceConfigured: Bool { memPalaceBinaryPath != nil }
    var cavemanConfigured: Bool { claudeBinaryPath != nil }
    var isAnyConfigured: Bool { claudeConfigured || rtkConfigured || memPalaceConfigured || cavemanConfigured }

    static var current: ServiceConfig {
        // ProcessLocator results are persisted so subsequent look-ups (which
        // run inside the app's limited PATH) find the same binary.
        func resolve(saved: String?, binary: String) -> String? {
            if let saved { return saved }
            if let found = ProcessLocator.locate(binary) {
                return found
            }
            return nil
        }
        return ServiceConfig(
            claudeConfigured: KeychainStore.exists(.claudeSessionKey),
            claudeBinaryPath: resolve(saved: AppSettings.claudeBinaryPath, binary: "claude"),
            rtkBinaryPath: resolve(saved: AppSettings.rtkBinaryPath, binary: "rtk"),
            memPalaceBinaryPath: resolve(saved: AppSettings.memPalaceBinaryPath, binary: "mempalace")
        )
    }
}

enum ProcessLocator {
    /// Common install locations not always in the app's default PATH.
    private static let extraSearchPaths = [
        "/opt/homebrew/bin",       // Homebrew Apple Silicon
        "/usr/local/bin",          // Homebrew Intel / manual installs
        "/opt/homebrew/sbin",
        "/usr/local/sbin",
        "\(NSHomeDirectory())/.local/bin",   // pip --user, uv, mise
        "\(NSHomeDirectory())/.cargo/bin",   // Rust / cargo install
        "\(NSHomeDirectory())/.npm/bin",
    ]

    static func locate(_ binaryName: String) -> String? {
        // 1. Probe common paths directly (fastest, avoids PATH issues)
        for dir in extraSearchPaths {
            let candidate = "\(dir)/\(binaryName)"
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }

        // 2. Fall back to `which` with an enriched PATH
        let augmentedPath = (["/usr/bin", "/bin"] + extraSearchPaths).joined(separator: ":")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = [binaryName]
        process.environment = ["PATH": augmentedPath]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let path = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return (path?.isEmpty == false) ? path : nil
        } catch {
            return nil
        }
    }
}
