import SwiftUI
import AppKit

struct AboutSettingsView: View {
    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "0.1.0"
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
                Text("Aggregate Claude.ai, RTK and mempalace usage in your menu bar.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Text("© 2026 Avi Teboul · MIT License")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
