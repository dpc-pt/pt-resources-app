//
//  ESVPassage.swift
//  PT Resources
//
//  Models for ESV Bible passage integration
//

import Foundation

/// ESV Bible passage data
struct ESVPassage: Codable, Identifiable {
    let id: String
    let reference: String
    let passages: [String]
    let copyright: String?
    
    var text: String {
        return passages.joined(separator: "\n\n")
    }
    
    var formattedText: String {
        // Remove extra whitespace and format for display
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "  ", with: " ")
    }
    
    init(reference: String, passages: [String], copyright: String? = nil) {
        self.id = reference
        self.reference = reference
        self.passages = passages
        self.copyright = copyright
    }
}

/// ESV API response model for text endpoint
struct ESVResponse: Codable {
    let query: String
    let canonical: String
    let parsed: [[String]]
    let passages: [String]
    let copyright: String?
    
    func toESVPassage() -> ESVPassage {
        return ESVPassage(
            reference: canonical,
            passages: passages,
            copyright: copyright
        )
    }
}

/// ESV API response model for HTML endpoint
struct ESVHTMLResponse: Codable {
    let query: String
    let canonical: String
    let parsed: [[Int]]  // API returns numbers, not strings
    let passages: [String]
    let copyright: String?
    
    func toESVPassage() -> ESVPassage {
        return ESVPassage(
            reference: canonical,
            passages: passages,
            copyright: copyright
        )
    }
}

/// Cached passage with expiration
final class CachedESVPassage {
    let passage: ESVPassage
    let cachedAt: Date
    let expiresAt: Date
    
    var isExpired: Bool {
        return Date() > expiresAt
    }
    
    init(passage: ESVPassage, cacheExpiration: TimeInterval = Config.esvCacheExpiration) {
        self.passage = passage
        self.cachedAt = Date()
        self.expiresAt = Date().addingTimeInterval(cacheExpiration)
    }
}

/// ESV passage request parameters
struct ESVPassageRequest {
    let reference: String
    let includeHeadings: Bool
    let includeFootnotes: Bool
    let includeVerseNumbers: Bool
    let includeShortCopyright: Bool
    let includeCopyright: Bool
    
    init(
        reference: String,
        includeHeadings: Bool = false,
        includeFootnotes: Bool = false,
        includeVerseNumbers: Bool = true,
        includeShortCopyright: Bool = true,
        includeCopyright: Bool = false
    ) {
        self.reference = reference
        self.includeHeadings = includeHeadings
        self.includeFootnotes = includeFootnotes
        self.includeVerseNumbers = includeVerseNumbers
        self.includeShortCopyright = includeShortCopyright
        self.includeCopyright = includeCopyright
    }
    
    var queryItems: [URLQueryItem] {
        return [
            URLQueryItem(name: "q", value: reference),
            URLQueryItem(name: "include-headings", value: includeHeadings ? "true" : "false"),
            URLQueryItem(name: "include-footnotes", value: includeFootnotes ? "true" : "false"),
            URLQueryItem(name: "include-verse-numbers", value: includeVerseNumbers ? "true" : "false"),
            URLQueryItem(name: "include-short-copyright", value: includeShortCopyright ? "true" : "false"),
            URLQueryItem(name: "include-copyright", value: includeCopyright ? "true" : "false")
        ]
    }
}

// MARK: - Bible Reference Parsing

extension String {
    /// Parse a Bible reference and return a normalized form
    var normalizedBibleReference: String {
        // Basic normalization - more sophisticated parsing could be added
        return self.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "  ", with: " ")
            .replacingOccurrences(of: " - ", with: "-")
            .replacingOccurrences(of: " – ", with: "-")
    }
    
    /// Check if string looks like a Bible reference
    var isBibleReference: Bool {
        // Simple check for patterns like "John 3:16" or "1 Corinthians 13:1-13"
        let pattern = #"^\d?\s?[A-Za-z]+\s+\d+:\d+(-\d+)?(,\s?\d+:\d+(-\d+)?)*$"#
        return self.range(of: pattern, options: .regularExpression) != nil
    }
}

// MARK: - Mock Data

extension ESVPassage {
    static let mockPassages: [ESVPassage] = [
        ESVPassage(
            reference: "John 1:1-18",
            passages: [
                "In the beginning was the Word, and the Word was with God, and the Word was God. He was in the beginning with God. All things were made through him, and without him was not any thing made that was made. In him was life, and the life was the light of men. The light shines in the darkness, and the darkness has not overcome it.\n\nThere was a man sent from God, whose name was John. He came as a witness, to bear witness about the light, that all might believe through him. He was not the light, but came to bear witness about the light.\n\nThe true light, which gives light to everyone, was coming into the world. He was in the world, and the world was made through him, yet the world did not know him. He came to his own, and his own people did not receive him. But to all who did receive him, who believed in his name, he gave the right to become children of God, who were born, not of blood nor of the will of the flesh nor of the will of man, but of God.\n\nAnd the Word became flesh and dwelt among us, and we have seen his glory, glory as of the only Son from the Father, full of grace and truth. (John bore witness about him, and cried out, \"This was he of whom I said, 'He who comes after me ranks before me, because he was before me.'\") For from his fullness we have all received, grace upon grace. For the law was given through Moses; grace and truth came through Jesus Christ. No one has ever seen God; the only God, who is at the Father's side, he has made him known."
            ],
            copyright: "ESV"
        ),
        ESVPassage(
            reference: "John 3:16",
            passages: [
                "For God so loved the world, that he gave his only Son, that whoever believes in him should not perish but have eternal life."
            ],
            copyright: "ESV"
        ),
        ESVPassage(
            reference: "Romans 8:28",
            passages: [
                "And we know that for those who love God all things work together for good, for those who are called according to his purpose."
            ],
            copyright: "ESV"
        )
    ]
}