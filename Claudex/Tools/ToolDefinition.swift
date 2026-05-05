import Foundation

enum ToolCategory: String, CaseIterable, Identifiable {
    case usageMonitoring   = "Usage Monitoring"
    case tokenOptimization = "Token Optimization"
    case memory            = "Memory"

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .usageMonitoring:   return "chart.bar"
        case .tokenOptimization: return "bolt.fill"
        case .memory:            return "books.vertical.fill"
        }
    }
}

enum ToolID: String, CaseIterable, Identifiable {
    case claude    = "claude"
    case rtk       = "rtk"
    case caveman   = "caveman"
    case mempalace = "mempalace"

    var id: String { rawValue }

    var definition: ToolDefinition {
        switch self {
        case .claude:
            return ToolDefinition(
                id: self,
                name: "Claude",
                icon: "brain.head.profile",
                category: .usageMonitoring,
                estimatedPopoverHeight: 150,
                requiresBinary: false
            )
        case .rtk:
            return ToolDefinition(
                id: self,
                name: "RTK",
                icon: "bolt.fill",
                category: .tokenOptimization,
                estimatedPopoverHeight: 95,
                requiresBinary: true
            )
        case .caveman:
            return ToolDefinition(
                id: self,
                name: "Caveman",
                icon: "hammer.fill",
                category: .tokenOptimization,
                estimatedPopoverHeight: 75,
                requiresBinary: true
            )
        case .mempalace:
            return ToolDefinition(
                id: self,
                name: "MemPalace",
                icon: "books.vertical.fill",
                category: .memory,
                estimatedPopoverHeight: 125,
                requiresBinary: true
            )
        }
    }
}

struct ToolDefinition {
    let id: ToolID
    let name: String
    let icon: String
    let category: ToolCategory
    /// Estimated vertical space this tool occupies in the popover (pt).
    /// Used to decide whether category headers should be shown.
    let estimatedPopoverHeight: CGFloat
    /// True for tools invoked via a local binary (rtk, caveman, mempalace).
    /// False for API-based tools (claude).
    let requiresBinary: Bool
}
