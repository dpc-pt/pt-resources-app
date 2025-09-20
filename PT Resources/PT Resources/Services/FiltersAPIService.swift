//
//  FiltersAPIService.swift
//  PT Resources
//
//  Service for fetching available filter options from the PT API
//

import Foundation

// MARK: - Filter Option Models

struct FilterOptions: Codable {
    let speakers: [FiltersSpeaker]
    let conferences: [Conference]
    let conferenceTypes: [ConferenceType]
    let bibleBooks: [BibleBook]
    let years: [YearInfo]
    let collections: [Collection]
    
    enum CodingKeys: String, CodingKey {
        case speakers, conferences, years, collections, conferenceTypes
        case bibleBooks = "books"
    }
}

struct FiltersSpeaker: Codable, Identifiable, Hashable {
    let id: String
    let firstName: String
    let lastName: String
    let name: String
    
    enum CodingKeys: String, CodingKey {
        case id, name, firstName = "first_name", lastName = "last_name"
    }
}

struct Conference: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let year: String?
    
    enum CodingKeys: String, CodingKey {
        case id, name, year
    }
}

struct ConferenceType: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let conferenceCount: Int?
    let resourceCount: Int?
    
    init(id: String, name: String, conferenceCount: Int? = nil, resourceCount: Int? = nil) {
        self.id = id
        self.name = name
        self.conferenceCount = conferenceCount
        self.resourceCount = resourceCount
    }
}

struct BibleBook: Codable, Identifiable, Hashable {
    let id: String
    let name: String
}

struct YearInfo: Codable, Identifiable, Hashable {
    let id: String
    let year: String
}

struct Collection: Codable, Identifiable, Hashable {
    let id: String
    let name: String
}

// Convenience wrapper for UI display
struct FilterOption: Identifiable, Hashable {
    let id: String
    let name: String
    let count: Int?
    
    init(id: String, name: String, count: Int? = nil) {
        self.id = id
        self.name = name
        self.count = count
    }
    
    // Convert from FiltersSpeaker
    init(from speaker: FiltersSpeaker) {
        self.id = speaker.id
        self.name = speaker.name
        self.count = nil
    }
    
    // Convert from Conference
    init(from conference: Conference) {
        self.id = conference.id
        if let year = conference.year {
            self.name = "\(conference.name) (\(year))"
        } else {
            self.name = conference.name
        }
        self.count = nil
    }
    
    // Convert from ConferenceType
    init(from conferenceType: ConferenceType) {
        self.id = conferenceType.id
        self.name = conferenceType.name
        self.count = nil
    }
    
    // Convert from BibleBook
    init(from bibleBook: BibleBook) {
        self.id = bibleBook.id
        self.name = bibleBook.name
        self.count = nil
    }
    
    // Convert from YearInfo
    init(from yearInfo: YearInfo) {
        self.id = yearInfo.id
        self.name = yearInfo.year
        self.count = nil
    }
    
    // Convert from Collection
    init(from collection: Collection) {
        self.id = collection.id
        self.name = collection.name
        self.count = nil
    }
}

// MARK: - Quick Filter Options

struct QuickFilterOption: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let filterType: QuickFilterType
    let value: String
    let icon: String
    let color: String
}

enum QuickFilterType {
    case bibleBook
    case topic
    case speaker
    case series
}

// MARK: - Filters API Service Protocol

protocol FiltersAPIServiceProtocol {
    func fetchFilterOptions() async throws -> FilterOptions
    func getQuickFilters() -> [QuickFilterOption]
    func getSpeakerFilterOptions() async throws -> [FilterOption]
    func getConferenceFilterOptions() async throws -> [FilterOption]
    func getConferenceTypeFilterOptions() async throws -> [FilterOption]
    func getBibleBookFilterOptions() async throws -> [FilterOption]
    func getYearFilterOptions() async throws -> [FilterOption]
    func getCollectionFilterOptions() async throws -> [FilterOption]
}

// MARK: - Filters API Service

final class FiltersAPIService: FiltersAPIServiceProtocol, ObservableObject {
    
    private let session: URLSession
    private let decoder: JSONDecoder
    @Published private var cachedFilters: FilterOptions?
    
    init(session: URLSession = .shared) {
        self.session = session
        self.decoder = JSONDecoder()
        
        // Configure date decoding if needed
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        decoder.dateDecodingStrategy = .formatted(formatter)
    }
    
    // MARK: - Public Methods
    
    func fetchFilterOptions() async throws -> FilterOptions {
        
        // Return cached filters if available and recent
        if let cached = cachedFilters {
            return cached
        }
        
        // Use mock data if configured
        if Config.useMockServices {
            return await mockFetchFilterOptions()
        }
        
        let endpoint = Config.APIEndpoint.filters
        
        guard let url = URL(string: endpoint.url) else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = Config.apiTimeout
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            switch httpResponse.statusCode {
            case 200:
                break
            case 400:
                throw APIError.badRequest(data)
            case 401:
                throw APIError.unauthorized
            case 403:
                throw APIError.forbidden
            case 404:
                throw APIError.notFound
            case 429:
                throw APIError.rateLimited
            case 500...599:
                throw APIError.serverError
            default:
                throw APIError.unknown(statusCode: httpResponse.statusCode, data: data)
            }
            
            let filterOptions = try decoder.decode(FilterOptions.self, from: data)
            
            // Cache the results
            await MainActor.run {
                self.cachedFilters = filterOptions
            }
            
            return filterOptions
            
        } catch {
            if error is APIError {
                throw error
            } else {
                throw APIError.networkError(error)
            }
        }
    }
    
    func getQuickFilters() -> [QuickFilterOption] {
        return [
            QuickFilterOption(
                title: "Matthew", 
                filterType: .bibleBook, 
                value: "40", 
                icon: "book.closed",
                color: "kleinBlue"
            ),
            QuickFilterOption(
                title: "Romans", 
                filterType: .bibleBook, 
                value: "45", 
                icon: "book.closed",
                color: "tang"
            ),
            QuickFilterOption(
                title: "Prayer", 
                filterType: .topic, 
                value: "Prayer", 
                icon: "hands.sparkles",
                color: "lawn"
            ),
            QuickFilterOption(
                title: "Leadership", 
                filterType: .topic, 
                value: "Leadership", 
                icon: "person.2",
                color: "turmeric"
            ),
            QuickFilterOption(
                title: "Evangelism", 
                filterType: .topic, 
                value: "Evangelism", 
                icon: "megaphone",
                color: "kleinBlue"
            ),
            QuickFilterOption(
                title: "John Stott", 
                filterType: .speaker, 
                value: "john-stott", 
                icon: "person.circle",
                color: "tang"
            )
        ]
    }
    
    func getSpeakerFilterOptions() async throws -> [FilterOption] {
        let filterOptions = try await fetchFilterOptions()
        return filterOptions.speakers.map { FilterOption(from: $0) }
    }
    
    func getConferenceFilterOptions() async throws -> [FilterOption] {
        let filterOptions = try await fetchFilterOptions()
        return filterOptions.conferences.map { FilterOption(from: $0) }
    }
    
    func getConferenceTypeFilterOptions() async throws -> [FilterOption] {
        let filterOptions = try await fetchFilterOptions()
        return filterOptions.conferenceTypes.map { FilterOption(from: $0) }
    }
    
    func getBibleBookFilterOptions() async throws -> [FilterOption] {
        let filterOptions = try await fetchFilterOptions()
        return filterOptions.bibleBooks.map { FilterOption(from: $0) }
    }
    
    func getYearFilterOptions() async throws -> [FilterOption] {
        let filterOptions = try await fetchFilterOptions()
        return filterOptions.years.map { FilterOption(from: $0) }
    }
    
    func getCollectionFilterOptions() async throws -> [FilterOption] {
        let filterOptions = try await fetchFilterOptions()
        return filterOptions.collections.map { FilterOption(from: $0) }
    }
    
    // MARK: - Cache Management
    
    func clearCache() {
        cachedFilters = nil
    }
}

// MARK: - Mock Implementation

extension FiltersAPIService {
    
    private func mockFetchFilterOptions() async -> FilterOptions {
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        return FilterOptions(
            speakers: [
                FiltersSpeaker(id: "john-stott", firstName: "John", lastName: "Stott", name: "John Stott"),
                FiltersSpeaker(id: "dick-lucas", firstName: "Dick", lastName: "Lucas", name: "Dick Lucas"),
                FiltersSpeaker(id: "vaughan-roberts", firstName: "Vaughan", lastName: "Roberts", name: "Vaughan Roberts"),
                FiltersSpeaker(id: "david-jackman", firstName: "David", lastName: "Jackman", name: "David Jackman"),
                FiltersSpeaker(id: "peter-jensen", firstName: "Peter", lastName: "Jensen", name: "Peter Jensen"),
                FiltersSpeaker(id: "christopher-ash", firstName: "Christopher", lastName: "Ash", name: "Christopher Ash")
            ],
            conferences: [
                Conference(id: "word-alive-2024", name: "Word Alive", year: "2024"),
                Conference(id: "ema-2024", name: "Evangelical Ministry Assembly", year: "2024"),
                Conference(id: "women-in-ministry-2023", name: "Women in Ministry", year: "2023"),
                Conference(id: "preachers-conference-2024", name: "Preachers Conference", year: "2024")
            ],
            conferenceTypes: [
                ConferenceType(id: "main-talk", name: "Main Talk"),
                ConferenceType(id: "seminar", name: "Seminar"),
                ConferenceType(id: "workshop", name: "Workshop"),
                ConferenceType(id: "panel", name: "Panel Discussion"),
                ConferenceType(id: "qa", name: "Q&A Session")
            ],
            bibleBooks: [
                BibleBook(id: "1", name: "Genesis"),
                BibleBook(id: "2", name: "Exodus"),
                BibleBook(id: "40", name: "Matthew"),
                BibleBook(id: "41", name: "Mark"),
                BibleBook(id: "42", name: "Luke"),
                BibleBook(id: "43", name: "John"),
                BibleBook(id: "44", name: "Acts"),
                BibleBook(id: "45", name: "Romans"),
                BibleBook(id: "46", name: "1 Corinthians"),
                BibleBook(id: "47", name: "2 Corinthians")
            ],
            years: [
                YearInfo(id: "2024", year: "2024"),
                YearInfo(id: "2023", year: "2023"),
                YearInfo(id: "2022", year: "2022"),
                YearInfo(id: "2021", year: "2021"),
                YearInfo(id: "2020", year: "2020"),
                YearInfo(id: "2019", year: "2019"),
                YearInfo(id: "2018", year: "2018")
            ],
            collections: [
                Collection(id: "word-alive", name: "Word Alive"),
                Collection(id: "keswick", name: "Keswick Convention"),
                Collection(id: "training", name: "Training Course"),
                Collection(id: "expository", name: "Expository Preaching"),
                Collection(id: "ema", name: "EMA Pen portraits")
            ]
        )
    }
}

// MARK: - Mock Service for Testing

final class MockFiltersAPIService: FiltersAPIServiceProtocol {
    
    var shouldFail = false
    
    func fetchFilterOptions() async throws -> FilterOptions {
        if shouldFail {
            throw APIError.serverError
        }
        
        // Use the same mock data as the main service
        return await mockFetchFilterOptions()
    }
    
    private func mockFetchFilterOptions() async -> FilterOptions {
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        return FilterOptions(
            speakers: [
                FiltersSpeaker(id: "john-stott", firstName: "John", lastName: "Stott", name: "John Stott"),
                FiltersSpeaker(id: "dick-lucas", firstName: "Dick", lastName: "Lucas", name: "Dick Lucas"),
                FiltersSpeaker(id: "vaughan-roberts", firstName: "Vaughan", lastName: "Roberts", name: "Vaughan Roberts"),
                FiltersSpeaker(id: "david-jackman", firstName: "David", lastName: "Jackman", name: "David Jackman"),
                FiltersSpeaker(id: "peter-jensen", firstName: "Peter", lastName: "Jensen", name: "Peter Jensen"),
                FiltersSpeaker(id: "christopher-ash", firstName: "Christopher", lastName: "Ash", name: "Christopher Ash")
            ],
            conferences: [
                Conference(id: "word-alive-2024", name: "Word Alive", year: "2024"),
                Conference(id: "ema-2024", name: "Evangelical Ministry Assembly", year: "2024"),
                Conference(id: "women-in-ministry-2023", name: "Women in Ministry", year: "2023"),
                Conference(id: "preachers-conference-2024", name: "Preachers Conference", year: "2024")
            ],
            conferenceTypes: [
                ConferenceType(id: "main-talk", name: "Main Talk"),
                ConferenceType(id: "seminar", name: "Seminar"),
                ConferenceType(id: "workshop", name: "Workshop"),
                ConferenceType(id: "panel", name: "Panel Discussion"),
                ConferenceType(id: "qa", name: "Q&A Session")
            ],
            bibleBooks: [
                BibleBook(id: "1", name: "Genesis"),
                BibleBook(id: "2", name: "Exodus"),
                BibleBook(id: "40", name: "Matthew"),
                BibleBook(id: "41", name: "Mark"),
                BibleBook(id: "42", name: "Luke"),
                BibleBook(id: "43", name: "John"),
                BibleBook(id: "44", name: "Acts"),
                BibleBook(id: "45", name: "Romans"),
                BibleBook(id: "46", name: "1 Corinthians"),
                BibleBook(id: "47", name: "2 Corinthians")
            ],
            years: [
                YearInfo(id: "2024", year: "2024"),
                YearInfo(id: "2023", year: "2023"),
                YearInfo(id: "2022", year: "2022"),
                YearInfo(id: "2021", year: "2021"),
                YearInfo(id: "2020", year: "2020"),
                YearInfo(id: "2019", year: "2019"),
                YearInfo(id: "2018", year: "2018")
            ],
            collections: [
                Collection(id: "word-alive", name: "Word Alive"),
                Collection(id: "keswick", name: "Keswick Convention"),
                Collection(id: "training", name: "Training Course"),
                Collection(id: "expository", name: "Expository Preaching"),
                Collection(id: "ema", name: "EMA Pen portraits")
            ]
        )
    }
    
    func getQuickFilters() -> [QuickFilterOption] {
        let service = FiltersAPIService()
        return service.getQuickFilters()
    }
    
    func getSpeakerFilterOptions() async throws -> [FilterOption] {
        let filterOptions = try await fetchFilterOptions()
        return filterOptions.speakers.map { FilterOption(from: $0) }
    }
    
    func getConferenceFilterOptions() async throws -> [FilterOption] {
        let filterOptions = try await fetchFilterOptions()
        return filterOptions.conferences.map { FilterOption(from: $0) }
    }
    
    func getConferenceTypeFilterOptions() async throws -> [FilterOption] {
        let filterOptions = try await fetchFilterOptions()
        return filterOptions.conferenceTypes.map { FilterOption(from: $0) }
    }
    
    func getBibleBookFilterOptions() async throws -> [FilterOption] {
        let filterOptions = try await fetchFilterOptions()
        return filterOptions.bibleBooks.map { FilterOption(from: $0) }
    }
    
    func getYearFilterOptions() async throws -> [FilterOption] {
        let filterOptions = try await fetchFilterOptions()
        return filterOptions.years.map { FilterOption(from: $0) }
    }
    
    func getCollectionFilterOptions() async throws -> [FilterOption] {
        let filterOptions = try await fetchFilterOptions()
        return filterOptions.collections.map { FilterOption(from: $0) }
    }
}
