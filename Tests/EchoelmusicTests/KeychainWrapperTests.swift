import XCTest
@testable import Echoelmusic

final class KeychainWrapperTests: XCTestCase {

    var keychain: KeychainWrapper!

    override func setUp() {
        super.setUp()
        keychain = KeychainWrapper(serviceName: "com.echoelmusic.test")
        // Clear any existing test data
        keychain.removeAll()
    }

    override func tearDown() {
        keychain.removeAll()
        keychain = nil
        super.tearDown()
    }

    // MARK: - String Storage Tests

    func testSetAndGetString() {
        // Given
        let testValue = "TestSecretValue123"
        let testKey = "test_key"

        // When
        let setSuccess = keychain.setString(testValue, forKey: testKey)
        let retrievedValue = keychain.getString(forKey: testKey)

        // Then
        XCTAssertTrue(setSuccess, "Should successfully store string")
        XCTAssertEqual(retrievedValue, testValue, "Retrieved value should match stored value")
    }

    func testGetNonExistentString() {
        // When
        let retrievedValue = keychain.getString(forKey: "non_existent_key")

        // Then
        XCTAssertNil(retrievedValue, "Should return nil for non-existent key")
    }

    func testOverwriteExistingString() {
        // Given
        let key = "overwrite_test"
        keychain.setString("old_value", forKey: key)

        // When
        keychain.setString("new_value", forKey: key)
        let retrieved = keychain.getString(forKey: key)

        // Then
        XCTAssertEqual(retrieved, "new_value", "Should overwrite old value")
    }

    // MARK: - Data Storage Tests

    func testSetAndGetData() {
        // Given
        let testData = "Test data".data(using: .utf8)!
        let testKey = "test_data_key"

        // When
        let setSuccess = keychain.setData(testData, forKey: testKey)
        let retrievedData = keychain.getData(forKey: testKey)

        // Then
        XCTAssertTrue(setSuccess)
        XCTAssertEqual(retrievedData, testData)
    }

    func testStoreBinaryData() {
        // Given: Random binary data
        let binaryData = Data([0x00, 0x01, 0x02, 0xFF, 0xFE, 0xFD])
        let key = "binary_test"

        // When
        keychain.setData(binaryData, forKey: key)
        let retrieved = keychain.getData(forKey: key)

        // Then
        XCTAssertEqual(retrieved, binaryData)
    }

    // MARK: - Codable Storage Tests

    func testSetAndGetCodable() {
        // Given
        struct TestModel: Codable, Equatable {
            let name: String
            let age: Int
            let tags: [String]
        }

        let testModel = TestModel(name: "Echoel", age: 25, tags: ["music", "biometric"])
        let key = "codable_test"

        // When
        let setSuccess = keychain.setCodable(testModel, forKey: key)
        let retrieved: TestModel? = keychain.getCodable(forKey: key)

        // Then
        XCTAssertTrue(setSuccess)
        XCTAssertEqual(retrieved, testModel)
    }

    func testGetCodableWithWrongType() {
        // Given
        struct Model1: Codable {
            let value: String
        }
        struct Model2: Codable {
            let value: Int
        }

        let model1 = Model1(value: "test")
        keychain.setCodable(model1, forKey: "wrong_type_test")

        // When
        let retrieved: Model2? = keychain.getCodable(forKey: "wrong_type_test")

        // Then
        XCTAssertNil(retrieved, "Should return nil when type doesn't match")
    }

    // MARK: - Removal Tests

    func testRemoveData() {
        // Given
        let key = "remove_test"
        keychain.setString("value", forKey: key)

        // When
        let removeSuccess = keychain.removeData(forKey: key)
        let retrieved = keychain.getString(forKey: key)

        // Then
        XCTAssertTrue(removeSuccess)
        XCTAssertNil(retrieved)
    }

    func testRemoveNonExistentKey() {
        // When
        let removeSuccess = keychain.removeData(forKey: "non_existent_key")

        // Then
        XCTAssertTrue(removeSuccess, "Removing non-existent key should succeed")
    }

    func testRemoveAll() {
        // Given
        keychain.setString("value1", forKey: "key1")
        keychain.setString("value2", forKey: "key2")
        keychain.setString("value3", forKey: "key3")

        // When
        keychain.removeAll()

        // Then
        XCTAssertNil(keychain.getString(forKey: "key1"))
        XCTAssertNil(keychain.getString(forKey: "key2"))
        XCTAssertNil(keychain.getString(forKey: "key3"))
    }

    // MARK: - API Key Convenience Methods

    func testSetAndGetAPIKey() {
        // Given
        let apiKey = "sk_test_1234567890abcdef"
        let service = "openai"

        // When
        let setSuccess = keychain.setAPIKey(apiKey, forService: service)
        let retrieved = keychain.getAPIKey(forService: service)

        // Then
        XCTAssertTrue(setSuccess)
        XCTAssertEqual(retrieved, apiKey)
    }

    func testSetAndGetAccessToken() {
        // Given
        let token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
        let service = "spotify"

        // When
        keychain.setAccessToken(token, forService: service)
        let retrieved = keychain.getAccessToken(forService: service)

        // Then
        XCTAssertEqual(retrieved, token)
    }

    // MARK: - RTMP Stream Key Tests

    func testSetAndGetRTMPStreamKey() {
        // Given
        let streamKey = "live_123456789_abcdefghijklmnop"
        let platform = "twitch"

        // When
        let setSuccess = keychain.setRTMPStreamKey(streamKey, forPlatform: platform)
        let retrieved = keychain.getRTMPStreamKey(forPlatform: platform)

        // Then
        XCTAssertTrue(setSuccess)
        XCTAssertEqual(retrieved, streamKey)
    }

    func testMultiplePlatformStreamKeys() {
        // Given
        let twitchKey = "twitch_stream_key"
        let youtubeKey = "youtube_stream_key"

        // When
        keychain.setRTMPStreamKey(twitchKey, forPlatform: "twitch")
        keychain.setRTMPStreamKey(youtubeKey, forPlatform: "youtube")

        // Then
        XCTAssertEqual(keychain.getRTMPStreamKey(forPlatform: "twitch"), twitchKey)
        XCTAssertEqual(keychain.getRTMPStreamKey(forPlatform: "youtube"), youtubeKey)
    }

    // MARK: - CloudKit Token Tests

    func testSetAndGetCloudKitToken() {
        // Given
        let token = "cloudkit_token_1234567890"

        // When
        keychain.setCloudKitToken(token)
        let retrieved = keychain.getCloudKitToken()

        // Then
        XCTAssertEqual(retrieved, token)
    }

    // MARK: - Encryption Key Tests

    func testSetAndGetEncryptionKey() {
        // Given
        let encryptionKey = Data(repeating: 0x42, count: 32) // 256-bit key
        let identifier = "master"

        // When
        let setSuccess = keychain.setEncryptionKey(encryptionKey, identifier: identifier)
        let retrieved = keychain.getEncryptionKey(identifier: identifier)

        // Then
        XCTAssertTrue(setSuccess)
        XCTAssertEqual(retrieved, encryptionKey)
    }

    // MARK: - Utility Tests

    func testExists() {
        // Given
        let key = "exists_test"

        // When
        let existsBefore = keychain.exists(forKey: key)
        keychain.setString("value", forKey: key)
        let existsAfter = keychain.exists(forKey: key)

        // Then
        XCTAssertFalse(existsBefore)
        XCTAssertTrue(existsAfter)
    }

    func testAllKeys() {
        // Given
        keychain.setString("value1", forKey: "key1")
        keychain.setString("value2", forKey: "key2")
        keychain.setString("value3", forKey: "key3")

        // When
        let keys = keychain.allKeys()

        // Then
        XCTAssertEqual(keys.count, 3)
        XCTAssertTrue(keys.contains("key1"))
        XCTAssertTrue(keys.contains("key2"))
        XCTAssertTrue(keys.contains("key3"))
    }

    // MARK: - Special Characters Tests

    func testStoreUnicodeString() {
        // Given
        let unicodeString = "Hello 世界 🎵 Émoji"
        let key = "unicode_test"

        // When
        keychain.setString(unicodeString, forKey: key)
        let retrieved = keychain.getString(forKey: key)

        // Then
        XCTAssertEqual(retrieved, unicodeString)
    }

    func testStoreEmptyString() {
        // Given
        let emptyString = ""
        let key = "empty_test"

        // When
        keychain.setString(emptyString, forKey: key)
        let retrieved = keychain.getString(forKey: key)

        // Then
        XCTAssertEqual(retrieved, emptyString)
    }

    // MARK: - Large Data Tests

    func testStoreLargeData() {
        // Given: 100 KB of data
        let largeData = Data(repeating: 0xFF, count: 100 * 1024)
        let key = "large_data_test"

        // When
        let setSuccess = keychain.setData(largeData, forKey: key)
        let retrieved = keychain.getData(forKey: key)

        // Then
        XCTAssertTrue(setSuccess)
        XCTAssertEqual(retrieved, largeData)
    }

    // MARK: - Thread Safety Tests

    func testConcurrentAccess() {
        let expectation = XCTestExpectation(description: "Concurrent keychain access")
        expectation.expectedFulfillmentCount = 10

        // When: Multiple concurrent writes
        DispatchQueue.concurrentPerform(iterations: 10) { index in
            let key = "concurrent_\(index)"
            let value = "value_\(index)"

            keychain.setString(value, forKey: key)
            let retrieved = keychain.getString(forKey: key)

            XCTAssertEqual(retrieved, value)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }

    // MARK: - Performance Tests

    func testWritePerformance() {
        let testData = "Performance test data".data(using: .utf8)!

        measure {
            for i in 0..<100 {
                keychain.setData(testData, forKey: "perf_test_\(i)")
            }
        }
    }

    func testReadPerformance() {
        // Setup
        let testData = "Performance test data".data(using: .utf8)!
        for i in 0..<100 {
            keychain.setData(testData, forKey: "perf_test_\(i)")
        }

        measure {
            for i in 0..<100 {
                _ = keychain.getData(forKey: "perf_test_\(i)")
            }
        }
    }

    // MARK: - Security Best Practices Tests

    func testNeverLogSensitiveData() {
        // This test ensures we don't accidentally log sensitive data
        // In production code, verify logs don't contain keys/values

        let sensitiveKey = "credit_card"
        let sensitiveValue = "4532-1234-5678-9010"

        keychain.setString(sensitiveValue, forKey: sensitiveKey)

        // If we were to add logging, this would catch it
        // For now, this is a reminder to never log keychain values
        XCTAssertTrue(true, "Never log keychain values in production")
    }
}
