import XCTest
@testable import Claudex

final class KeychainStoreTests: XCTestCase {
    override func setUp() {
        super.setUp()
        try? KeychainStore.delete(.claudeSessionKey)
    }

    override func tearDown() {
        try? KeychainStore.delete(.claudeSessionKey)
        super.tearDown()
    }

    func test_save_then_read_returnsSameValue() throws {
        let value = "sk-ant-test-value-123"
        try KeychainStore.save(value, for: .claudeSessionKey)
        let read = try KeychainStore.read(.claudeSessionKey)
        XCTAssertEqual(read, value)
    }

    func test_save_overwrites_existingValue() throws {
        try KeychainStore.save("sk-ant-old", for: .claudeSessionKey)
        try KeychainStore.save("sk-ant-new", for: .claudeSessionKey)
        XCTAssertEqual(try KeychainStore.read(.claudeSessionKey), "sk-ant-new")
    }

    func test_read_throws_whenItemNotFound() {
        XCTAssertThrowsError(try KeychainStore.read(.claudeSessionKey)) { error in
            XCTAssertEqual(error as? KeychainError, .itemNotFound)
        }
    }

    func test_exists_reflectsState() throws {
        XCTAssertFalse(KeychainStore.exists(.claudeSessionKey))
        try KeychainStore.save("sk-ant-x", for: .claudeSessionKey)
        XCTAssertTrue(KeychainStore.exists(.claudeSessionKey))
        try KeychainStore.delete(.claudeSessionKey)
        XCTAssertFalse(KeychainStore.exists(.claudeSessionKey))
    }
}
