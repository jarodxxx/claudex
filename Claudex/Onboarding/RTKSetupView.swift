import SwiftUI

struct RTKSetupView: View {
    @State private var path: String = AppSettings.rtkBinaryPath ?? ProcessLocator.locate("rtk") ?? ""

    private var isDetected: Bool { !path.isEmpty }

    var body: some View {
        GroupBox(label: Label("RTK", systemImage: "bolt.fill")) {
            VStack(alignment: .leading, spacing: 8) {
                if isDetected {
                    Text("Auto-detected via `which rtk`. Override below if needed.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    notInstalledHelp
                }

                HStack {
                    TextField("/usr/local/bin/rtk", text: $path)
                        .textFieldStyle(.roundedBorder)
                    Button("Choose…") { pickBinary() }
                }

                HStack {
                    Button("Save") {
                        AppSettings.rtkBinaryPath = path.isEmpty ? nil : path
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
            Text("RTK is not installed on this Mac. It's a CLI proxy that compresses bash output to save 60–90% of LLM tokens.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Button {
                    if let url = URL(string: "https://github.com/rtk-ai/rtk#installation") {
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
                    pasteboard.setString("brew install rtk", forType: .string)
                } label: {
                    Label("Copy `brew install rtk`", systemImage: "doc.on.clipboard")
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
        panel.directoryURL = URL(fileURLWithPath: "/usr/local/bin")
        if panel.runModal() == .OK, let url = panel.url {
            path = url.path
        }
    }
}
