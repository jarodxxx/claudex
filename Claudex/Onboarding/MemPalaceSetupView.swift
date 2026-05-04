import SwiftUI

struct MemPalaceSetupView: View {
    @State private var path: String = AppSettings.memPalaceBinaryPath ?? ProcessLocator.locate("mempalace") ?? ""

    private var isDetected: Bool { !path.isEmpty }

    var body: some View {
        GroupBox(label: Label("MemPalace", systemImage: "books.vertical.fill")) {
            VStack(alignment: .leading, spacing: 8) {
                if isDetected {
                    Text("Auto-detected via `which mempalace`. Override below if needed.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    notInstalledHelp
                }

                HStack {
                    TextField("/opt/homebrew/bin/mempalace", text: $path)
                        .textFieldStyle(.roundedBorder)
                    Button("Choose…") { pickBinary() }
                }

                HStack {
                    Button("Save") {
                        AppSettings.memPalaceBinaryPath = path.isEmpty ? nil : path
                        NotificationCenter.default.post(name: .claudexShouldRefresh, object: nil)
                    }
                    .disabled(path.isEmpty)
                    Spacer()
                    if isDetected {
                        Label("Detected", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                    } else {
                        Label("Not found", systemImage: "questionmark.circle")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                }
            }
            .padding(8)
        }
    }

    private var notInstalledHelp: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("MemPalace is not installed on this Mac. It's a local-first AI memory that stores your Claude Code sessions verbatim and retrieves them by semantic search.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Button {
                    if let url = URL(string: "https://github.com/mempalace/mempalace#install") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Label("Install instructions", systemImage: "arrow.up.right.square")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                Button {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString("pip install mempalace", forType: .string)
                } label: {
                    Label("Copy `pip install mempalace`", systemImage: "doc.on.clipboard")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
            }
        }
    }

    private func pickBinary() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: "/opt/homebrew/bin")
        if panel.runModal() == .OK, let url = panel.url {
            path = url.path
        }
    }
}
