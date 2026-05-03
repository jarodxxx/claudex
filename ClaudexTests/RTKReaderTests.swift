import XCTest
@testable import Claudex

final class FakeProcessRunner: ProcessRunning {
    var stubbedOutput: ProcessOutput
    var lastExecutable: String?
    var lastArguments: [String]?

    init(stubbedOutput: ProcessOutput) {
        self.stubbedOutput = stubbedOutput
    }

    func run(executable: String, arguments: [String]) throws -> ProcessOutput {
        lastExecutable = executable
        lastArguments = arguments
        return stubbedOutput
    }
}

final class RTKReaderTests: XCTestCase {
    func test_fetchStats_parsesValidJSON() throws {
        let json = """
        {
          "summary": {
            "total_commands": 637,
            "total_input": 751572,
            "total_output": 544293,
            "total_saved": 207770,
            "avg_savings_pct": 27.6,
            "total_time_ms": 3443431,
            "avg_time_ms": 5405
          }
        }
        """
        let runner = FakeProcessRunner(stubbedOutput: ProcessOutput(
            exitCode: 0,
            stdout: Data(json.utf8),
            stderr: Data()
        ))

        let reader = RTKReader(binaryPath: "/usr/local/bin/rtk", runner: runner)
        let stats = try reader.fetchStats()

        XCTAssertEqual(stats.summary.totalCommands, 637)
        XCTAssertEqual(stats.summary.totalSaved, 207770)
        XCTAssertEqual(stats.summary.avgSavingsPct, 27.6)
        XCTAssertEqual(runner.lastExecutable, "/usr/local/bin/rtk")
        XCTAssertEqual(runner.lastArguments, ["gain", "--all", "--format", "json"])
    }

    func test_fetchStats_parsesFullPayloadWithDailyAndWeekly() throws {
        let json = """
        {
          "summary": {
            "total_commands": 100, "total_input": 1000, "total_output": 800,
            "total_saved": 200, "avg_savings_pct": 20.0
          },
          "daily": [
            {"date": "2026-05-01", "commands": 50, "input_tokens": 500,
             "output_tokens": 400, "saved_tokens": 100, "savings_pct": 20.0}
          ],
          "weekly": [
            {"week_start": "2026-04-27", "week_end": "2026-05-03",
             "commands": 100, "input_tokens": 1000, "output_tokens": 800,
             "saved_tokens": 200, "savings_pct": 20.0}
          ]
        }
        """
        let runner = FakeProcessRunner(stubbedOutput: ProcessOutput(
            exitCode: 0, stdout: Data(json.utf8), stderr: Data()
        ))
        let stats = try RTKReader(binaryPath: "/p", runner: runner).fetchStats()
        XCTAssertEqual(stats.daily?.count, 1)
        XCTAssertEqual(stats.daily?.first?.date, "2026-05-01")
        XCTAssertEqual(stats.weekly?.first?.weekEnd, "2026-05-03")
    }

    func test_fetchStats_throwsOnNonZeroExit() {
        let runner = FakeProcessRunner(stubbedOutput: ProcessOutput(
            exitCode: 1,
            stdout: Data(),
            stderr: Data("rtk: not configured".utf8)
        ))
        let reader = RTKReader(binaryPath: "/usr/local/bin/rtk", runner: runner)

        XCTAssertThrowsError(try reader.fetchStats()) { error in
            guard case .nonZeroExit(let code, let stderr) = error as? RTKReaderError else {
                XCTFail("expected nonZeroExit, got \(error)")
                return
            }
            XCTAssertEqual(code, 1)
            XCTAssertEqual(stderr, "rtk: not configured")
        }
    }

    func test_fetchStats_throwsOnInvalidJSON() {
        let runner = FakeProcessRunner(stubbedOutput: ProcessOutput(
            exitCode: 0,
            stdout: Data("not json".utf8),
            stderr: Data()
        ))
        let reader = RTKReader(binaryPath: "/usr/local/bin/rtk", runner: runner)

        XCTAssertThrowsError(try reader.fetchStats()) { error in
            guard case .decodingFailed = error as? RTKReaderError else {
                XCTFail("expected decodingFailed, got \(error)")
                return
            }
        }
    }
}
