//
//  TalksAPIService.swift
//  PT Resources
//
//  Service for fetching talks from the Proclamation Trust API
//

import Foundation
import Combine

protocol TalksAPIServiceProtocol {
    func fetchTalks(filters: TalkSearchFilters, page: Int, sortBy: TalkSortOption) async throws -> TalksResponse
    func fetchTalkDetail(id: String) async throws -> Talk
    func fetchTalkChapters(id: String) async throws -> [Chapter]
    func getDownloadURL(for talkID: String) async throws -> DownloadResponse
    func searchTalks(query: String, page: Int) async throws -> TalksResponse
}

final class TalksAPIService: TalksAPIServiceProtocol, ObservableObject {
    
    private let session: URLSession
    private let decoder: JSONDecoder
    
    init(session: URLSession = .shared) {
        self.session = session
        self.decoder = JSONDecoder()
        
        // Configure date decoding
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        decoder.dateDecodingStrategy = .formatted(formatter)
    }
    
    // MARK: - API Methods
    
    func fetchTalks(filters: TalkSearchFilters = TalkSearchFilters(), page: Int = 1, sortBy: TalkSortOption = .dateNewest) async throws -> TalksResponse {
        
        // Use mock data if configured
        if Config.useMockServices {
            return await mockFetchTalks(filters: filters, page: page, sortBy: sortBy)
        }
        
        let endpoint = Config.APIEndpoint.resources(
            query: filters.query.isEmpty ? nil : filters.query,
            speaker: filters.speaker,
            series: filters.series,
            page: page,
            limit: 12
        )
        
        guard let url = URL(string: endpoint.url) else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                throw APIError.httpError(httpResponse.statusCode)
            }
            
            return try decoder.decode(TalksResponse.self, from: data)
            
        } catch {
            if error is APIError {
                throw error
            } else {
                throw APIError.networkError(error)
            }
        }
    }
    
    func fetchTalkDetail(id: String) async throws -> Talk {
        
        // Use mock data if configured
        if Config.useMockServices {
            return await mockFetchTalkDetail(id: id)
        }
        
        let endpoint = Config.APIEndpoint.resourceDetail(id: id)
        
        guard let url = URL(string: endpoint.url) else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                throw APIError.httpError(httpResponse.statusCode)
            }
            
            let detailResponse = try decoder.decode(TalkDetailResponse.self, from: data)
            return detailResponse.resource
            
        } catch {
            if error is APIError {
                throw error
            } else {
                throw APIError.networkError(error)
            }
        }
    }
    
    func fetchTalkChapters(id: String) async throws -> [Chapter] {
        
        // Use mock data if configured
        if Config.useMockServices {
            return await mockFetchTalkChapters(id: id)
        }
        
        // Note: Chapters may not be available in PT API - using detail endpoint
        let endpoint = Config.APIEndpoint.resourceDetail(id: id)
        
        guard let url = URL(string: endpoint.url) else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                throw APIError.httpError(httpResponse.statusCode)
            }
            
            let chaptersResponse = try decoder.decode(ChaptersResponse.self, from: data)
            return chaptersResponse.chapters
            
        } catch {
            if error is APIError {
                throw error
            } else {
                throw APIError.networkError(error)
            }
        }
    }
    
    func getDownloadURL(for talkID: String) async throws -> DownloadResponse {
        
        // Use mock data if configured
        if Config.useMockServices {
            return await mockGetDownloadURL(for: talkID)
        }
        
        let endpoint = Config.APIEndpoint.resourceDownload(id: talkID)
        
        guard let url = URL(string: endpoint.url) else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                throw APIError.httpError(httpResponse.statusCode)
            }
            
            return try decoder.decode(DownloadResponse.self, from: data)
            
        } catch {
            if error is APIError {
                throw error
            } else {
                throw APIError.networkError(error)
            }
        }
    }
    
    func searchTalks(query: String, page: Int = 1) async throws -> TalksResponse {
        var filters = TalkSearchFilters()
        filters.query = query
        return try await fetchTalks(filters: filters, page: page)
    }
}

// MARK: - Supporting Types

private struct ChaptersResponse: Codable {
    let chapters: [Chapter]
}

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case networkError(Error)
    case decodingError(Error)
    case notFound
    case serverError
    case rateLimited
    case unauthorized
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code):
            switch code {
            case 404:
                return "Resource not found"
            case 401:
                return "Unauthorized"
            case 429:
                return "Too many requests"
            case 500...599:
                return "Server error"
            default:
                return "HTTP error: \(code)"
            }
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Data parsing error: \(error.localizedDescription)"
        case .notFound:
            return "Resource not found"
        case .serverError:
            return "Server error"
        case .rateLimited:
            return "Rate limited - please try again later"
        case .unauthorized:
            return "Unauthorized access"
        }
    }
}

// MARK: - Mock Implementation

extension TalksAPIService {
    
    private func mockFetchTalks(filters: TalkSearchFilters, page: Int, sortBy: TalkSortOption) async -> TalksResponse {
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        var talks = Talk.mockTalks
        
        // Apply search filter
        if !filters.query.isEmpty {
            talks = talks.filter { talk in
                talk.title.localizedCaseInsensitiveContains(filters.query) ||
                talk.description?.localizedCaseInsensitiveContains(filters.query) == true ||
                talk.speaker.localizedCaseInsensitiveContains(filters.query)
            }
        }
        
        // Apply speaker filter
        if let speaker = filters.speaker, !speaker.isEmpty {
            talks = talks.filter { $0.speaker == speaker }
        }
        
        // Apply series filter
        if let series = filters.series, !series.isEmpty {
            talks = talks.filter { $0.series == series }
        }
        
        // Apply sorting
        switch sortBy {
        case .dateNewest:
            talks = talks.sorted { $0.dateRecorded > $1.dateRecorded }
        case .dateOldest:
            talks = talks.sorted { $0.dateRecorded < $1.dateRecorded }
        case .titleAZ:
            talks = talks.sorted { $0.title < $1.title }
        case .titleZA:
            talks = talks.sorted { $0.title > $1.title }
        case .speaker:
            talks = talks.sorted { $0.speaker < $1.speaker }
        case .series:
            talks = talks.sorted { ($0.series ?? "") < ($1.series ?? "") }
        case .duration:
            talks = talks.sorted { $0.duration > $1.duration }
        }
        
        // Paginate
        let pageSize = 20
        let startIndex = (page - 1) * pageSize
        let endIndex = min(startIndex + pageSize, talks.count)
        
        if startIndex >= talks.count {
            return TalksResponse(
                talks: [],
                page: page,
                totalPages: max(1, (talks.count + pageSize - 1) / pageSize),
                totalCount: talks.count,
                hasMore: false
            )
        }
        
        let pagedTalks = Array(talks[startIndex..<endIndex])
        let totalPages = max(1, (talks.count + pageSize - 1) / pageSize)
        
        return TalksResponse(
            talks: pagedTalks,
            page: page,
            totalPages: totalPages,
            totalCount: talks.count,
            hasMore: page < totalPages
        )
    }
    
    private func mockFetchTalkDetail(id: String) async -> Talk {
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        return Talk.mockTalks.first { $0.id == id } ?? Talk.mockTalks.first!
    }
    
    private func mockFetchTalkChapters(id: String) async -> [Chapter] {
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        return Talk.mockChapters
    }
    
    private func mockGetDownloadURL(for talkID: String) async -> DownloadResponse {
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Note: Mock services are now only used when explicitly requested for testing
        // In normal development, we use the real Proclamation Trust API
        let testAudioURL = "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3"
        
        return DownloadResponse(
            downloadURL: testAudioURL,
            expiresAt: Date().addingTimeInterval(3600), // 1 hour from now
            fileSize: 4_500_000 // ~4.5 MB (approximate size of test file)
        )
    }
}

// MARK: - Mock Service for Testing

final class MockTalksAPIService: TalksAPIServiceProtocol {
    
    var shouldFail = false
    var mockTalks = Talk.mockTalks
    var mockChapters = Talk.mockChapters
    
    func fetchTalks(filters: TalkSearchFilters, page: Int, sortBy: TalkSortOption) async throws -> TalksResponse {
        if shouldFail {
            throw APIError.serverError
        }
        
        return TalksResponse(
            talks: mockTalks,
            page: 1,
            totalPages: 1,
            totalCount: mockTalks.count,
            hasMore: false
        )
    }
    
    func fetchTalkDetail(id: String) async throws -> Talk {
        if shouldFail {
            throw APIError.notFound
        }
        
        return mockTalks.first { $0.id == id } ?? mockTalks.first!
    }
    
    func fetchTalkChapters(id: String) async throws -> [Chapter] {
        if shouldFail {
            throw APIError.notFound
        }
        
        return mockChapters
    }
    
    func getDownloadURL(for talkID: String) async throws -> DownloadResponse {
        if shouldFail {
            throw APIError.serverError
        }
        
        // Use a real MP3 file for testing when mock services are explicitly requested
        let testAudioURL = "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3"
        
        return DownloadResponse(
            downloadURL: testAudioURL,
            expiresAt: Date().addingTimeInterval(3600),
            fileSize: 4_500_000 // ~4.5 MB
        )
    }
    
    func searchTalks(query: String, page: Int) async throws -> TalksResponse {
        return try await fetchTalks(filters: TalkSearchFilters(), page: page, sortBy: .dateNewest)
    }
}