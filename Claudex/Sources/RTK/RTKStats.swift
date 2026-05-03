import Foundation

/// Top-level shape of `rtk gain --all --format json`. We only consume the
/// `summary` block in the popover; the historical breakdowns are kept as
/// optional fields for future enhancements (charts, dashboards).
struct RTKStats: Codable, Equatable {
    let summary: RTKSummary
    let daily: [RTKPeriod]?
    let weekly: [RTKWeeklyPeriod]?
    let monthly: [RTKMonthlyPeriod]?
}

struct RTKSummary: Codable, Equatable {
    let totalCommands: Int
    let totalInput: Int
    let totalOutput: Int
    let totalSaved: Int
    let avgSavingsPct: Double
    let totalTimeMs: Int?
    let avgTimeMs: Int?

    enum CodingKeys: String, CodingKey {
        case totalCommands = "total_commands"
        case totalInput = "total_input"
        case totalOutput = "total_output"
        case totalSaved = "total_saved"
        case avgSavingsPct = "avg_savings_pct"
        case totalTimeMs = "total_time_ms"
        case avgTimeMs = "avg_time_ms"
    }
}

struct RTKPeriod: Codable, Equatable {
    let date: String
    let commands: Int
    let inputTokens: Int
    let outputTokens: Int
    let savedTokens: Int
    let savingsPct: Double

    enum CodingKeys: String, CodingKey {
        case date
        case commands
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case savedTokens = "saved_tokens"
        case savingsPct = "savings_pct"
    }
}

struct RTKWeeklyPeriod: Codable, Equatable {
    let weekStart: String
    let weekEnd: String
    let commands: Int
    let inputTokens: Int
    let outputTokens: Int
    let savedTokens: Int
    let savingsPct: Double

    enum CodingKeys: String, CodingKey {
        case weekStart = "week_start"
        case weekEnd = "week_end"
        case commands
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case savedTokens = "saved_tokens"
        case savingsPct = "savings_pct"
    }
}

struct RTKMonthlyPeriod: Codable, Equatable {
    let month: String
    let commands: Int
    let inputTokens: Int
    let outputTokens: Int
    let savedTokens: Int
    let savingsPct: Double

    enum CodingKeys: String, CodingKey {
        case month
        case commands
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case savedTokens = "saved_tokens"
        case savingsPct = "savings_pct"
    }
}
