import XCTest
@testable import Claudex

final class MemPalaceReaderTests: XCTestCase {
    private let realSample = """

    =======================================================
      MemPalace Status — 30486 drawers
    =======================================================

      WING: certi-files
        ROOM: general               9767 drawers

      WING: diag-pilote
        ROOM: general               6379 drawers

      WING: france-erp
        ROOM: general              12635 drawers

      WING: juripulse
        ROOM: general                210 drawers

      WING: scan-pilote
        ROOM: general               1495 drawers

    =======================================================

    """

    func test_parse_realStatusOutput() throws {
        let stats = try MemPalaceReader.parse(realSample)

        XCTAssertEqual(stats.totalDrawers, 30486)
        XCTAssertEqual(stats.wings.count, 5)

        let firstWing = try XCTUnwrap(stats.wings.first)
        XCTAssertEqual(firstWing.name, "certi-files")
        XCTAssertEqual(firstWing.rooms.first?.name, "general")
        XCTAssertEqual(firstWing.rooms.first?.drawers, 9767)
        XCTAssertEqual(firstWing.totalDrawers, 9767)

        let franceErp = try XCTUnwrap(stats.wings.first(where: { $0.name == "france-erp" }))
        XCTAssertEqual(franceErp.totalDrawers, 12635)
    }

    func test_fetchStats_passesStatusArgument() throws {
        let runner = FakeProcessRunner(stubbedOutput: ProcessOutput(
            exitCode: 0,
            stdout: Data(realSample.utf8),
            stderr: Data()
        ))
        let reader = MemPalaceReader(binaryPath: "/opt/homebrew/bin/mempalace", runner: runner)
        let stats = try reader.fetchStats()

        XCTAssertEqual(runner.lastArguments, ["status"])
        XCTAssertEqual(stats.totalDrawers, 30486)
    }

    func test_fetchStats_throwsOnNonZeroExit() {
        let runner = FakeProcessRunner(stubbedOutput: ProcessOutput(
            exitCode: 2,
            stdout: Data(),
            stderr: Data("not initialized".utf8)
        ))
        let reader = MemPalaceReader(binaryPath: "/opt/homebrew/bin/mempalace", runner: runner)

        XCTAssertThrowsError(try reader.fetchStats()) { error in
            guard case .nonZeroExit = error as? MemPalaceReaderError else {
                XCTFail("expected nonZeroExit, got \(error)")
                return
            }
        }
    }

    func test_parse_throwsOnEmptyOutput() {
        XCTAssertThrowsError(try MemPalaceReader.parse("")) { error in
            guard case .unparseableOutput = error as? MemPalaceReaderError else {
                XCTFail("expected unparseableOutput, got \(error)")
                return
            }
        }
    }
}
