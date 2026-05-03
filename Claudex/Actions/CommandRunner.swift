import Foundation
import AppKit
import UserNotifications

struct CommandResult {
    let title: String
    let exitCode: Int32
    let stdout: String
    let stderr: String

    var succeeded: Bool { exitCode == 0 }
}

@MainActor
final class CommandRunner {
    static let shared = CommandRunner()

    private let runner: ProcessRunning

    init(runner: ProcessRunning = SystemProcessRunner()) {
        self.runner = runner
    }

    /// Runs a command in the background, then posts a system notification with
    /// the outcome. Returns the captured stdout/stderr for callers that want to
    /// display it in a window.
    func runWithNotification(
        title: String,
        executable: String,
        arguments: [String]
    ) async -> CommandResult {
        let result: CommandResult
        do {
            let output = try runner.run(executable: executable, arguments: arguments)
            result = CommandResult(
                title: title,
                exitCode: output.exitCode,
                stdout: String(data: output.stdout, encoding: .utf8) ?? "",
                stderr: String(data: output.stderr, encoding: .utf8) ?? ""
            )
        } catch {
            result = CommandResult(
                title: title,
                exitCode: -1,
                stdout: "",
                stderr: String(describing: error)
            )
        }

        await NotificationPresenter.shared.notify(
            title: title,
            body: result.succeeded ? "Completed successfully." : "Failed: \(result.stderr.prefix(120))"
        )

        return result
    }
}

@MainActor
final class NotificationPresenter {
    static let shared = NotificationPresenter()

    /// Like `notify(...)` but returns a human-readable diagnosis string for
    /// the Settings panel test button.
    func diagnose(title: String, body: String) async -> String {
        let bundleID = Bundle.main.bundleIdentifier ?? "<no bundle id>"

        if let result = await tryModernNotify(title: title, body: body) {
            return "Posted via UNUserNotificationCenter (\(result), bundle=\(bundleID))"
        }

        // Modern path failed (typically UNErrorDomain error 1 — app not
        // signed with Apple Developer ID). Fall back to AppleScript which
        // always works regardless of signing.
        if osascriptNotify(title: title, body: body) {
            return "Posted via osascript fallback. UNUserNotificationCenter is blocked for ad-hoc signed apps; this is expected in dev. A Developer ID build will use the modern path."
        }

        return "Both UNUserNotificationCenter and osascript fallback failed. Bundle id: \(bundleID)."
    }

    /// Returns nil if the modern API is unusable (auth error, denied, etc.).
    private func tryModernNotify(title: String, body: String) async -> String? {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        if settings.authorizationStatus == .notDetermined {
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
                if !granted { return nil }
            } catch {
                NSLog("[Claudex] requestAuthorization threw: \(error)")
                return nil
            }
        } else if settings.authorizationStatus == .denied {
            return nil
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        do {
            try await center.add(request)
            return "authorized"
        } catch {
            NSLog("[Claudex] center.add threw: \(error)")
            return nil
        }
    }

    /// Fires `osascript -e 'display notification ...'`. Always works on macOS,
    /// even for ad-hoc signed apps. Returns true on exit code 0.
    private func osascriptNotify(title: String, body: String) -> Bool {
        let escape: (String) -> String = { s in
            s.replacingOccurrences(of: "\\", with: "\\\\")
             .replacingOccurrences(of: "\"", with: "\\\"")
        }
        let script = "display notification \"\(escape(body))\" with title \"\(escape(title))\""

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            NSLog("[Claudex] osascript notify failed: \(error)")
            return false
        }
    }

    func notify(title: String, body: String) async {
        if await tryModernNotify(title: title, body: body) != nil {
            NSLog("[Claudex] notification posted (UN): \(title)")
            return
        }
        if osascriptNotify(title: title, body: body) {
            NSLog("[Claudex] notification posted (osascript fallback): \(title)")
            return
        }
        NSLog("[Claudex] notification dropped: \(title)")
    }

    private func showDeniedAlert() {
        let alert = NSAlert()
        alert.messageText = "Notifications are disabled for Claudex"
        alert.informativeText = "Open System Settings → Notifications → Claudex to allow alerts."
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}
