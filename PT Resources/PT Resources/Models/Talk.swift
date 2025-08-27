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
    let fileSize: Int64?
    let category: String?
    let scriptureReference: String?
    
    enum CodingKeys: String, CodingKey {
        case id, title, description, speaker, series, category
        case biblePassage = "scriptureReference"
        case dateRecorded = "date"
        case duration
        case audioURL = "audioUrl"
        case videoURL = "videoUrl"  
        case imageURL = "imageUrl"
        case fileSize
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
        fileSize: Int64? = nil,
        category: String? = nil,
        scriptureReference: String? = nil
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
        self.fileSize = fileSize
        self.category = category
        self.scriptureReference = scriptureReference
    }
    
    // Computed properties
    var formattedDuration: String {
        let minutes = duration / 60
        let seconds = duration % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: dateRecorded)
    }
    
    var shareURL: String {
        "\(Config.universalLinkDomain)/talks/\(id)"
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
    var series: String? = nil
    var dateFrom: Date? = nil
    var dateTo: Date? = nil
    var hasTranscript: Bool? = nil
    var isDownloaded: Bool? = nil
    
    var isEmpty: Bool {
        return query.isEmpty && 
               speaker == nil && 
               series == nil && 
               dateFrom == nil && 
               dateTo == nil && 
               hasTranscript == nil && 
               isDownloaded == nil
    }
}

/// Sort options for talks
enum TalkSortOption: String, CaseIterable, Codable {
    case dateNewest = "date_desc"
    case dateOldest = "date_asc"
    case titleAZ = "title_asc"
    case titleZA = "title_desc"
    case speaker = "speaker_asc"
    case series = "series_asc"
    case duration = "duration_desc"
    
    var displayName: String {
        switch self {
        case .dateNewest: return "Newest First"
        case .dateOldest: return "Oldest First"
        case .titleAZ: return "Title A-Z"
        case .titleZA: return "Title Z-A"
        case .speaker: return "Speaker"
        case .series: return "Series"
        case .duration: return "Duration"
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
            imageURL: "https://example.com/images/john-series.jpg",
            fileSize: 45_000_000 // 45 MB
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
            imageURL: "https://example.com/images/john-series.jpg",
            fileSize: 38_000_000 // 38 MB
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
            fileSize: 48_000_000 // 48 MB
        )
    ]
    
    static let mockChapters: [Chapter] = [
        Chapter(id: "ch-1", title: "Introduction", startTime: 0, endTime: 300),
        Chapter(id: "ch-2", title: "The Word Made Flesh", startTime: 300, endTime: 900),
        Chapter(id: "ch-3", title: "Light and Darkness", startTime: 900, endTime: 1500),
        Chapter(id: "ch-4", title: "Application", startTime: 1500, endTime: nil)
    ]
}