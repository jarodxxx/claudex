import SwiftUI
import AppKit

struct GeneralSettingsView: View {
    @ObservedObject private var registry = ToolRegistry.shared

    @State private var refreshTick = 0
    @State private var refreshInterval: TimeInterval = AppSettings.refreshIntervalSeconds
    @State private var showSonnet: Bool = AppSettings.showSonnet
    @State private var iconStyle: IconStyle = AppSettings.iconStyle
    @State private var launchAtLogin: Bool = LaunchAtLogin.isEnabled

    private static let intervals: [(label: String, seconds: TimeInterval)] = [
        ("1 minute", 60), ("5 minutes", 300), ("15 minutes", 900), ("30 minutes", 1800),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                claudeSection
                refreshSection
                startupSection
                displaySection
                toolsSection
            }
            .padding(.bottom, 12)
        }
    }

    // MARK: - Startup

    private var startupSection: some View {
        SettingsCard(title: "Startup") {
            Toggle("Launch Claudex at login", isOn: $launchAtLogin)
                .toggleStyle(.switch)
                .onChange(of: launchAtLogin) { _, newValue in
                    let ok = LaunchAtLogin.setEnabled(newValue)
                    if !ok {
                        // Revert the toggle if SMAppService rejected the change
                        // (typically the user denied in System Settings).
                        launchAtLogin = LaunchAtLogin.isEnabled
                    }
                }
            Text("Claudex re-opens automatically each time you log in to macOS.")
                .font(.caption)
                .foregroundStyle(.secondary)
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

    // MARK: - Tools toggle

    private var toolsSection: some View {
        SettingsCard(title: "Tools") {
            Text("Choose which tools appear in the popover. At least one must stay enabled.")
                .font(.caption).foregroundStyle(.secondary)

            ForEach(ToolCategory.allCases) { cat in
                let catTools = ToolID.allCases.filter { $0.definition.category == cat }
                if !catTools.isEmpty {
                    Text(cat.rawValue).font(.caption.bold()).foregroundStyle(.secondary)
                        .padding(.top, 4)
                    ForEach(catTools) { toolID in
                        let def = toolID.definition
                        HStack {
                            Image(systemName: def.icon).frame(width: 18)
                            Text(def.name)
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { registry.isEnabled(toolID) },
                                set: { registry.setEnabled(toolID, $0) }
                            ))
                            .toggleStyle(.switch)
                            .labelsHidden()
                        }
                        .font(.subheadline)
                    }
                }
            }
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
