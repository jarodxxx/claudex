import XCTest
@testable import Claudex

final class ClaudeAuthTests: XCTestCase {
    func test_validate_acceptsValidPrefix() {
        XCTAssertNoThrow(try ClaudeAuth.validate("sk-ant-abcdef123"))
    }

    func test_validate_rejectsMissingPrefix() {
        XCTAssertThrowsError(try ClaudeAuth.validate("abcdef")) { error in
            XCTAssertEqual(error as? ClaudeAuthError, .invalidFormat)
        }
    }

    func test_validate_rejectsPrefixOnly() {
        XCTAssertThrowsError(try ClaudeAuth.validate("sk-ant-")) { error in
            XCTAssertEqual(error as? ClaudeAuthError, .invalidFormat)
        }
    }

    func test_validate_trimsWhitespace() {
        XCTAssertNoThrow(try ClaudeAuth.validate("  sk-ant-padded  "))
    }

    func test_mask_keepsPrefixOnly() {
        let masked = ClaudeAuth.mask("sk-ant-supersecretvalue")
        XCTAssertEqual(masked, "sk-ant-****")
    }
}

