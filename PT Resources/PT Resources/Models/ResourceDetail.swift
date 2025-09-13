//
//  ResourceDetail.swift
//  PT Resources
//
//  Individual resource detail model for PT API
//

import Foundation

// MARK: - Resource Detail Response

struct ResourceDetailResponse: Codable {
    let resource: ResourceDetail
}

// MARK: - Resource Detail

struct ResourceDetail: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let description: String
    let content: String
    let date: String
    let conference: String
    let conferenceId: String
    let conferenceTypeId: String
    let speaker: String
    let speakerIds: [String]
    let books: [Book]
    let bookIds: [String]
    let videoUrl: String
    let audioUrl: String
    let imageUrl: String
    let category: String
    let scriptureReference: String
    let relatedResources: [RelatedResource]
    
    var videoURL: URL? {
        if videoUrl.isEmpty { return nil }
        // Handle Vimeo URLs - if it's just a number, construct full URL
        if videoUrl.allSatisfy({ $0.isNumber }) {
            return URL(string: "https://player.vimeo.com/video/\(videoUrl)")
        }
        return URL(string: videoUrl)
    }
    
    var audioURL: URL? {
        guard !audioUrl.isEmpty else { return nil }
        if audioUrl.hasPrefix("http") {
            return URL(string: audioUrl)
        } else {
            return URL(string: "https://www.proctrust.org.uk\(audioUrl)")
        }
    }
    
    var resourceImageURL: URL? {
        if imageUrl.hasPrefix("http") {
            return URL(string: imageUrl)
        } else {
            return URL(string: "https://www.proctrust.org.uk\(imageUrl)")
        }
    }
    
    var formattedDate: Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM yyyy"
        return formatter.date(from: date)
    }
}

// MARK: - Book

struct Book: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let shortName: String?
    let testament: String?
}

// MARK: - Related Resource

struct RelatedResource: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let description: String
    let date: String
    let conference: String
    let speaker: String
    let imageUrl: String
    
    var resourceImageURL: URL? {
        if imageUrl.hasPrefix("http") {
            return URL(string: imageUrl)
        } else {
            return URL(string: "https://www.proctrust.org.uk\(imageUrl)")
        }
    }
}

// MARK: - Mock Data

extension ResourceDetailResponse {
    static let mockData = ResourceDetailResponse(
        resource: ResourceDetail(
            id: "506ce344-825f-4124-8667-97f7e84ee5aa",
            title: "Closing exposition",
            description: "A powerful closing message that brings together the key themes of the conference",
            content: "<p>This exposition draws together the threads of our conference theme...</p>",
            date: "1 January 2016",
            conference: "Autumn Ministers 2016",
            conferenceId: "ca811227-447d-40ec-a87e-b8f96a79426e",
            conferenceTypeId: "",
            speaker: "Vaughan Roberts",
            speakerIds: ["3c68e458-2441-46e8-87c8-53ba51821ef8"],
            books: [],
            bookIds: [],
            videoUrl: "194364791",
            audioUrl: "/media/audio/sample.mp3",
            imageUrl: "https://www.proctrust.org.uk/images/brand/logos/pt-resources.svg",
            category: "Autumn Ministers 2016",
            scriptureReference: "2 Timothy 4:1-8",
            relatedResources: [
                RelatedResource(
                    id: "0049b421-a4ae-4c7d-b401-b2bb32690df3",
                    title: "Preaching and the glory of God: the ministry of Martyn Lloyd-Jones",
                    description: "",
                    date: "1 January 2014",
                    conference: "Evangelical Ministry Assembly 2014",
                    speaker: "Vaughan Roberts",
                    imageUrl: "https://www.proctrust.org.uk/images/brand/logos/pt-resources.svg"
                )
            ]
        )
    )
}