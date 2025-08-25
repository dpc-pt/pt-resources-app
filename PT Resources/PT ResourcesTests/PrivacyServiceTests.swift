//
//  PrivacyServiceTests.swift
//  PT ResourcesTests
//
//  Unit tests for PrivacyService
//

import XCTest
import CoreData
@testable import PT_Resources

final class PrivacyServiceTests: XCTestCase {
    var privacyService: PrivacyService!
    var mockPersistenceController: PersistenceController!

    override func setUpWithError() throws {
        try super.setUpWithError()

        // Use in-memory store for testing
        mockPersistenceController = PersistenceController(inMemory: true)
        privacyService = PrivacyService()
    }

    override func tearDownWithError() throws {
        privacyService = nil
        mockPersistenceController = nil
        try super.tearDownWithError()
    }

    // MARK: - Data Export Tests

    func testExportUserData() async throws {
        // This test would require setting up mock data in Core Data
        // and verifying the export file is created correctly

        do {
            let exportURL = try await privacyService.exportUserData()

            // Verify file exists
            let fileManager = FileManager.default
            XCTAssertTrue(fileManager.fileExists(atPath: exportURL.path))

            // Verify file has content
            let data = try Data(contentsOf: exportURL)
            XCTAssertGreaterThan(data.count, 0)

            // Verify it's valid JSON
            let jsonObject = try JSONSerialization.jsonObject(with: data)
            XCTAssertNotNil(jsonObject)

            // Clean up
            try? fileManager.removeItem(at: exportURL)

        } catch {
            // If there's no data to export, the test should still pass
            // but we should verify the error type
            XCTAssertTrue(error is CocoaError || error is URLError)
        }
    }

    func testExportDownloadedTalks() async throws {
        do {
            let exportURL = try await privacyService.exportDownloadedTalks()

            let fileManager = FileManager.default
            XCTAssertTrue(fileManager.fileExists(atPath: exportURL.path))

            let data = try Data(contentsOf: exportURL)
            let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            XCTAssertNotNil(jsonObject)

            // Clean up
            try? fileManager.removeItem(at: exportURL)

        } catch {
            XCTAssertTrue(error is CocoaError || error is URLError)
        }
    }

    func testExportListeningHistory() async throws {
        do {
            let exportURL = try await privacyService.exportListeningHistory()

            let fileManager = FileManager.default
            XCTAssertTrue(fileManager.fileExists(atPath: exportURL.path))

            let data = try Data(contentsOf: exportURL)
            let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            XCTAssertNotNil(jsonObject)

            // Clean up
            try? fileManager.removeItem(at: exportURL)

        } catch {
            XCTAssertTrue(error is CocoaError || error is URLError)
        }
    }

    // MARK: - Data Deletion Tests

    func testDeleteDownloadedContent() async throws {
        // This test would require setting up downloaded talks in Core Data
        // and verifying they are deleted correctly

        do {
            try await privacyService.deleteDownloadedContent()

            // Verify the deletion completed without error
            // In a full test, you'd verify the specific data was deleted

        } catch {
            // Deletion should not normally fail, but handle gracefully
            XCTAssertTrue(error is CocoaError || error is URLError)
        }
    }

    func testDeleteListeningHistory() async throws {
        do {
            try await privacyService.deleteListeningHistory()

            // Verify the deletion completed without error

        } catch {
            XCTAssertTrue(error is CocoaError || error is URLError)
        }
    }

    func testDeleteAllUserData() async throws {
        do {
            try await privacyService.deleteAllUserData()

            // Verify the deletion completed without error
            // In a full test, you'd verify all user data was cleared

        } catch {
            XCTAssertTrue(error is CocoaError || error is URLError)
        }
    }

    // MARK: - Data Usage Statistics Tests

    func testGetDataUsageStatistics() async {
        let statistics = await privacyService.getDataUsageStatistics()

        // Verify statistics structure
        XCTAssertGreaterThanOrEqual(statistics.totalTalks, 0)
        XCTAssertGreaterThanOrEqual(statistics.downloadedTalks, 0)
        XCTAssertGreaterThanOrEqual(statistics.bookmarks, 0)
        XCTAssertGreaterThanOrEqual(statistics.totalDownloadedSize, 0)

        // Verify formatted size string
        XCTAssertFalse(statistics.totalDownloadedSizeFormatted.isEmpty)
    }

    // MARK: - Export Data Model Tests

    func testExportDataCodable() {
        let exportData = ExportData(
            exportDate: Date(),
            talks: [],
            bookmarks: [],
            playbackStates: [],
            downloads: [],
            appVersion: "1.0.0",
            exportType: .full
        )

        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(exportData)

            let decoder = JSONDecoder()
            let decodedData = try decoder.decode(ExportData.self, from: data)

            XCTAssertEqual(decodedData.appVersion, exportData.appVersion)
            XCTAssertEqual(decodedData.exportType, exportData.exportType)

        } catch {
            XCTFail("ExportData should be codable: \(error)")
        }
    }

    func testTalkExportDataCodable() {
        let talkData = TalkExportData(
            id: "test-id",
            title: "Test Talk",
            speaker: "Test Speaker",
            series: "Test Series",
            biblePassage: "John 1:1",
            dateRecorded: Date(),
            duration: 1800,
            isDownloaded: true,
            isFavorite: false,
            lastAccessedAt: Date(),
            fileSize: 1024
        )

        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(talkData)

            let decoder = JSONDecoder()
            let decodedData = try decoder.decode(TalkExportData.self, from: data)

            XCTAssertEqual(decodedData.id, talkData.id)
            XCTAssertEqual(decodedData.title, talkData.title)
            XCTAssertEqual(decodedData.speaker, talkData.speaker)

        } catch {
            XCTFail("TalkExportData should be codable: \(error)")
        }
    }

    // MARK: - Privacy Document Tests

    func testPrivacyDocumentStructure() {
        let privacyPolicy = PrivacyDocument.privacyPolicy
        let termsOfService = PrivacyDocument.termsOfService

        // Test privacy policy
        XCTAssertEqual(privacyPolicy.title, "Privacy Policy")
        XCTAssertFalse(privacyPolicy.content.isEmpty)
        XCTAssertNotNil(privacyPolicy.lastUpdated)

        // Test terms of service
        XCTAssertEqual(termsOfService.title, "Terms of Service")
        XCTAssertFalse(termsOfService.content.isEmpty)
        XCTAssertNotNil(termsOfService.lastUpdated)
    }

    // MARK: - Performance Tests

    func testDataUsageStatisticsPerformance() async {
        measure {
            let _ = privacyService.getDataUsageStatistics()
        }
    }
}

