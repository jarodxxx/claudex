import AppKit
import Combine

/// Polls `NSPasteboard.general` for a Claude `sessionKey` value (sk-ant-...).
///
/// `NSPasteboard` doesn't expose a change notification, so we poll on a 1s
/// timer. Only emits when the pasteboard contents actually change AND look
/// like a valid session key.
@MainActor
final class ClipboardWatcher: ObservableObject {
    @Published private(set) var detectedKey: String?

    private var lastChangeCount: Int
    private var timer: AnyCancellable?

    init() {
        self.lastChangeCount = NSPasteboard.general.changeCount
    }

    func start() {
        timer = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.poll()
            }
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    func dismissDetectedKey() {
        detectedKey = nil
    }

    private func poll() {
        let pb = NSPasteboard.general
        guard pb.changeCount != lastChangeCount else { return }
        lastChangeCount = pb.changeCount

        guard let value = pb.string(forType: .string) else { return }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix(ClaudeAuth.sessionKeyPrefix),
              trimmed.count > ClaudeAuth.sessionKeyPrefix.count + 20 else {
            return
        }
        detectedKey = trimmed
    }
}
