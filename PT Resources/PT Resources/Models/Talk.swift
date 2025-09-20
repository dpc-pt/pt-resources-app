//
//  Talk.swift
//  PT Resources
//
//  API models for talks and related data
//

import Foundation



/// Main talk model representing a sermon/lecture
struct Talk: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let description: String?
    let speaker: String
    let series: String?
    let biblePassage: String?
    let dateRecorded: Date
    let duration: Int // Duration in seconds
    let audioURL: String?
    let videoURL: String?
    let imageURL: String?
    let conferenceImageURL: String?
    let defaultImageURL: String?
    let fileSize: Int64?
    let category: String?
    let scriptureReference: String?
    let conferenceId: String?
    let speakerIds: [String]?
    let bookIds: [String]?
    
    enum CodingKeys: String, CodingKey {
        case id, title, description, speaker, series, category
        case biblePassage = "scriptureReference"
        case dateRecorded = "date"
        case duration
        case audioURL = "audioUrl"
        case videoURL = "videoUrl"  
        case imageURL = "imageUrl"
        case conferenceImageURL = "conferenceImageUrl"  // Matches actual API response
        case defaultImageURL = "defaultImageUrl"
        case fileSize
        case conferenceId
        case speakerIds
        case bookIds
    }
    
    // Custom decoder to handle API response format
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        speaker = try container.decode(String.self, forKey: .speaker)
        series = try container.decodeIfPresent(String.self, forKey: .series)
        
        audioURL = try container.decodeIfPresent(String.self, forKey: .audioURL)
        videoURL = try container.decodeIfPresent(String.self, forKey: .videoURL)
        
        imageURL = try container.decodeIfPresent(String.self, forKey: .imageURL)
        conferenceImageURL = try container.decodeIfPresent(String.self, forKey: .conferenceImageURL)
        defaultImageURL = try container.decodeIfPresent(String.self, forKey: .defaultImageURL)
        fileSize = try container.decodeIfPresent(Int64.self, forKey: .fileSize)
        category = try container.decodeIfPresent(String.self, forKey: .category)
        
        // Both scriptureReference and biblePassage map to the same API field
        let scriptureRef = try container.decodeIfPresent(String.self, forKey: .biblePassage)
        scriptureReference = scriptureRef
        biblePassage = scriptureRef
        
        // Parse date - API returns year string like "2025"
        let dateString = try container.decode(String.self, forKey: .dateRecorded)
        if let year = Int(dateString) {
            dateRecorded = Calendar.current.date(from: DateComponents(year: year)) ?? Date()
        } else {
            dateRecorded = Date()
        }
        
        // Duration not provided in API response, default to 0
        duration = try container.decodeIfPresent(Int.self, forKey: .duration) ?? 0
        
        // Additional fields from the actual API response
        conferenceId = try container.decodeIfPresent(String.self, forKey: .conferenceId)
        speakerIds = try container.decodeIfPresent([String].self, forKey: .speakerIds)
        bookIds = try container.decodeIfPresent([String].self, forKey: .bookIds)
    }
    
    // Standard init for mock data and internal use
    init(
        id: String,
        title: String,
        description: String? = nil,
        speaker: String,
        series: String? = nil,
        biblePassage: String? = nil,
        dateRecorded: Date,
        duration: Int = 0,
        audioURL: String? = nil,
        videoURL: String? = nil,
        imageURL: String? = nil,
        conferenceImageURL: String? = nil,
        defaultImageURL: String? = nil,
        fileSize: Int64? = nil,
        category: String? = nil,
        scriptureReference: String? = nil,
        conferenceId: String? = nil,
        speakerIds: [String]? = nil,
        bookIds: [String]? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.speaker = speaker
        self.series = series
        self.biblePassage = biblePassage
        self.dateRecorded = dateRecorded
        self.duration = duration
        self.audioURL = audioURL
        self.videoURL = videoURL
        self.imageURL = imageURL
        self.conferenceImageURL = conferenceImageURL
        self.defaultImageURL = defaultImageURL
        self.fileSize = fileSize
        self.category = category
        self.scriptureReference = scriptureReference
        self.conferenceId = conferenceId
        self.speakerIds = speakerIds
        self.bookIds = bookIds
    }
    
    // Computed properties
    var formattedDuration: String {
        let minutes = duration / 60
        let seconds = duration % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    // Media availability
    var hasAudio: Bool {
        return audioURL != nil && !audioURL!.isEmpty
    }
    
    var hasVideo: Bool {
        return processedVideoURL != nil
    }
    
    var availableMediaTypes: [MediaType] {
        var types: [MediaType] = []
        if hasAudio { types.append(.audio) }
        if hasVideo { types.append(.video) }
        return types
    }
    
    var hasMultipleMediaTypes: Bool {
        return availableMediaTypes.count > 1
    }
    
    var primaryMediaType: MediaType? {
        if hasAudio { return .audio }
        if hasVideo { return .video }
        return nil
    }
    
    // MARK: - URL Processing
    
    /// Returns a properly formatted video URL, handling Vimeo IDs
    var processedVideoURL: URL? {
        guard let videoURL = videoURL, !videoURL.isEmpty else { return nil }
        
        // If it's already a full URL, return it
        if videoURL.hasPrefix("http") {
            return URL(string: videoURL)
        }
        
        // If it's just a number (Vimeo ID), construct the full URL
        if videoURL.allSatisfy({ $0.isNumber }) {
            return URL(string: "https://player.vimeo.com/video/\(videoURL)")
        }
        
        // If it's a relative URL, construct the full URL
        return URL(string: "https://www.proctrust.org.uk\(videoURL)")
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: dateRecorded)
    }
    
    var formattedYear: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter.string(from: dateRecorded)
    }
    
    var shareURL: String {
        "\(Config.universalLinkDomain)/talks/\(id)"
    }
    
    // Computed property for artwork URL with fallback priority
    var artworkURL: String? {
        // Priority: imageURL -> conferenceImageURL -> defaultImageURL
        if let imageURL = imageURL, !imageURL.isEmpty {
            return constructFullURL(from: imageURL)
        }
        if let conferenceImageURL = conferenceImageURL, !conferenceImageURL.isEmpty {
            return constructFullURL(from: conferenceImageURL)
        }
        if let defaultImageURL = defaultImageURL, !defaultImageURL.isEmpty {
            return constructFullURL(from: defaultImageURL)
        }
        
        // Return nil if no artwork is available - let the UI handle the fallback
        return nil
    }
    
    // Helper to construct full URLs from relative paths
    private func constructFullURL(from urlString: String) -> String {
        // If already a full URL, return as-is
        if urlString.hasPrefix("http://") || urlString.hasPrefix("https://") {
            return urlString
        }
        // If it starts with "/", it's a relative URL from the root
        if urlString.hasPrefix("/") {
            return "https://www.proctrust.org.uk\(urlString)"
        }
        // Otherwise, assume it needs the full base URL
        return "https://www.proctrust.org.uk/\(urlString)"
    }
}

/// Response model for individual talk detail
struct TalkDetailResponse: Codable {
    let resource: Talk
}

/// Response model for paginated talks
struct TalksResponse: Codable {
    let talks: [Talk]
    let page: Int
    let totalPages: Int
    let totalCount: Int
    let hasMore: Bool
    
    enum CodingKeys: String, CodingKey {
        case talks = "resources"
        case page = "currentPage"
        case totalPages
        case totalCount
        case hasMore = "hasNextPage"
    }
}

/// Speaker information
struct Speaker: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let bio: String?
    let imageURL: String?
    
    enum CodingKeys: String, CodingKey {
        case id, name, bio
        case imageURL = "image_url"
    }
}

/// Series information
struct Series: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let description: String?
    let imageURL: String?
    let talkCount: Int?
    
    enum CodingKeys: String, CodingKey {
        case id, name, description
        case imageURL = "image_url"
        case talkCount = "talk_count"
    }
}

/// Chapter/section within a talk
struct Chapter: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let startTime: TimeInterval
    let endTime: TimeInterval?
    
    var formattedStartTime: String {
        let minutes = Int(startTime) / 60
        let seconds = Int(startTime) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    enum CodingKeys: String, CodingKey {
        case id, title
        case startTime = "start_time"
        case endTime = "end_time"
    }
}

/// Download URL response
struct DownloadResponse: Codable {
    let downloadURL: String
    let expiresAt: Date
    let fileSize: Int64?
    
    enum CodingKeys: String, CodingKey {
        case downloadURL = "download_url"
        case expiresAt = "expires_at"
        case fileSize = "file_size"
    }
}

/// Search filters
struct TalkSearchFilters: Codable {
    var query: String = ""
    var speaker: String? = nil
    var speakerIds: [String] = []
    var series: String? = nil
    var conference: String? = nil
    var conferenceIds: [String] = []
    var conferenceType: String? = nil
    var conferenceTypes: [String] = []
    var bibleBook: String? = nil
    var bibleBookIds: [String] = []
    var year: String? = nil
    var years: [String] = []
    var collection: String? = nil
    var collections: [String] = []
    var dateFrom: Date? = nil
    var dateTo: Date? = nil
    var hasTranscript: Bool? = nil
    var isDownloaded: Bool? = nil
    
    var isEmpty: Bool {
        return query.isEmpty && 
               speaker == nil && 
               speakerIds.isEmpty &&
               series == nil && 
               conference == nil &&
               conferenceIds.isEmpty &&
               conferenceType == nil &&
               conferenceTypes.isEmpty &&
               bibleBook == nil &&
               bibleBookIds.isEmpty &&
               year == nil &&
               years.isEmpty &&
               collection == nil &&
               collections.isEmpty &&
               dateFrom == nil && 
               dateTo == nil && 
               hasTranscript == nil && 
               isDownloaded == nil
    }
    
    // Helper methods for managing filter arrays
    mutating func addSpeaker(_ speakerId: String) {
        if !speakerIds.contains(speakerId) {
            speakerIds.append(speakerId)
        }
    }
    
    mutating func removeSpeaker(_ speakerId: String) {
        speakerIds.removeAll { $0 == speakerId }
    }
    
    mutating func addConference(_ conferenceId: String) {
        if !conferenceIds.contains(conferenceId) {
            conferenceIds.append(conferenceId)
        }
    }
    
    mutating func removeConference(_ conferenceId: String) {
        conferenceIds.removeAll { $0 == conferenceId }
    }
    
    mutating func addBibleBook(_ bookId: String) {
        if !bibleBookIds.contains(bookId) {
            bibleBookIds.append(bookId)
        }
    }
    
    mutating func removeBibleBook(_ bookId: String) {
        bibleBookIds.removeAll { $0 == bookId }
    }
    
    mutating func addYear(_ year: String) {
        if !years.contains(year) {
            years.append(year)
        }
    }
    
    mutating func removeYear(_ year: String) {
        years.removeAll { $0 == year }
    }
    
    mutating func addCollection(_ collection: String) {
        if !collections.contains(collection) {
            collections.append(collection)
        }
    }
    
    mutating func removeCollection(_ collection: String) {
        collections.removeAll { $0 == collection }
    }
    
    mutating func addConferenceType(_ type: String) {
        if !conferenceTypes.contains(type) {
            conferenceTypes.append(type)
        }
    }
    
    mutating func removeConferenceType(_ type: String) {
        conferenceTypes.removeAll { $0 == type }
    }
    
    // MARK: - Factory Methods
    
    /// Create filters for a specific conference
    static func forConference(_ conferenceId: String) -> TalkSearchFilters {
        var filters = TalkSearchFilters()
        filters.addConference(conferenceId)
        return filters
    }
}

/// Sort options for talks
enum TalkSortOption: String, CaseIterable, Codable {
    case dateNewest = "date_desc"
    case dateOldest = "date_asc"
    case titleAZ = "title_asc"
    case titleZA = "title_desc"
    
    var displayName: String {
        switch self {
        case .dateNewest: return "Newest First"
        case .dateOldest: return "Oldest First"
        case .titleAZ: return "Title A-Z"
        case .titleZA: return "Title Z-A"
        }
    }
    
    var description: String? {
        switch self {
        case .dateNewest: return "Most recent talks first"
        case .dateOldest: return "Oldest talks first"
        case .titleAZ: return "Alphabetical by title"
        case .titleZA: return "Reverse alphabetical by title"
        }
    }
    
    var iconName: String {
        switch self {
        case .dateNewest, .dateOldest: return "calendar"
        case .titleAZ, .titleZA: return "textformat"
        }
    }
}

// MARK: - Mock Data for Development

extension Talk {
    static let mockTalks: [Talk] = [
        Talk(
            id: "mock-1",
            title: "The Gospel of John: Light in the Darkness",
            description: "An exploration of John's prologue and the coming of the light into the world.",
            speaker: "John Smith",
            series: "Gospel of John",
            biblePassage: "John 1:1-18",
            dateRecorded: Date().addingTimeInterval(-86400 * 30), // 30 days ago
            duration: 2340, // 39 minutes
            audioURL: "https://example.com/audio/mock-1.mp3",
            videoURL: "https://example.com/video/mock-1.mp4",
            imageURL: "https://example.com/images/john-series.jpg",
            conferenceImageURL: "https://example.com/images/conference-john.jpg",
            defaultImageURL: "/images/brand/logos/pt-resources.svg",
            fileSize: 45_000_000, // 45 MB
            category: nil,
            scriptureReference: "John 1:1-18",
            conferenceId: "mock-conference-1",
            speakerIds: ["speaker-1"],
            bookIds: ["book-john"]
        ),
        Talk(
            id: "mock-2",
            title: "Grace and Truth",
            description: "Understanding the balance of grace and truth as revealed in Christ.",
            speaker: "Jane Doe",
            series: "Gospel of John",
            biblePassage: "John 1:14-17",
            dateRecorded: Date().addingTimeInterval(-86400 * 23), // 23 days ago
            duration: 1980, // 33 minutes
            audioURL: "https://example.com/audio/mock-2.mp3",
            videoURL: "https://example.com/video/mock-2.mp4",
            imageURL: "https://example.com/images/john-series.jpg",
            conferenceImageURL: "https://example.com/images/conference-john.jpg",
            defaultImageURL: "/images/brand/logos/pt-resources.svg",
            fileSize: 38_000_000, // 38 MB
            category: nil,
            scriptureReference: "John 1:14-17",
            conferenceId: "mock-conference-1",
            speakerIds: ["speaker-2"],
            bookIds: ["book-john"]
        ),
        Talk(
            id: "mock-3",
            title: "The Witness of John the Baptist",
            description: "John the Baptist's role as a witness to Christ and its implications for us.",
            speaker: "John Smith",
            series: "Gospel of John",
            biblePassage: "John 1:19-34",
            dateRecorded: Date().addingTimeInterval(-86400 * 16), // 16 days ago
            duration: 2520, // 42 minutes
            audioURL: "https://example.com/audio/mock-3.mp3",
            imageURL: "https://example.com/images/john-series.jpg",
            conferenceImageURL: "https://example.com/images/conference-john.jpg",
            defaultImageURL: "/images/brand/logos/pt-resources.svg",
            fileSize: 48_000_000, // 48 MB
            category: nil,
            scriptureReference: "John 1:19-34",
            conferenceId: "mock-conference-1",
            speakerIds: ["speaker-1"],
            bookIds: ["book-john"]
        )
    ]
    
    static let mockChapters: [Chapter] = [
        Chapter(id: "ch-1", title: "Introduction", startTime: 0, endTime: 300),
        Chapter(id: "ch-2", title: "The Word Made Flesh", startTime: 300, endTime: 900),
        Chapter(id: "ch-3", title: "Light and Darkness", startTime: 900, endTime: 1500),
        Chapter(id: "ch-4", title: "Application", startTime: 1500, endTime: nil)
    ]
}