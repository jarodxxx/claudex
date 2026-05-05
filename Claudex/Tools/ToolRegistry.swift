import Foundation
import Combine

/// Single source of truth for which tools are enabled and in what order they
/// appear in the popover. Persisted to UserDefaults.
///
/// Categorisation rule: if the sum of `estimatedPopoverHeight` for all enabled
/// tools exceeds `categorizationThreshold`, the popover adds category headers
/// between sections so the user can skim faster.
@MainActor
final class ToolRegistry: ObservableObject {
    static let shared = ToolRegistry()

    /// Height (pt) above which category headers are injected.
    static let categorizationThreshold: CGFloat = 500

    @Published private(set) var enabledIDs: [ToolID]

    var all: [ToolDefinition] { ToolID.allCases.map(\.definition) }

    var enabled: [ToolDefinition] {
        enabledIDs.compactMap { id in all.first { $0.id == id } }
    }

    var shouldCategorize: Bool {
        enabled.map(\.estimatedPopoverHeight).reduce(0, +) > Self.categorizationThreshold
    }

    func isEnabled(_ id: ToolID) -> Bool { enabledIDs.contains(id) }

    func setEnabled(_ id: ToolID, _ on: Bool) {
        guard on != isEnabled(id) else { return }
        if on {
            // Insert in canonical order (ToolID.allCases order)
            let ordered = ToolID.allCases.filter { enabledIDs.contains($0) || $0 == id }
            enabledIDs = ordered
        } else {
            guard enabledIDs.count > 1 else { return }  // always keep ≥ 1
            enabledIDs.removeAll { $0 == id }
        }
        persist()
    }

    // MARK: - Init / persistence

    private static let defaultsKey = "enabledToolIDs"

    private init() {
        if let raw = UserDefaults.standard.stringArray(forKey: Self.defaultsKey),
           !raw.isEmpty {
            enabledIDs = raw.compactMap(ToolID.init(rawValue:))
        } else {
            // Default: all tools enabled
            enabledIDs = ToolID.allCases
        }
    }

    private func persist() {
        UserDefaults.standard.set(enabledIDs.map(\.rawValue), forKey: Self.defaultsKey)
    }
}
