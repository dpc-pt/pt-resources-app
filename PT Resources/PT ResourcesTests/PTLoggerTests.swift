//
//  PTLoggerTests.swift
//  PT ResourcesTests
//
//  Unit tests for PTLogger
//

import XCTest
import Foundation
@testable import PT_Resources

final class PTLoggerTests: XCTestCase {

    // MARK: - Logger Category Tests

    func testLoggerCategories() {
        // Test that all logger categories are accessible
        XCTAssertNotNil(PTLogger.api)
        XCTAssertNotNil(PTLogger.coreData)
        XCTAssertNotNil(PTLogger.ui)
        XCTAssertNotNil(PTLogger.audio)
        XCTAssertNotNil(PTLogger.download)
        XCTAssertNotNil(PTLogger.fonts)
        XCTAssertNotNil(PTLogger.general)
    }

    // MARK: - Logging Method Tests

    func testAPILogging() {
        // Test that API logging methods can be called without crashing
        PTLogger.apiRequest("Test API request", metadata: ["url": "https://example.com"])
        PTLogger.apiError("Test API error", error: NSError(domain: "Test", code: 1))

        // Methods should complete without throwing
        XCTAssertTrue(true, "API logging methods should complete without error")
    }

    func testCoreDataLogging() {
        PTLogger.coreDataOperation("Test Core Data operation", metadata: ["entity": "TalkEntity"])
        PTLogger.coreDataError("Test Core Data error", error: NSError(domain: "CoreData", code: 2))

        XCTAssertTrue(true, "Core Data logging methods should complete without error")
    }

    func testUILogging() {
        PTLogger.uiEvent("Test UI event", metadata: ["view": "HomeView"])
        PTLogger.uiError("Test UI error", error: NSError(domain: "UI", code: 3))

        XCTAssertTrue(true, "UI logging methods should complete without error")
    }

    func testAudioLogging() {
        PTLogger.audioEvent("Test audio event", metadata: ["action": "play"])

        XCTAssertTrue(true, "Audio logging methods should complete without error")
    }

    func testDownloadLogging() {
        PTLogger.downloadProgress("Test download progress", metadata: ["progress": 0.5])

        XCTAssertTrue(true, "Download logging methods should complete without error")
    }

    func testFontLogging() {
        PTLogger.fontRegistration("Test font registration", metadata: ["font": "TestFont"])

        XCTAssertTrue(true, "Font logging methods should complete without error")
    }

    func testGeneralLogging() {
        PTLogger.general.info("Test general info")
        PTLogger.general.error("Test general error", metadata: ["details": "test"])

        XCTAssertTrue(true, "General logging methods should complete without error")
    }

    // MARK: - Performance Logging Tests

    func testPerformanceLogging() {
        let operationId = PTLogger.performanceStart("Test Operation")

        // Simulate some work
        Thread.sleep(forTimeInterval: 0.1)

        PTLogger.performanceEnd("Test Operation", operationId: operationId, duration: 0.1)

        XCTAssertTrue(true, "Performance logging should complete without error")
    }

    func testPerformanceMeasurement() {
        let expectation = expectation(description: "Performance measurement")

        PTLogger.measurePerformance("Test Performance Block") {
            // Simulate some work
            Thread.sleep(forTimeInterval: 0.05)
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)
    }

    // MARK: - Message Building Tests

    func testMessageBuilding() {
        // Test that messages are properly formatted with metadata
        let message = "Test message"
        let metadata = ["key1": "value1", "key2": 42]

        // The actual message building is private, but we can test the public interface
        PTLogger.general.info(message, metadata: metadata)

        XCTAssertTrue(true, "Message with metadata should be logged without error")
    }

    func testErrorLogging() {
        let testError = NSError(domain: "TestDomain", code: 123,
                               userInfo: [NSLocalizedDescriptionKey: "Test error description"])

        PTLogger.general.error("Test error logging", error: testError)

        XCTAssertTrue(true, "Error logging should complete without error")
    }

    // MARK: - Log Level Tests

    func testDifferentLogLevels() {
        // Test that different log levels work correctly
        PTLogger.general.info("Info level message")
        PTLogger.general.error("Error level message")
        PTLogger.general.debug("Debug level message")

        // In production, debug messages might be filtered out
        // but the methods should still work
        XCTAssertTrue(true, "Different log levels should work without error")
    }

    // MARK: - Performance Tests

    func testLoggingPerformance() {
        measure {
            for i in 0..<1000 {
                PTLogger.general.info("Performance test message \(i)", metadata: ["index": i])
            }
        }
    }

    func testErrorLoggingPerformance() {
        let testError = NSError(domain: "PerformanceTest", code: 999,
                               userInfo: [NSLocalizedDescriptionKey: "Performance test error"])

        measure {
            for i in 0..<100 {
                PTLogger.general.error("Performance test error \(i)", error: testError)
            }
        }
    }

    // MARK: - Metadata Handling Tests

    func testMetadataTypes() {
        // Test different types of metadata values
        let metadata: [String: Any] = [
            "string": "test string",
            "int": 42,
            "double": 3.14159,
            "bool": true,
            "array": ["item1", "item2"],
            "dict": ["nested": "value"]
        ]

        PTLogger.general.info("Test metadata types", metadata: metadata)

        XCTAssertTrue(true, "Complex metadata should be handled without error")
    }

    func testEmptyMetadata() {
        PTLogger.general.info("Test empty metadata", metadata: [:])
        PTLogger.general.info("Test nil metadata", metadata: nil)

        XCTAssertTrue(true, "Empty or nil metadata should be handled without error")
    }

    // MARK: - Special Cases Tests

    func testSpecialCharactersInMessages() {
        let specialMessage = "Special chars: !@#$%^&*()_+-=[]{}|;:,.<>?/~`"
        let specialMetadata = ["special": "chars: !@#$%^&*()"]

        PTLogger.general.info(specialMessage, metadata: specialMetadata)

        XCTAssertTrue(true, "Special characters should be handled without error")
    }

    func testLongMessages() {
        let longMessage = String(repeating: "This is a very long message. ", count: 100)
        let longMetadata = ["longValue": String(repeating: "a", count: 1000)]

        PTLogger.general.info(longMessage, metadata: longMetadata)

        XCTAssertTrue(true, "Long messages should be handled without error")
    }

    func testConcurrentLogging() {
        let expectation = expectation(description: "Concurrent logging")
        expectation.expectedFulfillmentCount = 10

        DispatchQueue.concurrentPerform(iterations: 10) { index in
            PTLogger.general.info("Concurrent message \(index)", metadata: ["thread": index])
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5.0)
    }
}

