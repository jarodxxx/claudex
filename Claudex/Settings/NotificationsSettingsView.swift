import SwiftUI

struct NotificationsSettingsView: View {
    @State private var enabled: Bool = AppSettings.notificationsEnabled
    @State private var warning: Double = AppSettings.warningThreshold
    @State private var critical: Double = AppSettings.criticalThreshold
    @State private var notifyReset: Bool = AppSettings.notifyOnSessionReset
    @State private var testResult: String?
    @State private var isTesting = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SettingsCard(title: "Enable notifications") {
                    Toggle(isOn: $enabled) {
                        VStack(alignment: .leading) {
                            Text("Get notified when usage thresholds are reached")
                                .font(.subheadline)
                            Text("Uses macOS Notification Center.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .toggleStyle(.switch)
                    .onChange(of: enabled) { _, v in AppSettings.notificationsEnabled = v }
                }

                SettingsCard(title: "Warning threshold") {
                    HStack {
                        Text("Notify when usage reaches")
                        Spacer()
                        Text("\(Int(warning))%")
                            .foregroundStyle(.orange)
                            .monospacedDigit()
                    }
                    Slider(value: $warning, in: 50...90, step: 5) {
                        EmptyView()
                    }
                    .tint(.orange)
                    .disabled(!enabled)
                    .onChange(of: warning) { _, v in
                        AppSettings.warningThreshold = v
                        if critical < v + 5 {
                            critical = min(100, v + 5)
                            AppSettings.criticalThreshold = critical
                        }
                    }
                }

                SettingsCard(title: "Critical threshold") {
                    HStack {
                        Text("Send urgent notification when usage reaches")
                        Spacer()
                        Text("\(Int(critical))%")
                            .foregroundStyle(.red)
                            .monospacedDigit()
                    }
                    Slider(value: $critical, in: 75...100, step: 5) {
                        EmptyView()
                    }
                    .tint(.red)
                    .disabled(!enabled)
                    .onChange(of: critical) { _, v in
                        AppSettings.criticalThreshold = v
                    }
                }

                SettingsCard(title: "Session reset") {
                    Toggle("Notify when usage limits reset", isOn: $notifyReset)
                        .toggleStyle(.switch)
                        .disabled(!enabled)
                        .onChange(of: notifyReset) { _, v in AppSettings.notifyOnSessionReset = v }
                }

                SettingsCard(title: "Test") {
                    Text("Make sure Claudex appears in System Settings → Notifications and is allowed to show alerts.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        Button {
                            isTesting = true
                            testResult = nil
                            Task {
                                let result = await UsageNotifier.sendTestNotification()
                                testResult = result
                                isTesting = false
                            }
                        } label: {
                            if isTesting {
                                HStack { ProgressView().controlSize(.small); Text("Testing…") }
                            } else {
                                Label("Send Test Notification", systemImage: "bell.badge")
                            }
                        }
                        .disabled(isTesting)

                        Button {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
                                NSWorkspace.shared.open(url)
                            }
                        } label: {
                            Label("Open System Settings", systemImage: "gear")
                        }
                    }
                    if let testResult {
                        Text(testResult)
                            .font(.caption)
                            .foregroundStyle(testResult.lowercased().contains("posted") ? .green : .orange)
                            .textSelection(.enabled)
                            .padding(.top, 4)
                    }
                }
            }
            .padding(.bottom, 12)
        }
    }
}
