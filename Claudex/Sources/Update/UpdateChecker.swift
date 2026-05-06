import Foundation
import AppKit
import Observation

struct GitHubRelease: Codable {
    let tagName: String
    let htmlUrl: String
    let body: String?
    let publishedAt: String?

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlUrl = "html_url"
        case body
        case publishedAt = "published_at"
    }

    var version: String {
        tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
    }
}

/// Polls GitHub Releases for newer Claudex versions and lets the user update
/// in-app (Homebrew) or via the release page (manual install).
///
/// Install method is asked once on first update and stored in AppSettings.
@MainActor
@Observable
final class UpdateChecker {
    static let shared = UpdateChecker()

    private static let releasesURL = URL(
        string: "https://api.github.com/repos/jarodxxx/Claudex/releases/latest"
    )!
    private static let minimumIntervalBetweenAutoChecks: TimeInterval = 24 * 60 * 60

    /// Most recent release newer than current build. Observed by AboutSettingsView.
    var availableRelease: GitHubRelease? = nil
    /// True while brew upgrade is running.
    var isUpdating: Bool = false

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    func checkAtLaunchIfDue() async {
        guard AppSettings.checkForUpdatesAutomatically else { return }

        let now = Date().timeIntervalSince1970
        let last = AppSettings.lastUpdateCheckTimestamp
        if now - last < Self.minimumIntervalBetweenAutoChecks { return }

        AppSettings.lastUpdateCheckTimestamp = now

        guard let release = await fetchLatest() else { return }
        guard isNewer(release.version, than: currentVersion) else {
            availableRelease = nil
            return
        }
        availableRelease = release
        if AppSettings.dismissedUpdateVersion == release.version { return }
        presentUpdateAlert(release: release, automatic: true)
    }

    func manualCheck() async -> String {
        AppSettings.lastUpdateCheckTimestamp = Date().timeIntervalSince1970

        guard let release = await fetchLatest() else {
            return "Could not reach GitHub. Check your network and try again."
        }

        if !isNewer(release.version, than: currentVersion) {
            availableRelease = nil
            return "You're up to date — Claudex \(currentVersion) is the latest version."
        }

        availableRelease = release
        AppSettings.dismissedUpdateVersion = nil
        presentUpdateAlert(release: release, automatic: false)
        return "Update found: \(release.tagName)."
    }

    // MARK: - Update

    func performUpdate(release: GitHubRelease) async {
        let method: String
        if let saved = AppSettings.updateMethod {
            method = saved
        } else {
            method = askAndSaveInstallMethod()
        }

        if method == "homebrew" {
            await performBrewUpdate(release: release)
        } else {
            performManualUpdate(release: release)
        }
    }

    private func askAndSaveInstallMethod() -> String {
        let alert = NSAlert()
        alert.messageText = "How did you install Claudex?"
        alert.informativeText = "This is asked once — you can change it later in Settings → About."
        alert.addButton(withTitle: "Homebrew")
        alert.addButton(withTitle: "Manual Download")
        let method = alert.runModal() == .alertFirstButtonReturn ? "homebrew" : "manual"
        AppSettings.updateMethod = method
        return method
    }

    private func detectedBrewPath() -> String? {
        ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]
            .first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    private func performBrewUpdate(release: GitHubRelease) async {
        guard let brewPath = detectedBrewPath() else {
            AppSettings.updateMethod = "manual"
            let alert = NSAlert()
            alert.messageText = "Homebrew not found"
            alert.informativeText = """
                brew was not found at /opt/homebrew/bin/brew or /usr/local/bin/brew.
                Your install method has been switched to Manual.
                """
            alert.addButton(withTitle: "Open Release Page")
            alert.addButton(withTitle: "Close")
            if alert.runModal() == .alertFirstButtonReturn {
                performManualUpdate(release: release)
            }
            return
        }

        isUpdating = true
        let result = await CommandRunner.shared.runWithNotification(
            title: "Updating Claudex",
            executable: brewPath,
            arguments: ["upgrade", "--cask", "claudex"]
        )
        isUpdating = false

        let output = [result.stdout, result.stderr]
            .filter { !$0.isEmpty }
            .joined(separator: "\n")

        if result.succeeded {
            CommandOutputWindow.showWithRelaunch(
                title: "Claudex Updated — \(release.tagName)",
                output: output.isEmpty ? "brew upgrade completed successfully." : output
            )
        } else {
            CommandOutputWindow.show(
                title: "Update Failed",
                output: output.isEmpty ? "brew upgrade exited with code \(result.exitCode)." : output
            )
        }
    }

    private func performManualUpdate(release: GitHubRelease) {
        if let url = URL(string: release.htmlUrl) {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Networking

    private func fetchLatest() async -> GitHubRelease? {
        var request = URLRequest(url: Self.releasesURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Claudex/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                NSLog("[Claudex] update check unexpected status: \(response)")
                return nil
            }
            return try JSONDecoder().decode(GitHubRelease.self, from: data)
        } catch {
            NSLog("[Claudex] update check failed: \(error)")
            return nil
        }
    }

    // MARK: - Version compare

    private func isNewer(_ candidate: String, than current: String) -> Bool {
        let a = parse(candidate)
        let b = parse(current)
        let pairs = zip(
            a + Array(repeating: 0, count: max(0, b.count - a.count)),
            b + Array(repeating: 0, count: max(0, a.count - b.count))
        )
        for (x, y) in pairs {
            if x > y { return true }
            if x < y { return false }
        }
        return false
    }

    private func parse(_ version: String) -> [Int] {
        version.split(separator: ".").compactMap { Int($0) }
    }

    // MARK: - UI

    private func presentUpdateAlert(release: GitHubRelease, automatic: Bool) {
        let alert = NSAlert()
        alert.messageText = "Claudex \(release.tagName) is available"
        alert.informativeText = """
            You're running version \(currentVersion). \
            Version \(release.tagName) is available on GitHub.
            """
        alert.addButton(withTitle: "Update Now")
        alert.addButton(withTitle: "Open Release Page")
        if automatic {
            alert.addButton(withTitle: "Skip This Version")
        } else {
            alert.addButton(withTitle: "Close")
        }

        let response = alert.runModal()
        switch response {
        case .alertFirstButtonReturn:
            Task { await performUpdate(release: release) }
        case .alertSecondButtonReturn:
            performManualUpdate(release: release)
        case .alertThirdButtonReturn where automatic:
            AppSettings.dismissedUpdateVersion = release.version
        default:
            break
        }
    }
}
