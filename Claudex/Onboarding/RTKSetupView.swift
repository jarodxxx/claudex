import SwiftUI

struct RTKSetupView: View {
    @State private var path: String = AppSettings.rtkBinaryPath ?? ProcessLocator.locate("rtk") ?? ""

    var body: some View {
        GroupBox(label: Label("RTK", systemImage: "bolt.fill")) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Auto-detected via `which rtk`. Override below if needed.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

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
        panel.directoryURL = URL(fileURLWithPath: "/usr/local/bin")
        if panel.runModal() == .OK, let url = panel.url {
            path = url.path
        }
    }
}
