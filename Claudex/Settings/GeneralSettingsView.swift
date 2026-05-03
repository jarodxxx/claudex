import SwiftUI
import AppKit

struct GeneralSettingsView: View {
    @State private var refreshTick = 0
    @State private var refreshInterval: TimeInterval = AppSettings.refreshIntervalSeconds
    @State private var showSonnet: Bool = AppSettings.showSonnet
    @State private var iconStyle: IconStyle = AppSettings.iconStyle
    @State private var rtkPath: String = AppSettings.rtkBinaryPath ?? ProcessLocator.locate("rtk") ?? ""
    @State private var memPalacePath: String = AppSettings.memPalaceBinaryPath ?? ProcessLocator.locate("mempalace") ?? ""

    private static let intervals: [(label: String, seconds: TimeInterval)] = [
        ("1 minute", 60), ("5 minutes", 300), ("15 minutes", 900), ("30 minutes", 1800),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                claudeSection
                refreshSection
                displaySection
                rtkSection
                memPalaceSection
            }
            .padding(.bottom, 12)
        }
    }

    // MARK: - Claude

    private var claudeSection: some View {
        SettingsCard(title: "Claude") {
            let _ = refreshTick
            if KeychainStore.exists(.claudeSessionKey) {
                HStack {
                    Label("Connected", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Spacer()
                    Button("Sign out") {
                        try? KeychainStore.delete(.claudeSessionKey)
                        AppSettings.claudeOrgUUID = nil
                        refreshTick += 1
                        NotificationCenter.default.post(name: .claudexShouldRefresh, object: nil)
                    }
                }
            } else {
                Text("Not connected. Use the onboarding wizard or paste your sessionKey below.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ClaudeSetupView()
            }
        }
    }

    // MARK: - Refresh

    private var refreshSection: some View {
        SettingsCard(title: "Refresh interval") {
            Picker("Refresh every", selection: $refreshInterval) {
                ForEach(Self.intervals, id: \.seconds) { entry in
                    Text(entry.label).tag(entry.seconds)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: refreshInterval) { _, newValue in
                AppSettings.refreshIntervalSeconds = newValue
                NotificationCenter.default.post(name: .claudexShouldRefresh, object: nil)
            }
            Text("How often Claudex polls the API and shells out to rtk / mempalace.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Display

    private var displaySection: some View {
        SettingsCard(title: "Display") {
            Toggle("Show Sonnet usage in popover", isOn: $showSonnet)
                .onChange(of: showSonnet) { _, newValue in
                    AppSettings.showSonnet = newValue
                }

            Divider().padding(.vertical, 4)

            Text("Menu bar icon style")
                .font(.subheadline.bold())
            Text("Choose how usage is rendered in the menu bar.")
                .font(.caption)
                .foregroundStyle(.secondary)
            IconStylePicker(selection: $iconStyle)
        }
    }

    // MARK: - RTK

    private var rtkSection: some View {
        SettingsCard(title: "RTK") {
            Text("Path to the `rtk` binary. Auto-detected via `which rtk`.")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                TextField("/opt/homebrew/bin/rtk", text: $rtkPath)
                    .textFieldStyle(.roundedBorder)
                Button("Choose…") { pickBinary(into: $rtkPath) }
                Button("Save") {
                    AppSettings.rtkBinaryPath = rtkPath.isEmpty ? nil : rtkPath
                    NotificationCenter.default.post(name: .claudexShouldRefresh, object: nil)
                }
                .disabled(rtkPath.isEmpty)
            }
        }
    }

    // MARK: - MemPalace

    private var memPalaceSection: some View {
        SettingsCard(title: "MemPalace") {
            Text("Path to the `mempalace` binary. Auto-detected via `which mempalace`.")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                TextField("/opt/homebrew/bin/mempalace", text: $memPalacePath)
                    .textFieldStyle(.roundedBorder)
                Button("Choose…") { pickBinary(into: $memPalacePath) }
                Button("Save") {
                    AppSettings.memPalaceBinaryPath = memPalacePath.isEmpty ? nil : memPalacePath
                    NotificationCenter.default.post(name: .claudexShouldRefresh, object: nil)
                }
                .disabled(memPalacePath.isEmpty)
            }
        }
    }

    private func pickBinary(into binding: Binding<String>) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            binding.wrappedValue = url.path
        }
    }
}

struct SettingsCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
        )
    }
}
