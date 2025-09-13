//
//  LatestContent.swift
//  PT Resources
//
//  Models for latest content API response
//

import Foundation

// MARK: - Latest Content Response

struct LatestContentResponse: Codable {
    let blogPost: LatestBlogPost?
    let latestConference: ConferenceMedia?
    let archiveMedia: ConferenceMedia?
}

// MARK: - Latest Blog Post (API specific)

struct LatestBlogPost: Codable, Identifiable {
    let id: String
    let wpId: String?
    let title: String
    let excerpt: String
    let image: String?
    let category: String
    let author: String
    let date: String
    let url: String

    enum CodingKeys: String, CodingKey {
        case id, title, excerpt, image, category, author, date, url
        case wpId = "wp_id"
    }

    var imageURL: URL? {
        guard let image = image else { return nil }
        return URL(string: image)
    }

    var fullURL: URL? {
        return URL(string: "https://www.proctrust.org.uk\(url)")
    }

    /// Converts LatestBlogPost to BlogPost for compatibility with BlogDetailView
    func toBlogPost() -> BlogPost {
        return BlogPost(
            id: id,
            title: title,
            excerpt: excerpt,
            date: date,
            slug: wpId ?? id, // Use wpId as slug if available, otherwise use id
            url: fullURL?.absoluteString ?? "https://www.proctrust.org.uk\(url)",
            author: author,
            image: image,
            category: category,
            content: nil, // LatestBlogPost doesn't have full content
            publishedDate: nil // Will be parsed from date string in BlogPost.init
        )
    }
}

// MARK: - Conference Media

struct ConferenceMedia: Codable, Identifiable {
    let title: String
    let excerpt: String
    let url: String
    let legacyUrl: String?
    let image: String
    let category: String
    let conferenceId: String
    let legacyConferenceId: Int?
    
    enum CodingKeys: String, CodingKey {
        case title, excerpt, url, image, category
        case legacyUrl, conferenceId, legacyConferenceId
    }
    
    var id: String {
        return conferenceId
    }
    
    var imageURL: URL? {
        if image.hasPrefix("http") {
            return URL(string: image)
        } else {
            return URL(string: "https://www.proctrust.org.uk\(image)")
        }
    }
    
    var fullURL: URL? {
        return URL(string: "https://www.proctrust.org.uk\(url)")
    }
    
    /// Converts ConferenceMedia to ConferenceInfo for compatibility
    func toConferenceInfo() -> ConferenceInfo {
        return ConferenceInfo(
            id: conferenceId,
            title: title,
            year: extractYear(from: title),
            imageURL: image,
            resourceCount: 0, // Not available from ConferenceMedia
            description: excerpt.isEmpty ? nil : excerpt,
            conferenceType: nil // Not available from ConferenceMedia
        )
    }
    
    private func extractYear(from title: String) -> String {
        // Simple regex to extract year from title
        let yearRegex = try? NSRegularExpression(pattern: "\\b(20\\d{2})\\b")
        let nsString = title as NSString
        let results = yearRegex?.matches(in: title, range: NSRange(location: 0, length: nsString.length))
        
        if let match = results?.first {
            return nsString.substring(with: match.range)
        }
        
        return "2025" // Default year if not found
    }
}

// MARK: - Mock Data

extension LatestContentResponse {
    static let mockData = LatestContentResponse(
        blogPost: LatestBlogPost(
            id: "mock-blog-1",
            wpId: nil,
            title: "Gospel growth in Sierra Leone",
            excerpt: "Read more at the Proclaimer",
            image: "https://example.com/sierra-leone.jpg",
            category: "From the Proclaimer",
            author: "PT Staff",
            date: "30 July 2025",
            url: "/blog/mock-blog-1"
        ),
        latestConference: ConferenceMedia(
            title: "Women in Ministry 2025",
            excerpt: "The Women in Ministry Conference 2025 with Rob Mullock and Anja Schmidt",
            url: "/resources?conference_id=3a006789-a7bf-44e7-a178-d6ed9d7e5630",
            legacyUrl: "/resources?conference_id=301",
            image: "/images/brand/logos/pt-resources.svg",
            category: "Latest Conference Media",
            conferenceId: "3a006789-a7bf-44e7-a178-d6ed9d7e5630",
            legacyConferenceId: 301
        ),
        archiveMedia: ConferenceMedia(
            title: "EMA 2025",
            excerpt: "Ministry can often feel relentless. The challenges of leading in a sceptical world, the weight of responsibility, and the demands of caring for others can leave even the most dedicated of us feeling weary.\n\nEMA 2025 was about being encouraged to continue on in ministry.",
            url: "/resources?conference_id=e616c1dd-6e56-442b-b628-287cc5a9e1c5",
            legacyUrl: "/resources?conference_id=null",
            image: "https://example.com/ema-2025.jpg",
            category: "From the archive",
            conferenceId: "e616c1dd-6e56-442b-b628-287cc5a9e1c5",
            legacyConferenceId: nil
        )
    )
}