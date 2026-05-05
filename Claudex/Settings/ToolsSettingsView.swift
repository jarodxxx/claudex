import SwiftUI
import AppKit

struct ToolsSettingsView: View {
    @State private var rtkPath: String = AppSettings.rtkBinaryPath ?? ProcessLocator.locate("rtk") ?? ""
    @State private var memPalacePath: String = AppSettings.memPalaceBinaryPath ?? ProcessLocator.locate("mempalace") ?? ""
    @State private var claudeProjectsPath: String = AppSettings.claudeProjectsPath

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                cavemanSection
                rtkSection
                memPalaceSection
            }
            .padding(.bottom, 12)
        }
    }

    // MARK: - Caveman

    private var cavemanSection: some View {
        SettingsCard(title: "Caveman") {
            VStack(alignment: .leading, spacing: 6) {
                Text("Caveman stats are read directly from Claude Code session files — no binary required.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Sessions folder").font(.caption.bold()).padding(.top, 4)
                HStack {
                    TextField("~/.claude/projects", text: $claudeProjectsPath)
                        .textFieldStyle(.roundedBorder)
                    Button("Choose…") { pickFolder(into: $claudeProjectsPath) }
                    Button("Save") {
                        AppSettings.claudeProjectsPath = claudeProjectsPath
                        NotificationCenter.default.post(name: .claudexShouldRefresh, object: nil)
                    }
                    Button("Reset") {
                        claudeProjectsPath = AppSettings.defaultClaudeProjectsPath
                        AppSettings.claudeProjectsPath = claudeProjectsPath
                    }
                }
                Text("Claudex reads session JSONL files from the last 24 h to compute token deltas.")
                    .font(.caption2).foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - RTK

    private var rtkSection: some View {
        SettingsCard(title: "RTK") {
            binaryRow(
                label: "rtk binary",
                placeholder: "/opt/homebrew/bin/rtk",
                installURL: "https://github.com/rtk-ai/rtk#installation",
                path: $rtkPath
            ) {
                AppSettings.rtkBinaryPath = rtkPath.isEmpty ? nil : rtkPath
                NotificationCenter.default.post(name: .claudexShouldRefresh, object: nil)
            }
        }
    }

    // MARK: - MemPalace

    private var memPalaceSection: some View {
        SettingsCard(title: "MemPalace") {
            binaryRow(
                label: "mempalace binary",
                placeholder: "/opt/homebrew/bin/mempalace",
                installURL: "https://github.com/mempalace/mempalace#install",
                path: $memPalacePath
            ) {
                AppSettings.memPalaceBinaryPath = memPalacePath.isEmpty ? nil : memPalacePath
                NotificationCenter.default.post(name: .claudexShouldRefresh, object: nil)
            }
        }
    }

    // MARK: - Helpers

    private func binaryRow(
        label: String,
        placeholder: String,
        installURL: String,
        path: Binding<String>,
        onSave: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label).font(.caption.bold())
                Spacer()
                if path.wrappedValue.isEmpty {
                    Button("Install instructions") {
                        if let url = URL(string: installURL) { NSWorkspace.shared.open(url) }
                    }
                    .font(.caption).buttonStyle(.borderless)
                }
            }
            HStack {
                TextField(placeholder, text: path).textFieldStyle(.roundedBorder)
                Button("…") { pickBinary(into: path) }
                Button("Save") { onSave() }.disabled(path.wrappedValue.isEmpty)
            }
            if !path.wrappedValue.isEmpty {
                Label("Detected", systemImage: "checkmark.circle.fill")
                    .font(.caption2).foregroundStyle(.green)
            }
        }
    }

    private func pickBinary(into binding: Binding<String>) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true; panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url { binding.wrappedValue = url.path }
    }

    private func pickFolder(into binding: Binding<String>) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false; panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url { binding.wrappedValue = url.path }
    }
}
