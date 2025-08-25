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