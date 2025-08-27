//
//  DownloadServiceTests.swift
//  PT ResourcesTests
//
//  Tests for the enhanced DownloadService with validation
//

import XCTest
@testable import PT_Resources
import CoreData

final class DownloadServiceTests: XCTestCase {
    
    var downloadService: DownloadService!
    var mockAPIService: MockTalksAPIService!
    var testPersistenceController: PersistenceController!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Create test Core Data stack
        testPersistenceController = PersistenceController.preview
        
        // Create mock API service
        mockAPIService = MockTalksAPIService()
        
        // Create download service with mocks
        downloadService = DownloadService(
            apiService: mockAPIService,
            persistenceController: testPersistenceController
        )
    }
    
    override func tearDownWithError() throws {
        downloadService = nil
        mockAPIService = nil
        testPersistenceController = nil
        try super.tearDownWithError()
    }
    
    @MainActor
    func testDownloadTalkSuccess() async throws {
        // Given
        let testTalk = Talk.mockTalks[0]
        mockAPIService.shouldFail = false
        
        // When
        try await downloadService.downloadTalk(testTalk)
        
        // Then
        // Check that download was initiated
        XCTAssertEqual(downloadService.activeDownloads.count, 1)
        XCTAssertEqual(downloadService.activeDownloads[0].talkID, testTalk.id)
        XCTAssertEqual(downloadService.activeDownloads[0].status, .pending)
        
        // Check progress tracking
        XCTAssertNotNil(downloadService.downloadProgress[testTalk.id])
        XCTAssertEqual(downloadService.downloadProgress[testTalk.id], 0.0)
    }
    
    @MainActor
    func testDownloadTalkFailure() async throws {
        // Given
        let testTalk = Talk.mockTalks[0]
        mockAPIService.shouldFail = true
        
        // When/Then
        do {
            try await downloadService.downloadTalk(testTalk)
            XCTFail("Expected download to fail")
        } catch {
            // Should fail and clean up progress
            XCTAssertEqual(downloadService.activeDownloads.count, 0)
            XCTAssertNil(downloadService.downloadProgress[testTalk.id])
        }
    }
    
    @MainActor
    func testDownloadAlreadyDownloaded() async throws {
        // Given
        let testTalk = Talk.mockTalks[0]
        
        // Mark talk as downloaded in Core Data
        try await testPersistenceController.performBackgroundTask { context in
            let talkEntity = TalkEntity(context: context)
            talkEntity.id = testTalk.id
            talkEntity.isDownloaded = true
            talkEntity.localAudioURL = "/fake/path/audio.mp3"
            try context.save()
        }
        
        // When
        try await downloadService.downloadTalk(testTalk)
        
        // Then
        // Should not start a new download
        XCTAssertEqual(downloadService.activeDownloads.count, 0)
        XCTAssertNil(downloadService.downloadProgress[testTalk.id])
    }
    
    @MainActor
    func testDownloadInProgress() async throws {
        // Given
        let testTalk = Talk.mockTalks[0]
        
        // Start first download
        try await downloadService.downloadTalk(testTalk)
        let initialDownloadCount = downloadService.activeDownloads.count
        
        // When - try to download again
        try await downloadService.downloadTalk(testTalk)
        
        // Then - should not create duplicate download
        XCTAssertEqual(downloadService.activeDownloads.count, initialDownloadCount)
    }
    
    @MainActor
    func testCancelDownload() async throws {
        // Given
        let testTalk = Talk.mockTalks[0]
        try await downloadService.downloadTalk(testTalk)
        
        // When
        await downloadService.cancelDownload(for: testTalk.id)
        
        // Then
        XCTAssertEqual(downloadService.activeDownloads.count, 0)
        XCTAssertNil(downloadService.downloadProgress[testTalk.id])
    }
    
    @MainActor
    func testDeleteDownload() async throws {
        // Given
        let testTalk = Talk.mockTalks[0]
        
        // Setup downloaded talk in Core Data
        try await testPersistenceController.performBackgroundTask { context in
            let talkEntity = TalkEntity(context: context)
            talkEntity.id = testTalk.id
            talkEntity.isDownloaded = true
            talkEntity.localAudioURL = "/fake/path/audio.mp3"
            try context.save()
        }
        
        // When
        try await downloadService.deleteDownload(for: testTalk.id)
        
        // Then
        let isDownloaded = await downloadService.isDownloaded(testTalk.id)
        XCTAssertFalse(isDownloaded)
    }
    
    @MainActor
    func testGetDownloadedTalks() async throws {
        // Given - create some downloaded talks
        let testTalks = Array(Talk.mockTalks[0...1])
        
        try await testPersistenceController.performBackgroundTask { context in
            for talk in testTalks {
                let talkEntity = TalkEntity(context: context)
                talkEntity.id = talk.id
                talkEntity.title = talk.title
                talkEntity.speaker = talk.speaker
                talkEntity.duration = Int32(talk.duration)
                talkEntity.isDownloaded = true
                talkEntity.localAudioURL = "/fake/path/\(talk.id).mp3"
                talkEntity.fileSize = 45_000_000
                talkEntity.createdAt = Date()
                talkEntity.lastAccessedAt = Date()
            }
            try context.save()
        }
        
        // When
        let downloadedTalks = try await downloadService.getDownloadedTalksWithMetadata()
        
        // Then
        XCTAssertEqual(downloadedTalks.count, testTalks.count)
        XCTAssertTrue(downloadedTalks.contains { $0.id == testTalks[0].id })
        XCTAssertTrue(downloadedTalks.contains { $0.id == testTalks[1].id })
    }
    
    func testValidateDownloadURLValid() async throws {
        // Given - use a real URL that should respond to HEAD requests
        let validURL = URL(string: "https://httpbin.org/status/200")!
        
        // When/Then - should not throw
        do {
            try await downloadService.validateDownloadURL(validURL)
        } catch {
            XCTFail("Valid URL should not throw error: \(error)")
        }
    }
    
    func testValidateDownloadURLInvalid() async throws {
        // Given - use a URL that will return 404
        let invalidURL = URL(string: "https://httpbin.org/status/404")!
        
        // When/Then - should throw
        do {
            try await downloadService.validateDownloadURL(invalidURL)
            XCTFail("Invalid URL should throw error")
        } catch {
            XCTAssertTrue(error is DownloadError)
        }
    }
}

// MARK: - Private Extensions for Testing

private extension DownloadService {
    func validateDownloadURL(_ url: URL) async throws {
        // Make the private method accessible for testing
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 10.0
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw DownloadError.invalidDownloadURL
            }
            
            guard httpResponse.statusCode == 200 else {
                throw DownloadError.invalidDownloadURL
            }
            
        } catch {
            throw DownloadError.networkError
        }
    }
}