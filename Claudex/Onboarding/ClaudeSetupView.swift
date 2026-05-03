import SwiftUI
import AppKit

struct ClaudeSetupView: View {
    enum Method: String, CaseIterable, Identifiable {
        case webSignIn = "Web sign-in"
        case manual = "Manual paste"
        var id: String { rawValue }

        var subtitle: String {
            switch self {
            case .webSignIn:
                return "Quickest. Works with email/password accounts. Google SSO is blocked by Claude in embedded browsers."
            case .manual:
                return "Always works, including Google SSO. Requires a quick visit to your browser's DevTools."
            }
        }
    }

    @StateObject private var clipboard = ClipboardWatcher()
    @State private var selectedMethod: Method = .webSignIn
    @State private var sessionKey: String = ""
    @State private var savedMessage: String?
    @State private var error: String?
    @State private var refreshTick = 0

    private var isConnected: Bool {
        _ = refreshTick
        return KeychainStore.exists(.claudeSessionKey)
    }

    var body: some View {
        GroupBox(label: Label("Claude", systemImage: "brain.head.profile")) {
            VStack(alignment: .leading, spacing: 12) {
                if isConnected {
                    connectedState
                } else {
                    Picker("Method", selection: $selectedMethod) {
                        ForEach(Method.allCases) { method in
                            Text(method.rawValue).tag(method)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()

                    Text(selectedMethod.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    switch selectedMethod {
                    case .webSignIn: webSignInSteps
                    case .manual: manualSteps
                    }
                }

                if let savedMessage { Text(savedMessage).font(.caption).foregroundStyle(.green) }
                if let error { Text(error).font(.caption).foregroundStyle(.red) }
            }
            .padding(8)
        }
        .onAppear { clipboard.start() }
        .onDisappear { clipboard.stop() }
        .onChange(of: clipboard.detectedKey) { _, newValue in
            if let key = newValue { sessionKey = key }
        }
    }

    // MARK: - Connected

    private var connectedState: some View {
        HStack {
            Label("Connected", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Spacer()
            Button("Sign out") { signOut() }
                .buttonStyle(.borderless)
                .font(.caption)
        }
    }

    // MARK: - Web sign-in

    private var webSignInSteps: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                ClaudeWebLogin.present(onSuccess: { capturedKey in
                    do {
                        try ClaudeAuth.validate(capturedKey)
                        try KeychainStore.save(capturedKey, for: .claudeSessionKey)
                        savedMessage = "Connected (\(ClaudeAuth.mask(capturedKey)))"
                        error = nil
                        refreshTick += 1
                    } catch let err {
                        error = "Captured a key but failed to save: \(err)"
                    }
                })
            } label: {
                Label("Sign in to Claude", systemImage: "person.crop.circle.badge.checkmark")
            }
            .buttonStyle(.borderedProminent)

            Text("Opens claude.ai in a secure window inside Claudex. Cookie never leaves the device.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Manual paste

    private var manualSteps: some View {
        VStack(alignment: .leading, spacing: 10) {
            stepHeader(number: 1, title: "Open claude.ai in your browser")
            HStack {
                Button {
                    if let url = URL(string: "https://claude.ai") { NSWorkspace.shared.open(url) }
                } label: {
                    Label("Open claude.ai", systemImage: "globe")
                }
                Text("→ make sure you're signed in")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.leading, 20)

            stepHeader(number: 2, title: "Open DevTools and find the cookie")
            VStack(alignment: .leading, spacing: 4) {
                Text("Press **F12** (or **⌥⌘I** on Mac).")
                Text("**Firefox**: Storage tab → Cookies → https://claude.ai → click `sessionKey` → copy the **Value** column.")
                Text("**Chrome / Edge**: Application tab → Cookies → https://claude.ai → copy `sessionKey` value.")
                Text("**Safari**: enable Develop menu first (Settings → Advanced → Show features for web developers), then ⌥⌘I → Storage → Cookies.")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.leading, 20)
            .fixedSize(horizontal: false, vertical: true)

            stepHeader(number: 3, title: "Paste it here")
            VStack(alignment: .leading, spacing: 6) {
                if clipboard.detectedKey != nil {
                    Label("Detected a Claude key in your clipboard", systemImage: "sparkles")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
                SecureField("sk-ant-...", text: $sessionKey)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Button("Save") { save() }
                        .buttonStyle(.borderedProminent)
                        .disabled(sessionKey.isEmpty)
                    Spacer()
                    if !sessionKey.isEmpty {
                        Button("Clear") {
                            sessionKey = ""
                            clipboard.dismissDetectedKey()
                        }
                        .buttonStyle(.borderless)
                        .font(.caption)
                    }
                }
            }
            .padding(.leading, 20)
        }
    }

    // MARK: - Helpers

    private func stepHeader(number: Int, title: String) -> some View {
        HStack(spacing: 8) {
            Text("\(number)")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 18, height: 18)
                .background(Circle().fill(Color.accentColor))
            Text(title).font(.caption.bold())
        }
    }

    private func save() {
        do {
            try ClaudeAuth.validate(sessionKey)
            try KeychainStore.save(sessionKey, for: .claudeSessionKey)
            savedMessage = "Saved (\(ClaudeAuth.mask(sessionKey)))"
            error = nil
            sessionKey = ""
            clipboard.dismissDetectedKey()
            refreshTick += 1
            NotificationCenter.default.post(name: .claudexShouldRefresh, object: nil)
        } catch let err {
            error = String(describing: err)
            savedMessage = nil
        }
    }

    private func signOut() {
        try? KeychainStore.delete(.claudeSessionKey)
        AppSettings.claudeOrgUUID = nil
        savedMessage = nil
        error = nil
        refreshTick += 1
        NotificationCenter.default.post(name: .claudexShouldRefresh, object: nil)
    }
}
