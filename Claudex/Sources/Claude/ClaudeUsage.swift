import Foundation

struct ClaudeUsage: Codable, Equatable {
    let lastUpdated: Date
    let sessionUsage: PeriodUsage
    let sonnetUsage: PeriodUsage?
    let weeklyUsage: PeriodUsage

    enum CodingKeys: String, CodingKey {
        case lastUpdated = "last_updated"
        case sessionUsage = "session_usage"
        case sonnetUsage = "sonnet_usage"
        case weeklyUsage = "weekly_usage"
    }
}

struct PeriodUsage: Codable, Equatable {
    let resetAt: Date
    let utilization: Double

    enum CodingKeys: String, CodingKey {
        case resetAt = "reset_at"
        case utilization
    }

    var status: UsageStatus {
        switch utilization {
        case ..<75: return .ok
        case 75..<90: return .warning
        default: return .critical
        }
    }
}

enum UsageStatus: Equatable {
    case ok, warning, critical
}
