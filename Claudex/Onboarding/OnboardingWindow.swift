import AppKit
import SwiftUI

@MainActor
final class OnboardingWindow {
    private let window: NSWindow
    private let onFinish: () -> Void

    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
        let view = OnboardingView(onFinish: onFinish)
        let hostingController = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Welcome to Claudex"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 600, height: 500))
        window.isReleasedWhenClosed = false
        window.center()
        self.window = window
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func close() {
        window.close()
    }
}

struct OnboardingView: View {
    let onFinish: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Connect your services")
                .font(.title2.bold())

            ScrollView {
                VStack(spacing: 12) {
                    ClaudeSetupView()
                    RTKSetupView()
                    MemPalaceSetupView()
                }
                .padding(.horizontal, 4)
            }

            HStack {
                Spacer()
                Button("Finish") {
                    AppSettings.onboardingCompleted = true
                    onFinish()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
    }
}
