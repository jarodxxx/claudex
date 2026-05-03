import XCTest
@testable import Claudex

final class ClaudeUsageTests: XCTestCase {
    func test_decode_matchesExportedSchema() throws {
        let json = """
        {
          "last_updated": "2025-12-24T07:30:00Z",
          "session_usage": { "reset_at": "2025-12-24T12:00:00Z", "utilization": 29.5 },
          "sonnet_usage":  { "reset_at": "2025-12-30T00:00:00Z", "utilization": 15 },
          "weekly_usage":  { "reset_at": "2025-12-30T00:00:00Z", "utilization": 45.2 }
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let usage = try decoder.decode(ClaudeUsage.self, from: Data(json.utf8))

        XCTAssertEqual(usage.sessionUsage.utilization, 29.5)
        XCTAssertEqual(usage.sonnetUsage?.utilization, 15)
        XCTAssertEqual(usage.weeklyUsage.utilization, 45.2)
    }

    func test_decode_withoutOptionalSonnet() throws {
        let json = """
        {
          "last_updated": "2025-12-24T07:30:00Z",
          "session_usage": { "reset_at": "2025-12-24T12:00:00Z", "utilization": 30 },
          "weekly_usage":  { "reset_at": "2025-12-30T00:00:00Z", "utilization": 50 }
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let usage = try decoder.decode(ClaudeUsage.self, from: Data(json.utf8))
        XCTAssertNil(usage.sonnetUsage)
    }

    func test_status_thresholds() {
        XCTAssertEqual(PeriodUsage(resetAt: .distantFuture, utilization: 50).status, .ok)
        XCTAssertEqual(PeriodUsage(resetAt: .distantFuture, utilization: 80).status, .warning)
        XCTAssertEqual(PeriodUsage(resetAt: .distantFuture, utilization: 95).status, .critical)
    }
}

