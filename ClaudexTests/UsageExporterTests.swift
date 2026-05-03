import XCTest
@testable import Claudex

final class UsageExporterTests: XCTestCase {
    private var fileURL: URL { UsageExporter.fileURL }

    override func setUp() {
        super.setUp()
        try? FileManager.default.removeItem(at: fileURL)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: fileURL)
        super.tearDown()
    }

    func test_write_createsFile_withClaudeAndRTKSections() throws {
        let claudeJSON = """
        {
          "last_updated": "2026-01-01T10:00:00Z",
          "session_usage": { "reset_at": "2026-01-01T15:00:00Z", "utilization": 30 },
          "sonnet_usage":  { "reset_at": "2026-01-08T00:00:00Z", "utilization": 20 },
          "weekly_usage":  { "reset_at": "2026-01-08T00:00:00Z", "utilization": 50 }
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let usage = try decoder.decode(ClaudeUsage.self, from: Data(claudeJSON.utf8))
        let rtk = RTKStats(
            summary: RTKSummary(
                totalCommands: 100, totalInput: 1000, totalOutput: 800,
                totalSaved: 200, avgSavingsPct: 20.0,
                totalTimeMs: nil, avgTimeMs: nil
            ),
            daily: nil, weekly: nil, monthly: nil
        )

        let stats = AggregatedStats(claude: .success(usage), rtk: .success(rtk), memPalace: nil)
        UsageExporter.write(stats)

        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))

        let data = try Data(contentsOf: fileURL)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertNotNil(json?["claude"])
        XCTAssertNotNil(json?["rtk"])
        XCTAssertNil(json?["mempalace"])
        XCTAssertNotNil(json?["last_updated"])
    }

    func test_write_omitsFailedSections() {
        let stats = AggregatedStats(
            claude: .failure(NSError(domain: "test", code: 1)),
            rtk: nil,
            memPalace: nil
        )
        UsageExporter.write(stats)

        let data = try? Data(contentsOf: fileURL)
        let json = (data.flatMap { try? JSONSerialization.jsonObject(with: $0) }) as? [String: Any]
        XCTAssertNil(json?["claude"])
        XCTAssertNil(json?["rtk"])
        XCTAssertNil(json?["mempalace"])
    }
}
