//
//  Conference.swift
//  PT Resources
//
//  Models for conferences and conference-related data
//

import Foundation

/// Main conference model representing a conference event
struct ConferenceInfo: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let year: String
    let imageURL: String?
    let resourceCount: Int
    let description: String?
    let conferenceType: ConferenceTypeInfo?
    
    enum CodingKeys: String, CodingKey {
        case id
        case title = "name"
        case year
        case imageURL = "imageUrl"
        case resourceCount
        case description
        case conferenceType
    }
    
    // Conference type info embedded in conference
    struct ConferenceTypeInfo: Codable, Hashable {
        let id: String
        let name: String
    }
    
    init(
        id: String,
        title: String,
        year: String,
        imageURL: String? = nil,
        resourceCount: Int = 0,
        description: String? = nil,
        conferenceType: ConferenceTypeInfo? = nil
    ) {
        self.id = id
        self.title = title
        self.year = year
        self.imageURL = imageURL
        self.resourceCount = resourceCount
        self.description = description
        self.conferenceType = conferenceType
    }
    
    
    // Computed properties
    var formattedYear: String {
        return year
    }
    
    var displayTitle: String {
        if title.contains(year) {
            return title
        } else {
            return "\(title) \(year)"
        }
    }
    
    // Image URL with fallback handling
    var artworkURL: String? {
        // Return the conference image URL if available
        if let imageURL = imageURL, !imageURL.isEmpty {
            return constructFullURL(from: imageURL)
        }
        
        // Return nil to trigger fallback to local bundle asset in UI
        return nil
    }
    
    // Helper to construct full URLs from relative paths
    private func constructFullURL(from urlString: String) -> String {
        // If already a full URL, return as-is
        if urlString.hasPrefix("http://") || urlString.hasPrefix("https://") {
            return urlString
        }
        
        // Special case: use local asset for PT Resources logo
        if urlString == "/images/brand/logos/pt-resources.svg" {
            // Return the local asset path - PTAsyncImage should handle bundle resources
            return "pt-resources" // This will be handled as a bundle resource name
        }
        
        // If it starts with "/", it's a relative URL from the root
        if urlString.hasPrefix("/") {
            return "https://www.proctrust.org.uk\(urlString)"
        }
        // Otherwise, assume it needs the full base URL
        return "https://www.proctrust.org.uk/\(urlString)"
    }
}

/// Response model for conference list
struct ConferencesResponse: Codable {
    let conferences: [ConferenceInfo]
    let page: Int
    let totalPages: Int
    let totalCount: Int
    let hasMore: Bool
    
    enum CodingKeys: String, CodingKey {
        case conferences
        case page = "currentPage"
        case totalPages
        case totalCount
        case hasMore = "hasNextPage"
    }
}

/// Conference search filters
struct ConferenceSearchFilters: Codable {
    var query: String = ""
    var year: String? = nil
    var years: [String] = []
    var conferenceType: String? = nil
    var minResources: Int? = nil
    
    var isEmpty: Bool {
        return query.isEmpty && year == nil && years.isEmpty && 
               conferenceType == nil && minResources == nil
    }
    
    // Helper methods for managing filter arrays
    mutating func addYear(_ year: String) {
        if !years.contains(year) {
            years.append(year)
        }
    }
    
    mutating func removeYear(_ year: String) {
        years.removeAll { $0 == year }
    }
}

// MARK: - Mock Data for Development

extension ConferenceInfo {
    static let mockConferences: [ConferenceInfo] = [
        ConferenceInfo(
            id: "mock-conference-1",
            title: "EMA 2024",
            year: "2024",
            imageURL: "/images/conferences/ema-2024.jpg",
            resourceCount: 15,
            description: "European Mission Academy 2024 - Equipping the next generation of gospel workers"
        ),
        ConferenceInfo(
            id: "mock-conference-2", 
            title: "Women in Ministry 2024",
            year: "2024",
            imageURL: "/images/conferences/wim-2024.jpg",
            resourceCount: 8,
            description: "A conference for women serving in gospel ministry"
        ),
        ConferenceInfo(
            id: "mock-conference-3",
            title: "Teaching Morning for Women",
            year: "2024", 
            imageURL: "/images/conferences/tmw-2024.jpg",
            resourceCount: 6,
            description: "Online teaching sessions focused on biblical exposition"
        ),
        ConferenceInfo(
            id: "mock-conference-4",
            title: "EMA 2023",
            year: "2023",
            imageURL: "/images/conferences/ema-2023.jpg", 
            resourceCount: 12,
            description: "European Mission Academy 2023 - Training for gospel ministry"
        ),
        ConferenceInfo(
            id: "mock-conference-5",
            title: "Cornhill Training Course",
            year: "2023",
            imageURL: "/images/conferences/cornhill-2023.jpg",
            resourceCount: 24,
            description: "Comprehensive Bible teaching and ministry training"
        )
    ]
}