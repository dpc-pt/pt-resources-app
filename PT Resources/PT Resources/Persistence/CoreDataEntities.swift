//
//  CoreDataEntities.swift
//  PT Resources
//
//  Core Data entity extensions and managed object subclasses
//

import Foundation
import CoreData

// MARK: - TalkEntity

@objc(TalkEntity)
public class TalkEntity: NSManagedObject {
    
}

extension TalkEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<TalkEntity> {
        return NSFetchRequest<TalkEntity>(entityName: "TalkEntity")
    }

    @NSManaged public var id: String?
    @NSManaged public var title: String?
    @NSManaged public var desc: String?
    @NSManaged public var speaker: String?
    @NSManaged public var series: String?
    @NSManaged public var biblePassage: String?
    @NSManaged public var dateRecorded: Date?
    @NSManaged public var duration: Int32
    @NSManaged public var audioURL: String?
    @NSManaged public var videoURL: String?
    @NSManaged public var localAudioURL: String?
    @NSManaged public var localVideoURL: String?
    @NSManaged public var imageURL: String?
    @NSManaged public var isDownloaded: Bool
    @NSManaged public var isFavorite: Bool
    @NSManaged public var fileSize: Int64
    @NSManaged public var lastAccessedAt: Date?
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var bookmarks: NSSet?
    @NSManaged public var chapters: NSSet?
    @NSManaged public var downloadTask: DownloadTaskEntity?
    @NSManaged public var passage: ESVPassageEntity?
    @NSManaged public var playbackState: PlaybackStateEntity?
    @NSManaged public var seriesEntity: SeriesEntity?
    @NSManaged public var speakerEntity: SpeakerEntity?
    @NSManaged public var transcript: TranscriptEntity?

}

// MARK: Generated accessors for bookmarks
extension TalkEntity {

    @objc(addBookmarksObject:)
    @NSManaged public func addToBookmarks(_ value: BookmarkEntity)

    @objc(removeBookmarksObject:)
    @NSManaged public func removeFromBookmarks(_ value: BookmarkEntity)

    @objc(addBookmarks:)
    @NSManaged public func addToBookmarks(_ values: NSSet)

    @objc(removeBookmarks:)
    @NSManaged public func removeFromBookmarks(_ values: NSSet)

}

// MARK: Generated accessors for chapters
extension TalkEntity {

    @objc(addChaptersObject:)
    @NSManaged public func addToChapters(_ value: ChapterEntity)

    @objc(removeChaptersObject:)
    @NSManaged public func removeFromChapters(_ value: ChapterEntity)

    @objc(addChapters:)
    @NSManaged public func addToChapters(_ values: NSSet)

    @objc(removeChapters:)
    @NSManaged public func removeFromChapters(_ values: NSSet)

}

// MARK: - BookmarkEntity

@objc(BookmarkEntity)
public class BookmarkEntity: NSManagedObject {

}

extension BookmarkEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<BookmarkEntity> {
        return NSFetchRequest<BookmarkEntity>(entityName: "BookmarkEntity")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var position: Double
    @NSManaged public var title: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var talk: TalkEntity?

}

// MARK: - ChapterEntity

@objc(ChapterEntity)
public class ChapterEntity: NSManagedObject {

}

extension ChapterEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ChapterEntity> {
        return NSFetchRequest<ChapterEntity>(entityName: "ChapterEntity")
    }

    @NSManaged public var id: String?
    @NSManaged public var title: String?
    @NSManaged public var startTime: Double
    @NSManaged public var endTime: Double
    @NSManaged public var talk: TalkEntity?

}

// MARK: - DownloadTaskEntity

@objc(DownloadTaskEntity)
public class DownloadTaskEntity: NSManagedObject {

}

extension DownloadTaskEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<DownloadTaskEntity> {
        return NSFetchRequest<DownloadTaskEntity>(entityName: "DownloadTaskEntity")
    }

    @NSManaged public var id: String?
    @NSManaged public var talkID: String?
    @NSManaged public var downloadURL: String?
    @NSManaged public var localURL: String?
    @NSManaged public var status: String?
    @NSManaged public var progress: Float
    @NSManaged public var totalBytes: Int64
    @NSManaged public var downloadedBytes: Int64
    @NSManaged public var createdAt: Date?
    @NSManaged public var startedAt: Date?
    @NSManaged public var completedAt: Date?
    @NSManaged public var resumeData: Data?
    @NSManaged public var talk: TalkEntity?

}

// MARK: - ESVPassageEntity

@objc(ESVPassageEntity)
public class ESVPassageEntity: NSManagedObject {

}

extension ESVPassageEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ESVPassageEntity> {
        return NSFetchRequest<ESVPassageEntity>(entityName: "ESVPassageEntity")
    }

    @NSManaged public var reference: String?
    @NSManaged public var text: String?
    @NSManaged public var cachedAt: Date?
    @NSManaged public var talks: NSSet?

}

// MARK: Generated accessors for talks
extension ESVPassageEntity {

    @objc(addTalksObject:)
    @NSManaged public func addToTalks(_ value: TalkEntity)

    @objc(removeTalksObject:)
    @NSManaged public func removeFromTalks(_ value: TalkEntity)

    @objc(addTalks:)
    @NSManaged public func addToTalks(_ values: NSSet)

    @objc(removeTalks:)
    @NSManaged public func removeFromTalks(_ values: NSSet)

}

// MARK: - PlaybackStateEntity

@objc(PlaybackStateEntity)
public class PlaybackStateEntity: NSManagedObject {

}

extension PlaybackStateEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<PlaybackStateEntity> {
        return NSFetchRequest<PlaybackStateEntity>(entityName: "PlaybackStateEntity")
    }

    @NSManaged public var talkID: String?
    @NSManaged public var position: Double
    @NSManaged public var isCompleted: Bool
    @NSManaged public var lastPlayedAt: Date?
    @NSManaged public var playbackSpeed: Float
    @NSManaged public var talk: TalkEntity?

}

// MARK: - SeriesEntity

@objc(SeriesEntity)
public class SeriesEntity: NSManagedObject {

}

extension SeriesEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<SeriesEntity> {
        return NSFetchRequest<SeriesEntity>(entityName: "SeriesEntity")
    }

    @NSManaged public var id: String?
    @NSManaged public var name: String?
    @NSManaged public var desc: String?
    @NSManaged public var imageURL: String?
    @NSManaged public var talks: NSSet?

}

// MARK: Generated accessors for talks
extension SeriesEntity {

    @objc(addTalksObject:)
    @NSManaged public func addToTalks(_ value: TalkEntity)

    @objc(removeTalksObject:)
    @NSManaged public func removeFromTalks(_ value: TalkEntity)

    @objc(addTalks:)
    @NSManaged public func addToTalks(_ values: NSSet)

    @objc(removeTalks:)
    @NSManaged public func removeFromTalks(_ values: NSSet)

}

// MARK: - SpeakerEntity

@objc(SpeakerEntity)
public class SpeakerEntity: NSManagedObject {

}

extension SpeakerEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<SpeakerEntity> {
        return NSFetchRequest<SpeakerEntity>(entityName: "SpeakerEntity")
    }

    @NSManaged public var id: String?
    @NSManaged public var name: String?
    @NSManaged public var bio: String?
    @NSManaged public var imageURL: String?
    @NSManaged public var talks: NSSet?

}

// MARK: Generated accessors for talks
extension SpeakerEntity {

    @objc(addTalksObject:)
    @NSManaged public func addToTalks(_ value: TalkEntity)

    @objc(removeTalksObject:)
    @NSManaged public func removeFromTalks(_ value: TalkEntity)

    @objc(addTalks:)
    @NSManaged public func addToTalks(_ values: NSSet)

    @objc(removeTalks:)
    @NSManaged public func removeFromTalks(_ values: NSSet)

}

// MARK: - TranscriptEntity

@objc(TranscriptEntity)
public class TranscriptEntity: NSManagedObject {

}

extension TranscriptEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<TranscriptEntity> {
        return NSFetchRequest<TranscriptEntity>(entityName: "TranscriptEntity")
    }

    @NSManaged public var id: String?
    @NSManaged public var talkID: String?
    @NSManaged public var text: String?
    @NSManaged public var segments: Data?
    @NSManaged public var language: String?
    @NSManaged public var status: String?
    @NSManaged public var jobID: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var completedAt: Date?
    @NSManaged public var talk: TalkEntity?

}