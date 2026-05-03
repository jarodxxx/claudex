import SwiftUI

struct MemPalaceSetupView: View {
    @State private var path: String = AppSettings.memPalaceBinaryPath ?? ProcessLocator.locate("mempalace") ?? ""

    var body: some View {
        GroupBox(label: Label("MemPalace", systemImage: "books.vertical.fill")) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Auto-detected via `which mempalace`. Override below if needed.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    TextField("/opt/homebrew/bin/mempalace", text: $path)
                        .textFieldStyle(.roundedBorder)
                    Button("Choose…") { pickBinary() }
                }

                HStack {
                    Button("Save") {
                        AppSettings.memPalaceBinaryPath = path.isEmpty ? nil : path
                    }
                    .disabled(path.isEmpty)
                    Spacer()
                    if !path.isEmpty {
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
