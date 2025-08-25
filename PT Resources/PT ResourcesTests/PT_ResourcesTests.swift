//
//  PT_ResourcesTests.swift
//  PT ResourcesTests
//
//  Unit tests for PT Resources app
//

import Testing
import Foundation
@testable import PT_Resources

struct PT_ResourcesTests {

    // MARK: - Model Tests
    
    @Test func talkModelTests() async throws {
        let talk = Talk.mockTalks[0]
        
        #expect(talk.id == "mock-1")
        #expect(talk.title == "The Gospel of John: Light in the Darkness")
        #expect(talk.speaker == "John Smith")
        #expect(talk.duration > 0)
        #expect(!talk.formattedDuration.isEmpty)
        #expect(!talk.shareURL.isEmpty)
    }
    
    @Test func talkSearchFiltersTests() async throws {
        var filters = TalkSearchFilters()
        #expect(filters.isEmpty)
        
        filters.query = "gospel"
        #expect(!filters.isEmpty)
        
        filters.speaker = "John Smith"
        #expect(!filters.isEmpty)
        
        filters = TalkSearchFilters()
        #expect(filters.isEmpty)
    }
    
    @Test func talkSortOptionTests() async throws {
        let sortOptions = TalkSortOption.allCases
        #expect(sortOptions.count > 0)
        
        for option in sortOptions {
            #expect(!option.displayName.isEmpty)
        }
    }

    // MARK: - Service Tests
    
    @Test func mockAPIServiceTests() async throws {
        let mockService = MockTalksAPIService()
        
        // Test successful fetch
        let response = try await mockService.fetchTalks(filters: TalkSearchFilters(), page: 1, sortBy: .dateNewest)
        #expect(response.talks.count > 0)
        #expect(response.page == 1)
        
        // Test talk detail
        let talk = try await mockService.fetchTalkDetail(id: "mock-1")
        #expect(talk.id == "mock-1")
        
        // Test chapters
        let chapters = try await mockService.fetchTalkChapters(id: "mock-1")
        #expect(chapters.count >= 0)
        
        // Test download URL
        let downloadResponse = try await mockService.getDownloadURL(for: "mock-1")
        #expect(!downloadResponse.downloadURL.isEmpty)
    }
    
    @Test func mockAPIServiceFailureTests() async throws {
        let mockService = MockTalksAPIService()
        mockService.shouldFail = true
        
        // Test API failure handling
        do {
            _ = try await mockService.fetchTalks(filters: TalkSearchFilters(), page: 1, sortBy: .dateNewest)
            #expect(Bool(false), "Expected API call to fail")
        } catch {
            #expect(error is APIError)
        }
    }
    
    @Test func transcriptionModelTests() async throws {
        let transcript = Transcript.mockTranscript
        
        #expect(!transcript.id.isEmpty)
        #expect(!transcript.talkID.isEmpty)
        #expect(!transcript.text.isEmpty)
        #expect(transcript.segments.count > 0)
        #expect(transcript.status == .completed)
        
        // Test segment finding
        let segment = transcript.segment(at: 5.0)
        #expect(segment != nil)
        #expect(segment?.startTime ?? 0 <= 5.0)
        #expect(segment?.endTime ?? 0 >= 5.0)
    }
    
    @Test func esvPassageModelTests() async throws {
        let passage = ESVPassage.mockPassages[0]
        
        #expect(!passage.id.isEmpty)
        #expect(!passage.reference.isEmpty)
        #expect(passage.passages.count > 0)
        #expect(!passage.text.isEmpty)
        #expect(!passage.formattedText.isEmpty)
    }
    
    @Test func configTests() async throws {
        // Test that config has required values
        #expect(!Config.proclamationAPIBaseURL.isEmpty)
        #expect(Config.maxConcurrentDownloads > 0)
        #expect(Config.defaultAutoDeleteDays > 0)
        #expect(Config.playbackSpeedOptions.count > 0)
        #expect(Config.skipInterval > 0)
        
        // Test URL scheme
        #expect(Config.urlScheme == "ptresources")
        
        // Test API endpoints
        let resourcesEndpoint = Config.APIEndpoint.resources()
        #expect(!resourcesEndpoint.url.isEmpty)
        
        let resourceDetailEndpoint = Config.APIEndpoint.resourceDetail(id: "test")
        #expect(resourceDetailEndpoint.url.contains("test"))
    }
    
    // MARK: - Utility Tests
    
    @Test func biblReferenceParsingTests() async throws {
        #expect("John 3:16".isBibleReference)
        #expect("1 Corinthians 13:1-13".isBibleReference)
        #expect("Romans 8:28".isBibleReference)
        #expect("Not a reference".isBibleReference == false)
        
        let normalized = "John  3:16 - 17".normalizedBibleReference
        #expect(normalized == "John 3:16-17")
    }
    
    @Test func persistenceControllerTests() async throws {
        let controller = PersistenceController(inMemory: true)
        #expect(controller.container.persistentStoreDescriptions.count > 0)
        
        // Test background context creation
        let backgroundContext = controller.backgroundContext()
        #expect(backgroundContext.concurrencyType == .privateQueueConcurrencyType)
    }
}
