//
//  BlogPost.swift
//  PT Resources
//
//  Blog post model representing articles from Proclamation Trust
//

import Foundation

/// Main blog post model representing an article from Proclamation Trust
struct BlogPost: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let excerpt: String?
    let date: String
    let slug: String
    let url: String
    let author: String
    let image: String?
    let category: String?
    let content: String?
    let publishedDate: Date?

    enum CodingKeys: String, CodingKey {
        case id = "ID"
        case title, excerpt, date, slug, url, author, image, category, content
        case publishedDate = "published_date"
    }

    // Custom decoder to handle date parsing
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        excerpt = try container.decodeIfPresent(String.self, forKey: .excerpt)
        date = try container.decode(String.self, forKey: .date)
        slug = try container.decode(String.self, forKey: .slug)
        url = try container.decode(String.self, forKey: .url)
        author = try container.decode(String.self, forKey: .author)
        image = try container.decodeIfPresent(String.self, forKey: .image)
        category = try container.decodeIfPresent(String.self, forKey: .category)
        content = try container.decodeIfPresent(String.self, forKey: .content)

        // Parse published_date if available, otherwise parse date field
        if let publishedDateString = try container.decodeIfPresent(String.self, forKey: .publishedDate) {
            publishedDate = DateFormatter.blogDateFormatter.date(from: publishedDateString)
        } else {
            publishedDate = DateFormatter.blogDateFormatter.date(from: date)
        }
    }

    // Standard init for mock data and internal use
    init(
        id: String,
        title: String,
        excerpt: String? = nil,
        date: String,
        slug: String,
        url: String,
        author: String,
        image: String? = nil,
        category: String? = nil,
        content: String? = nil,
        publishedDate: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.excerpt = excerpt
        self.date = date
        self.slug = slug
        self.url = url
        self.author = author
        self.image = image
        self.category = category
        self.content = content
        self.publishedDate = publishedDate
    }

    // Computed properties
    var formattedDate: String {
        guard let date = publishedDate else {
            return date
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    var shareURL: String {
        url
    }

    var displayExcerpt: String {
        excerpt?.isEmpty == false ? excerpt! : "Tap to read more..."
    }

    var categoryDisplayName: String {
        category ?? "Uncategorized"
    }
}

/// Response model for paginated blog posts
struct BlogPostsResponse: Codable {
    let posts: [BlogPost]
    let total: Int
    let limit: Int
    let offset: Int
    let hasMore: Bool

    enum CodingKeys: String, CodingKey {
        case posts
        case total
        case limit
        case offset
        case hasMore
    }
}

// MARK: - Date Formatter Extension

extension DateFormatter {
    static let blogDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMMM yyyy"
        return formatter
    }()
}

// MARK: - Mock Data for Development

extension BlogPost {
    static let mockBlogPosts: [BlogPost] = [
        BlogPost(
            id: "mock-blog-1",
            title: "Gospel growth in Sierra Leone",
            excerpt: "This month, we're encouraged by the work of Reformed Gospel Mission (ReGoM) in Sierra Leone...",
            date: "30 July 2025",
            slug: "gospel-growth-in-Sierra-Leone",
            url: "https://www.proctrust.org.uk/blog/gospel-growth-in-Sierra-Leone",
            author: "PT Staff",
            image: "https://svcsysqnxnplbxqolrtv.supabase.co/storage/v1/object/public/media/uploads/01e03e1d-af2b-43c3-8e5e-047251d54a55.jpeg",
            category: "From the Proclaimer",
            content: "Full blog post content would go here...",
            publishedDate: Calendar.current.date(from: DateComponents(year: 2025, month: 7, day: 30))
        ),
        BlogPost(
            id: "mock-blog-2",
            title: "Important changes to the Proclamation Trust courses",
            excerpt: "It is our privilege to serve in the important task of training gospel workers...",
            date: "21 June 2025",
            slug: "important-changes-to-the-proclamation-trust-courses",
            url: "https://www.proctrust.org.uk/blog/important-changes-to-the-proclamation-trust-courses",
            author: "Robin Sydserff",
            image: "https://svcsysqnxnplbxqolrtv.supabase.co/storage/v1/object/public/media/migrated/DSC_2773-9178079d.jpg",
            category: "Uncategorized",
            content: "Full blog post content would go here...",
            publishedDate: Calendar.current.date(from: DateComponents(year: 2025, month: 6, day: 21))
        ),
        BlogPost(
            id: "mock-blog-3",
            title: "Serving the Church, multiplying expository Word ministry",
            excerpt: "I'm very thankful for the opportunity to serve as the new Director of The Proclamation Trust...",
            date: "14 October 2024",
            slug: "serving-the-church-multiplying-expository-word-ministry",
            url: "https://www.proctrust.org.uk/blog/serving-the-church-multiplying-expository-word-ministry",
            author: "Robin Sydserff",
            image: "https://svcsysqnxnplbxqolrtv.supabase.co/storage/v1/object/public/media/migrated/DSC_3002-cf0f90bc.jpg",
            category: "Uncategorized",
            content: "Full blog post content would go here...",
            publishedDate: Calendar.current.date(from: DateComponents(year: 2024, month: 10, day: 14))
        )
    ]
}
