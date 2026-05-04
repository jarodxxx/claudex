import Foundation
import AppKit

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

/// Polls GitHub Releases for newer Claudex versions and prompts the user when
/// one is available. Two ways to trigger:
///
///   * Automatic: once at app launch, then at most once every 24 h
///   * Manual: from Settings → About → "Check for updates now"
///
/// Users can dismiss a specific version (it won't re-prompt for that exact
/// version) or disable the automatic check entirely.
@MainActor
final class UpdateChecker {
    static let shared = UpdateChecker()

    private static let releasesURL = URL(
        string: "https://api.github.com/repos/jarodxxx/Claudex/releases/latest"
    )!
    private static let minimumIntervalBetweenAutoChecks: TimeInterval = 24 * 60 * 60

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    /// Run an automatic check at startup if enabled and not already checked
    /// in the last 24 h.
    func checkAtLaunchIfDue() async {
        guard AppSettings.checkForUpdatesAutomatically else { return }

        let now = Date().timeIntervalSince1970
        let last = AppSettings.lastUpdateCheckTimestamp
        if now - last < Self.minimumIntervalBetweenAutoChecks { return }

        AppSettings.lastUpdateCheckTimestamp = now

        guard let release = await fetchLatest() else { return }
        guard isNewer(release.version, than: currentVersion) else { return }
        if AppSettings.dismissedUpdateVersion == release.version { return }

        presentUpdateAlert(release: release, automatic: true)
    }

    /// Manual "Check for updates now" — always shows the result, even if up to
    /// date or on error. Returns a human-readable status string.
    func manualCheck() async -> String {
        AppSettings.lastUpdateCheckTimestamp = Date().timeIntervalSince1970

        guard let release = await fetchLatest() else {
            return "Could not reach GitHub. Check your network and try again."
        }

        if !isNewer(release.version, than: currentVersion) {
            return "You're up to date — Claudex \(currentVersion) is the latest version."
        }

        // Reset dismissal when the user explicitly checks
        AppSettings.dismissedUpdateVersion = nil
        presentUpdateAlert(release: release, automatic: false)
        return "Update found: \(release.tagName)."
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
            You're running version \(currentVersion). The latest release on GitHub is \(release.tagName).

            If you installed Claudex via Homebrew, just run `brew upgrade --cask claudex`.
            Otherwise, open the release page to grab the new .dmg.
            """
        alert.addButton(withTitle: "Open Release Page")
        alert.addButton(withTitle: "Copy Brew Command")
        if automatic {
            alert.addButton(withTitle: "Skip This Version")
        } else {
            alert.addButton(withTitle: "Close")
        }

        let response = alert.runModal()
        switch response {
        case .alertFirstButtonReturn:
            if let url = URL(string: release.htmlUrl) {
                NSWorkspace.shared.open(url)
            }
        case .alertSecondButtonReturn:
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString("brew upgrade --cask claudex", forType: .string)
            // Soft confirmation
            let copied = NSAlert()
            copied.messageText = "Copied to clipboard"
            copied.informativeText = "Open Terminal and paste:\n\nbrew upgrade --cask claudex"
            copied.runModal()
        case .alertThirdButtonReturn where automatic:
            // "Skip This Version" — don't prompt again for this exact version
            AppSettings.dismissedUpdateVersion = release.version
        default:
            break
        }
    }
}
