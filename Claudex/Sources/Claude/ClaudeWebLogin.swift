import AppKit
import WebKit

/// Embedded Claude.ai login flow.
///
/// Opens `https://claude.ai/login` inside a WKWebView. Works for accounts that
/// authenticate via email/password (sometimes with 2FA). Does NOT work with
/// Google SSO — Google detects embedded browsers and refuses the OAuth handoff.
/// For those cases the user should pick the bookmarklet method instead.
@MainActor
final class ClaudeWebLogin: NSObject {
    private static var current: ClaudeWebLogin?

    private let window: NSWindow
    private let webView: WKWebView
    private let statusLabel: NSTextField
    private let onSuccess: (String) -> Void
    private let onCancel: () -> Void

    private var captured = false
    private var pollTimer: Timer?

    static func present(
        onSuccess: @escaping (String) -> Void,
        onCancel: @escaping () -> Void = {}
    ) {
        if let existing = current {
            existing.bringToFront()
            return
        }
        let instance = ClaudeWebLogin(onSuccess: onSuccess, onCancel: onCancel)
        instance.show()
        current = instance
    }

    private init(onSuccess: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
        self.onSuccess = onSuccess
        self.onCancel = onCancel

        let config = WKWebViewConfiguration()
        config.websiteDataStore = WKWebsiteDataStore.default()
        self.webView = WKWebView(frame: .zero, configuration: config)

        self.statusLabel = NSTextField(labelWithString: "Sign in to Claude — your session stays on this device.")
        self.statusLabel.font = .systemFont(ofSize: 11)
        self.statusLabel.textColor = .secondaryLabelColor

        let container = NSStackView()
        container.orientation = .vertical
        container.alignment = .leading
        container.spacing = 0
        container.edgeInsets = NSEdgeInsets(top: 0, left: 12, bottom: 8, right: 12)
        container.addArrangedSubview(webView)
        container.addArrangedSubview(statusLabel)
        webView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ])

        let viewController = NSViewController()
        viewController.view = container

        let window = NSWindow(contentViewController: viewController)
        window.title = "Sign in to Claude"
        window.styleMask = [.titled, .closable, .resizable]
        window.setContentSize(NSSize(width: 1024, height: 720))
        window.isReleasedWhenClosed = false
        window.center()
        self.window = window

        super.init()

        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
        webView.navigationDelegate = self

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowWillClose(_:)),
            name: NSWindow.willCloseNotification,
            object: window
        )

        if let url = URL(string: "https://claude.ai/login") {
            webView.load(URLRequest(url: url))
        }
    }

    private func show() {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        startPolling()
    }

    private func bringToFront() {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func dismiss() {
        stopPolling()
        window.close()
    }

    private func startPolling() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.checkCookies() }
        }
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func checkCookies() {
        guard !captured else { return }
        let store = webView.configuration.websiteDataStore.httpCookieStore
        store.getAllCookies { [weak self] cookies in
            guard let self, !self.captured else { return }
            let candidate = cookies.first { cookie in
                cookie.name == "sessionKey"
                    && cookie.value.hasPrefix(ClaudeAuth.sessionKeyPrefix)
                    && cookie.domain.contains("claude.ai")
            }
            guard let cookie = candidate else { return }
            self.captured = true
            let value = cookie.value
            Task { @MainActor in
                self.statusLabel.stringValue = "Connected as \(ClaudeAuth.mask(value)). Closing…"
                self.onSuccess(value)
                try? await Task.sleep(nanoseconds: 600_000_000)
                self.dismiss()
            }
        }
    }

    @objc private func windowWillClose(_ notification: Notification) {
        stopPolling()
        if !captured {
            onCancel()
        }
        NotificationCenter.default.removeObserver(self)
        ClaudeWebLogin.current = nil
    }
}

extension ClaudeWebLogin: WKNavigationDelegate {
    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor in self.checkCookies() }
    }

    nonisolated func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in
            self.statusLabel.stringValue = "Network error: \(error.localizedDescription)"
        }
    }
}
