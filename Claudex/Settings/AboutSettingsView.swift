import SwiftUI
import AppKit

struct AboutSettingsView: View {
    @State private var checkResult: String?
    @State private var isChecking = false
    @State private var autoCheck: Bool = AppSettings.checkForUpdatesAutomatically

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "2.0.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "Version \(short) (\(build))"
    }

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Group {
                if let appIcon = NSImage(named: "AppIcon") ?? NSApp.applicationIconImage {
                    Image(nsImage: appIcon)
                        .resizable()
                } else {
                    Image(systemName: "gauge.with.dots.needle.50percent")
                        .resizable()
                        .foregroundStyle(.tint)
                }
            }
            .scaledToFit()
            .frame(width: 128, height: 128)

            VStack(spacing: 4) {
                Text("Claudex").font(.largeTitle.bold())
                Text(version).foregroundStyle(.secondary)
            }

            VStack(spacing: 4) {
                Text("Your AI dev tools, unified in the menu bar.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Text("© 2026 Avi Teboul · MIT License")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    Button {
                        isChecking = true
                        checkResult = nil
                        Task {
                            let result = await UpdateChecker.shared.manualCheck()
                            checkResult = result
                            isChecking = false
                        }
                    } label: {
                        if isChecking {
                            HStack { ProgressView().controlSize(.small); Text("Checking…") }
                        } else {
                            Label("Check for updates", systemImage: "arrow.down.circle")
                        }
                    }
                    .disabled(isChecking)

                    Toggle("Auto-check daily", isOn: $autoCheck)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .onChange(of: autoCheck) { _, v in
                            AppSettings.checkForUpdatesAutomatically = v
                        }
                }

                if let checkResult {
                    Text(checkResult)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 400)
                }
            }

            HStack(spacing: 12) {
                Button {
                    if let url = URL(string: "https://github.com/jarodxxx/Claudex") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Label("View on GitHub", systemImage: "link")
                }
                Button {
                    if let url = URL(string: "https://github.com/jarodxxx/Claudex/issues") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Label("Report an issue", systemImage: "exclamationmark.bubble")
                }
            }

            Text("Inspired by ClaudeMeter (MIT) by Edd Mann.")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
