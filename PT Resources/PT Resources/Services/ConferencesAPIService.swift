//
//  ConferencesAPIService.swift
//  PT Resources
//
//  Service for fetching conferences from the Proclamation Trust Conferences API
//

import Foundation
import Combine

protocol ConferencesAPIServiceProtocol {
    func fetchConferences(filters: ConferenceSearchFilters, page: Int) async throws -> ConferencesResponse
    func fetchConferenceDetail(id: String) async throws -> ConferenceInfo
    func fetchConferenceResources(conferenceId: String, page: Int) async throws -> TalksResponse
    func fetchAvailableYears() async throws -> [String]
    func fetchConferenceTypes() async throws -> [ConferenceType]
}

final class ConferencesAPIService: ConferencesAPIServiceProtocol, ObservableObject {
    
    private let session: URLSession
    private let decoder: JSONDecoder
    private let baseURL: String
    
    init(session: URLSession = .shared) {
        self.session = session
        self.decoder = JSONDecoder()
        self.baseURL = "\(Config.proclamationAPIBaseURL)/conferences"
        
        // Configure date decoding
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        decoder.dateDecodingStrategy = .formatted(formatter)
    }
    
    // MARK: - API Methods
    
    /// Fetches conferences from the conferences API
    func fetchConferences(filters: ConferenceSearchFilters = ConferenceSearchFilters(), page: Int = 1) async throws -> ConferencesResponse {
        
        // Use mock data if configured
        if Config.useMockServices {
            return await mockFetchConferences(filters: filters, page: page)
        }
        
        var components = URLComponents(string: "\(baseURL)")!
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "limit", value: "20") // Default limit from API docs, max: 100
        ]
        
        // Search query (min 3 chars enforced by API)
        if !filters.query.isEmpty && filters.query.count >= 3 {
            queryItems.append(URLQueryItem(name: "search", value: filters.query))
        }
        
        // Year filter (comma-separated)
        var yearValues: [String] = []
        if !filters.years.isEmpty {
            yearValues.append(contentsOf: filters.years)
        }
        
        // Legacy single year support
        if let year = filters.year, !year.isEmpty {
            yearValues.append(year)
        }
        
        if !yearValues.isEmpty {
            let yearString = Array(Set(yearValues)).joined(separator: ",") // Remove duplicates
            queryItems.append(URLQueryItem(name: "year", value: yearString))
        }
        
        // Conference type filter (if specified)
        if let conferenceType = filters.conferenceType, !conferenceType.isEmpty {
            queryItems.append(URLQueryItem(name: "conferenceType", value: conferenceType))
        }
        
        // Minimum resources filter (if specified)  
        if let minResources = filters.minResources, minResources > 0 {
            queryItems.append(URLQueryItem(name: "minResources", value: "\(minResources)"))
        }
        
        // Sort order (default: date_desc)
        queryItems.append(URLQueryItem(name: "sort", value: "date_desc"))
        
        components.queryItems = queryItems
        
        guard let url = components.url else {
            throw APIError.invalidURL
        }
        
        let request = URLRequest(url: url)
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError(NSError(domain: "Invalid response", code: -1))
        }
        
        guard httpResponse.statusCode == 200 else {
            throw APIError.serverError
        }
        
        do {
            let apiResponse = try decoder.decode(ConferencesAPIResponse.self, from: data)
            return ConferencesResponse(
                conferences: apiResponse.conferences.map { $0.toConferenceInfo() },
                page: apiResponse.currentPage,
                totalPages: apiResponse.totalPages,
                totalCount: apiResponse.totalCount,
                hasMore: apiResponse.hasNextPage
            )
        } catch {
            throw APIError.decodingError(error)
        }
    }
    
    /// Fetches details for a specific conference
    func fetchConferenceDetail(id: String) async throws -> ConferenceInfo {
        
        // Use mock data if configured
        if Config.useMockServices {
            return await mockFetchConferenceDetail(id: id)
        }
        
        let url = URL(string: "\(baseURL)/\(id)")!
        let request = URLRequest(url: url)
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError(NSError(domain: "Invalid response", code: -1))
        }
        
        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 404 {
                throw APIError.notFound
            }
            throw APIError.serverError
        }
        
        do {
            let apiConference = try decoder.decode(ConferenceAPIResponse.self, from: data)
            return apiConference.toConferenceInfo()
        } catch {
            throw APIError.decodingError(error)
        }
    }
    
    /// Fetches resources for a specific conference
    func fetchConferenceResources(conferenceId: String, page: Int = 1) async throws -> TalksResponse {
        
        // Use mock data if configured
        if Config.useMockServices {
            return await mockFetchConferenceResources(conferenceId: conferenceId, page: page)
        }
        
        // Fetch the conference detail which includes resources
        let url = URL(string: "\(baseURL)/\(conferenceId)")!
        let request = URLRequest(url: url)
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError(NSError(domain: "Invalid response", code: -1))
        }
        
        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 404 {
                throw APIError.notFound
            }
            throw APIError.serverError
        }
        
        do {
            let apiConference = try decoder.decode(ConferenceAPIResponse.self, from: data)
            
            // Convert conference resources to Talk objects
            let talks = apiConference.resources?.compactMap { resource in
                convertConferenceResourceToTalk(resource, conferenceId: conferenceId)
            } ?? []
            
            return TalksResponse(
                talks: talks,
                page: page,
                totalPages: 1,
                totalCount: talks.count,
                hasMore: false
            )
        } catch {
            throw APIError.decodingError(error)
        }
    }
    
    /// Fetches available years for filtering
    func fetchAvailableYears() async throws -> [String] {
        // Use mock data if configured
        if Config.useMockServices {
            return ["2024", "2023", "2022", "2021", "2020"]
        }
        
        let url = URL(string: "\(baseURL)/years")!
        let request = URLRequest(url: url)
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError(NSError(domain: "Invalid response", code: -1))
        }
        
        guard httpResponse.statusCode == 200 else {
            throw APIError.serverError
        }
        
        do {
            let yearsResponse = try decoder.decode(YearsAPIResponse.self, from: data)
            return yearsResponse.years.map { String($0) }
        } catch {
            throw APIError.decodingError(error)
        }
    }
    
    /// Fetches available conference types
    func fetchConferenceTypes() async throws -> [ConferenceType] {
        // Use mock data if configured
        if Config.useMockServices {
            return [
                ConferenceType(id: "1", name: "Mission Conference", conferenceCount: 15, resourceCount: 180),
                ConferenceType(id: "2", name: "Training Event", conferenceCount: 8, resourceCount: 95)
            ]
        }
        
        let url = URL(string: "\(baseURL)/types")!
        let request = URLRequest(url: url)
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError(NSError(domain: "Invalid response", code: -1))
        }
        
        guard httpResponse.statusCode == 200 else {
            throw APIError.serverError
        }
        
        do {
            let typesResponse = try decoder.decode(ConferenceTypesAPIResponse.self, from: data)
            return typesResponse.types
        } catch {
            throw APIError.decodingError(error)
        }
    }
    
    // MARK: - Helper Methods
    
    /// Convert a ConferenceResourceAPI to a Talk object
    private func convertConferenceResourceToTalk(_ resource: ConferenceResourceAPI, conferenceId: String) -> Talk? {
        // Parse the date if available
        let dateRecorded: Date
        if let dateString = resource.dateRecorded {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            dateRecorded = formatter.date(from: dateString) ?? Date()
        } else {
            dateRecorded = Date()
        }
        
        // Extract speaker information
        let speaker = resource.speakers?.first?.fullName ?? "Unknown Speaker"
        
        // Extract Bible book information
        let biblePassage = resource.books?.first?.name ?? ""
        
        return Talk(
            id: resource.id,
            title: resource.title,
            description: resource.description ?? "",
            speaker: speaker,
            series: nil, // Not provided by conferences API
            biblePassage: biblePassage,
            dateRecorded: dateRecorded,
            duration: 0, // Not provided by conferences API
            audioURL: resource.audioUrl,
            videoURL: resource.videoUrl,
            imageURL: resource.imageUrl,
            conferenceImageURL: nil, // Will be set from conference
            defaultImageURL: nil,
            fileSize: nil,
            category: nil, // Not provided by conferences API
            scriptureReference: resource.scriptureReference,
            conferenceId: conferenceId,
            speakerIds: resource.speakers?.map { $0.id },
            bookIds: resource.books?.map { $0.id }
        )
    }
}

// MARK: - API Response Models

/// API response model for conferences list
struct ConferencesAPIResponse: Codable {
    let conferences: [ConferenceAPI]
    let currentPage: Int
    let totalPages: Int
    let totalCount: Int
    let hasNextPage: Bool
}

/// API response model for single conference
struct ConferenceAPIResponse: Codable {
    let id: String
    let name: String
    let year: String
    let description: String?
    let imageUrl: String?
    let conferenceType: ConferenceTypeAPI?
    let resources: [ConferenceResourceAPI]?
}

/// API model for conference in list
struct ConferenceAPI: Codable {
    let id: String
    let name: String
    let year: String
    let description: String?
    let imageUrl: String?
    let resourceCount: Int
    let conferenceType: ConferenceTypeAPI?
}

/// API model for conference type
struct ConferenceTypeAPI: Codable {
    let id: String
    let name: String
}

/// API model for conference resource
struct ConferenceResourceAPI: Codable {
    let id: String
    let title: String
    let description: String?
    let audioUrl: String?
    let videoUrl: String?
    let imageUrl: String?
    let dateRecorded: String?
    let scriptureReference: String?
    let speakers: [SpeakerAPI]?
    let books: [BookAPI]?
}

/// API model for speaker
struct SpeakerAPI: Codable {
    let id: String
    let firstName: String
    let lastName: String
    let fullName: String
}

/// API model for Bible book
struct BookAPI: Codable {
    let id: String
    let name: String
}

/// API response model for years
struct YearsAPIResponse: Codable {
    let years: [Int]
    let totalCount: Int
}

/// API response model for conference types
struct ConferenceTypesAPIResponse: Codable {
    let types: [ConferenceType]
    let totalCount: Int
}

// MARK: - Model Conversion Extensions

extension ConferenceAPI {
    func toConferenceInfo() -> ConferenceInfo {
        return ConferenceInfo(
            id: id,
            title: name,
            year: year,
            imageURL: imageUrl,
            resourceCount: resourceCount,
            description: description,
            conferenceType: conferenceType?.toConferenceTypeInfo()
        )
    }
}

extension ConferenceAPIResponse {
    func toConferenceInfo() -> ConferenceInfo {
        return ConferenceInfo(
            id: id,
            title: name,
            year: year,
            imageURL: imageUrl,
            resourceCount: resources?.count ?? 0,
            description: description,
            conferenceType: conferenceType?.toConferenceTypeInfo()
        )
    }
}

extension ConferenceTypeAPI {
    func toConferenceTypeInfo() -> ConferenceInfo.ConferenceTypeInfo {
        return ConferenceInfo.ConferenceTypeInfo(id: id, name: name)
    }
}

// MARK: - Mock Implementation

extension ConferencesAPIService {
    
    private func mockFetchConferences(filters: ConferenceSearchFilters, page: Int) async -> ConferencesResponse {
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        var conferences = ConferenceInfo.mockConferences
        
        // Apply search filter
        if !filters.query.isEmpty {
            conferences = conferences.filter { conference in
                conference.title.localizedCaseInsensitiveContains(filters.query) ||
                conference.year.localizedCaseInsensitiveContains(filters.query)
            }
        }
        
        // Apply year filters
        if !filters.years.isEmpty {
            conferences = conferences.filter { conference in
                filters.years.contains(conference.year)
            }
        }
        
        // Sort: most recent first
        conferences = conferences.sorted { $0.year > $1.year }
        
        // Paginate
        let pageSize = 20
        let startIndex = (page - 1) * pageSize
        let endIndex = min(startIndex + pageSize, conferences.count)
        
        if startIndex >= conferences.count {
            return ConferencesResponse(
                conferences: [],
                page: page,
                totalPages: max(1, (conferences.count + pageSize - 1) / pageSize),
                totalCount: conferences.count,
                hasMore: false
            )
        }
        
        let pagedConferences = Array(conferences[startIndex..<endIndex])
        let totalPages = max(1, (conferences.count + pageSize - 1) / pageSize)
        
        return ConferencesResponse(
            conferences: pagedConferences,
            page: page,
            totalPages: totalPages,
            totalCount: conferences.count,
            hasMore: page < totalPages
        )
    }
    
    private func mockFetchConferenceDetail(id: String) async -> ConferenceInfo {
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        return ConferenceInfo.mockConferences.first { $0.id == id } ?? ConferenceInfo.mockConferences.first!
    }
    
    private func mockFetchConferenceResources(conferenceId: String, page: Int) async -> TalksResponse {
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        // Return mock talks for the conference
        let mockTalks = Talk.mockTalks.filter { $0.conferenceId == conferenceId }
        
        return TalksResponse(
            talks: mockTalks,
            page: page,
            totalPages: 1,
            totalCount: mockTalks.count,
            hasMore: false
        )
    }
}

// MARK: - Mock Service for Testing

final class MockConferencesAPIService: ConferencesAPIServiceProtocol {
    
    var shouldFail = false
    var mockConferences = ConferenceInfo.mockConferences
    
    func fetchConferences(filters: ConferenceSearchFilters, page: Int) async throws -> ConferencesResponse {
        if shouldFail {
            throw APIError.serverError
        }
        
        return ConferencesResponse(
            conferences: mockConferences,
            page: 1,
            totalPages: 1,
            totalCount: mockConferences.count,
            hasMore: false
        )
    }
    
    func fetchConferenceDetail(id: String) async throws -> ConferenceInfo {
        if shouldFail {
            throw APIError.notFound
        }
        
        return mockConferences.first { $0.id == id } ?? mockConferences.first!
    }
    
    func fetchConferenceResources(conferenceId: String, page: Int) async throws -> TalksResponse {
        if shouldFail {
            throw APIError.serverError
        }
        
        // Return mock talks that match the conference
        let mockTalks = Talk.mockTalks.filter { $0.conferenceId == conferenceId }
        
        return TalksResponse(
            talks: mockTalks,
            page: page,
            totalPages: 1,
            totalCount: mockTalks.count,
            hasMore: false
        )
    }
    
    func fetchAvailableYears() async throws -> [String] {
        if shouldFail {
            throw APIError.serverError
        }
        
        return ["2024", "2023", "2022", "2021", "2020"]
    }
    
    func fetchConferenceTypes() async throws -> [ConferenceType] {
        if shouldFail {
            throw APIError.serverError
        }
        
        return [
            ConferenceType(id: "1", name: "Mission Conference", conferenceCount: 15, resourceCount: 180),
            ConferenceType(id: "2", name: "Training Event", conferenceCount: 8, resourceCount: 95)
        ]
    }
}