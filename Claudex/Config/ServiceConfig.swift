import Foundation

struct ServiceConfig {
    let claudeConfigured: Bool
    let rtkBinaryPath: String?
    let memPalaceBinaryPath: String?

    var rtkConfigured: Bool { rtkBinaryPath != nil }
    var memPalaceConfigured: Bool { memPalaceBinaryPath != nil }
    var isAnyConfigured: Bool { claudeConfigured || rtkConfigured || memPalaceConfigured }

    static var current: ServiceConfig {
        ServiceConfig(
            claudeConfigured: KeychainStore.exists(.claudeSessionKey),
            rtkBinaryPath: AppSettings.rtkBinaryPath ?? ProcessLocator.locate("rtk"),
            memPalaceBinaryPath: AppSettings.memPalaceBinaryPath ?? ProcessLocator.locate("mempalace")
        )
    }
}

enum ProcessLocator {
    static func locate(_ binaryName: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = [binaryName]

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
