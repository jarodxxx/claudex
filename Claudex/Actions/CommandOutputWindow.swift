import AppKit
import SwiftUI

@MainActor
final class CommandOutputWindow {
    private static var openWindows: [CommandOutputWindow] = []

    private let window: NSWindow

    static func show(title: String, output: String) {
        let instance = CommandOutputWindow(title: title, output: output)
        instance.present()
        openWindows.append(instance)
    }

    static func showWithRelaunch(title: String, output: String) {
        let instance = CommandOutputWindow(title: title, output: output, showRelaunch: true)
        instance.present()
        openWindows.append(instance)
    }

    private init(title: String, output: String, showRelaunch: Bool = false) {
        let view = CommandOutputView(title: title, output: output, showRelaunch: showRelaunch)
        let hostingController = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hostingController)
        window.title = title
        window.styleMask = [.titled, .closable, .resizable]
        window.setContentSize(NSSize(width: 720, height: 480))
        window.isReleasedWhenClosed = false
        window.center()
        self.window = window
    }

    private func present() {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}

private struct CommandOutputView: View {
    let title: String
    let output: String
    var showRelaunch: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            ScrollView {
                Text(output.isEmpty ? "(no output)" : output)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(6)

            HStack {
                Spacer()
                Button("Close") {
                    NSApp.keyWindow?.close()
                }
                .keyboardShortcut(.cancelAction)

                if showRelaunch {
                    Button("Relaunch") {
                        relaunch()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(16)
    }

    private func relaunch() {
        // Prefer the standard Homebrew cask install path; fall back to current bundle.
        let appPath = FileManager.default.fileExists(atPath: "/Applications/Claudex.app")
            ? "/Applications/Claudex.app"
            : Bundle.main.bundlePath
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = [appPath]
        try? task.run()
        NSApp.terminate(nil)
    }
}
