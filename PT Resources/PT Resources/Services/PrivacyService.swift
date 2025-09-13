//
//  PrivacyService.swift
//  PT Resources
//
//  Handles GDPR compliance features including data export and deletion
//

import Foundation
import CoreData
import Combine

/// Service for handling GDPR compliance features
@MainActor
final class PrivacyService: ObservableObject {
    static let shared = PrivacyService()

    private let persistenceController: PersistenceController
    private let fileManager = FileManager.default

    private init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
    }

    // MARK: - Data Export

    /// Export all user data as JSON
    func exportUserData() async throws -> URL {
        PTLogger.general.info("Starting user data export")

        let exportData = try await collectUserData()
        let jsonData = try JSONEncoder().encode(exportData)
        let exportURL = try await saveExportFile(jsonData, filename: "pt-resources-export-\(Date().ISO8601Format()).json")

        PTLogger.general.info("User data export completed - path: \(exportURL.path)")
        return exportURL
    }

    /// Export only downloaded talks and their metadata
    func exportDownloadedTalks() async throws -> URL {
        PTLogger.general.info("Starting downloaded talks export")

        let exportData = try await collectDownloadedTalksData()
        let jsonData = try JSONEncoder().encode(exportData)
        let exportURL = try await saveExportFile(jsonData, filename: "pt-resources-talks-export-\(Date().ISO8601Format()).json")

        PTLogger.general.info("Downloaded talks export completed - path: \(exportURL.path)")
        return exportURL
    }

    /// Export listening history and statistics
    func exportListeningHistory() async throws -> URL {
        PTLogger.general.info("Starting listening history export")

        let exportData = try await collectListeningHistory()
        let jsonData = try JSONEncoder().encode(exportData)
        let exportURL = try await saveExportFile(jsonData, filename: "pt-resources-history-export-\(Date().ISO8601Format()).json")

        PTLogger.general.info("Listening history export completed - path: \(exportURL.path)")
        return exportURL
    }

    // MARK: - Data Deletion

    /// Delete all user data (complete account deletion)
    func deleteAllUserData() async throws {
        PTLogger.general.warning("Starting complete user data deletion")

        // Delete Core Data entities first
        try await withCheckedThrowingContinuation { continuation in
            persistenceController.container.performBackgroundTask { context in
                do {
                    // Delete all entities
                    try self.deleteAllEntities(ofType: TalkEntity.self, in: context)
                    try self.deleteAllEntities(ofType: DownloadTaskEntity.self, in: context)
                    try self.deleteAllEntities(ofType: PlaybackStateEntity.self, in: context)
                    try self.deleteAllEntities(ofType: BookmarkEntity.self, in: context)
                    try self.deleteAllEntities(ofType: TranscriptEntity.self, in: context)
                    try self.deleteAllEntities(ofType: SeriesEntity.self, in: context)
                    try self.deleteAllEntities(ofType: SpeakerEntity.self, in: context)

                    // Save changes
                    try context.save()

                    PTLogger.general.info("Core Data deletion completed")
                    continuation.resume()

                } catch {
                    PTLogger.general.error("Failed to delete user data: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                }
            }
        }
        
        // Clear caches and user defaults
        await ImageCacheService.shared.clearCache()
        self.clearUserDefaults()
        
        PTLogger.general.info("Complete user data deletion completed")
    }

    /// Delete only downloaded content but keep metadata
    func deleteDownloadedContent() async throws {
        PTLogger.general.info("Starting downloaded content deletion")

        // Get all downloaded talks
        let downloadedTalks = try await persistenceController.performBackgroundTask { context in
            let request: NSFetchRequest<TalkEntity> = TalkEntity.fetchRequest()
            request.predicate = NSPredicate(format: "isDownloaded == true")
            return try context.fetch(request)
        }

        // Delete local files
        for talk in downloadedTalks {
            if let localURL = talk.localAudioURL {
                try? fileManager.removeItem(atPath: localURL)
            }
            talk.localAudioURL = nil
            talk.isDownloaded = false
        }

        // Clear download tasks
        _ = try await persistenceController.performBackgroundTask { context in
            try self.deleteAllEntities(ofType: DownloadTaskEntity.self, in: context)
        }

        // Save changes
        persistenceController.save()

        PTLogger.general.info("Downloaded content deletion completed - deleted_talks: \(downloadedTalks.count)")
    }

    /// Delete listening history and statistics
    func deleteListeningHistory() async throws {
        PTLogger.general.info("Starting listening history deletion")

        try await persistenceController.performBackgroundTask { context in
            // Clear playback states
            try self.deleteAllEntities(ofType: PlaybackStateEntity.self, in: context)

            // Clear bookmarks
            try self.deleteAllEntities(ofType: BookmarkEntity.self, in: context)

            // Reset last accessed dates
            let request: NSFetchRequest<TalkEntity> = TalkEntity.fetchRequest()
            let talks = try context.fetch(request)
            talks.forEach { talk in
                talk.lastAccessedAt = nil
            }

            try context.save()
        }

        PTLogger.general.info("Listening history deletion completed")
    }

    // MARK: - Privacy Information

    /// Get data usage statistics
    func getDataUsageStatistics() async -> DataUsageStatistics {
        do {
            let talkCount = try await persistenceController.performBackgroundTask { context in
                let request: NSFetchRequest<TalkEntity> = TalkEntity.fetchRequest()
                return try context.count(for: request)
            }

            let downloadedCount = try await persistenceController.performBackgroundTask { context in
                let request: NSFetchRequest<TalkEntity> = TalkEntity.fetchRequest()
                request.predicate = NSPredicate(format: "isDownloaded == true")
                return try context.count(for: request)
            }

            let bookmarkCount = try await persistenceController.performBackgroundTask { context in
                let request: NSFetchRequest<BookmarkEntity> = BookmarkEntity.fetchRequest()
                return try context.count(for: request)
            }

            let totalDownloadedSize = try await persistenceController.performBackgroundTask { context in
                let request: NSFetchRequest<TalkEntity> = TalkEntity.fetchRequest()
                request.predicate = NSPredicate(format: "isDownloaded == true")
                let talks = try context.fetch(request)
                return talks.reduce(0) { $0 + Int64($1.fileSize) }
            }

            return DataUsageStatistics(
                totalTalks: talkCount,
                downloadedTalks: downloadedCount,
                bookmarks: bookmarkCount,
                totalDownloadedSize: totalDownloadedSize
            )

        } catch {
            PTLogger.general.error("Failed to get data usage statistics: \(error.localizedDescription)")
            return DataUsageStatistics(totalTalks: 0, downloadedTalks: 0, bookmarks: 0, totalDownloadedSize: 0)
        }
    }

    // MARK: - Private Methods

    private func collectUserData() async throws -> ExportData {
        let talks = try await collectTalksData()
        let bookmarks = try await collectBookmarksData()
        let playbackStates = try await collectPlaybackStatesData()
        let downloads = try await collectDownloadsData()

        return ExportData(
            exportDate: Date(),
            talks: talks,
            bookmarks: bookmarks,
            playbackStates: playbackStates,
            downloads: downloads,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
            exportType: .full
        )
    }

    private func collectTalksData() async throws -> [TalkExportData] {
        return try await persistenceController.performBackgroundTask { context in
            let request: NSFetchRequest<TalkEntity> = TalkEntity.fetchRequest()
            let entities = try context.fetch(request)

            return entities.map { entity in
                TalkExportData(
                    id: entity.id ?? "",
                    title: entity.title ?? "",
                    speaker: entity.speaker ?? "",
                    series: entity.series,
                    biblePassage: entity.biblePassage,
                    dateRecorded: entity.dateRecorded,
                    duration: Int(entity.duration),
                    isDownloaded: entity.isDownloaded,
                    isFavorite: entity.isFavorite,
                    lastAccessedAt: entity.lastAccessedAt,
                    fileSize: entity.fileSize > 0 ? entity.fileSize : nil
                )
            }
        }
    }

    private func collectDownloadedTalksData() async throws -> DownloadedTalksExportData {
        let downloadedTalks = try await persistenceController.performBackgroundTask { context in
            let request: NSFetchRequest<TalkEntity> = TalkEntity.fetchRequest()
            request.predicate = NSPredicate(format: "isDownloaded == true")
            let entities = try context.fetch(request)

            return entities.map { entity in
                DownloadedTalkExportData(
                    id: entity.id ?? "",
                    title: entity.title ?? "",
                    speaker: entity.speaker ?? "",
                    series: entity.series,
                    downloadDate: entity.createdAt ?? Date(),
                    fileSize: entity.fileSize > 0 ? entity.fileSize : nil
                )
            }
        }

        return DownloadedTalksExportData(
            exportDate: Date(),
            talks: downloadedTalks,
            totalSize: downloadedTalks.reduce(0) { $0 + ($1.fileSize ?? 0) }
        )
    }

    private func collectListeningHistory() async throws -> ListeningHistoryExportData {
        let playbackStates = try await collectPlaybackStatesData()
        let bookmarks = try await collectBookmarksData()

        return ListeningHistoryExportData(
            exportDate: Date(),
            playbackStates: playbackStates,
            bookmarks: bookmarks
        )
    }

    private func collectBookmarksData() async throws -> [BookmarkExportData] {
        return try await persistenceController.performBackgroundTask { context in
            let request: NSFetchRequest<BookmarkEntity> = BookmarkEntity.fetchRequest()
            let entities = try context.fetch(request)

            return entities.map { entity in
                BookmarkExportData(
                    id: entity.id ?? UUID(),
                    talkId: entity.talk.id,
                    position: entity.position,
                    title: entity.title,
                    createdAt: entity.createdAt ?? Date()
                )
            }
        }
    }

    private func collectPlaybackStatesData() async throws -> [PlaybackStateExportData] {
        return try await persistenceController.performBackgroundTask { context in
            let request: NSFetchRequest<PlaybackStateEntity> = PlaybackStateEntity.fetchRequest()
            let entities = try context.fetch(request)

            return entities.map { entity in
                PlaybackStateExportData(
                    talkId: entity.talkID ?? "",
                    position: entity.position,
                    isCompleted: entity.isCompleted,
                    lastPlayedAt: entity.lastPlayedAt ?? Date(),
                    playbackSpeed: entity.playbackSpeed
                )
            }
        }
    }

    private func collectDownloadsData() async throws -> [DownloadExportData] {
        return try await persistenceController.performBackgroundTask { context in
            let request: NSFetchRequest<DownloadTaskEntity> = DownloadTaskEntity.fetchRequest()
            let entities = try context.fetch(request)

            return entities.map { entity in
                DownloadExportData(
                    id: entity.id ?? "",
                    talkId: entity.talkID ?? "",
                    status: entity.status ?? "",
                    progress: entity.progress,
                    totalBytes: entity.totalBytes,
                    downloadedBytes: entity.downloadedBytes,
                    createdAt: entity.createdAt ?? Date(),
                    completedAt: entity.completedAt
                )
            }
        }
    }

    private func saveExportFile(_ data: Data, filename: String) async throws -> URL {
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let exportsDirectory = documentsDirectory.appendingPathComponent("Exports")

        // Create exports directory if it doesn't exist
        try fileManager.createDirectory(at: exportsDirectory, withIntermediateDirectories: true)

        let fileURL = exportsDirectory.appendingPathComponent(filename)
        try data.write(to: fileURL)

        return fileURL
    }

    private func deleteAllEntities<T: NSManagedObject>(ofType type: T.Type, in context: NSManagedObjectContext) throws {
        let request = T.fetchRequest()
        let entities = try context.fetch(request)
        entities.forEach { context.delete($0 as! NSManagedObject) }
    }

    private func clearUserDefaults() {
        let defaults = UserDefaults.standard
        let keysToRemove = [
            "analytics_enabled",
            // Add other user-specific keys that should be cleared
        ]
        keysToRemove.forEach { defaults.removeObject(forKey: $0) }
    }
}

// MARK: - Data Models

struct DataUsageStatistics {
    let totalTalks: Int
    let downloadedTalks: Int
    let bookmarks: Int
    let totalDownloadedSize: Int64

    var totalDownloadedSizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: totalDownloadedSize, countStyle: .file)
    }
}

struct ExportData: Codable {
    let exportDate: Date
    let talks: [TalkExportData]
    let bookmarks: [BookmarkExportData]
    let playbackStates: [PlaybackStateExportData]
    let downloads: [DownloadExportData]
    let appVersion: String
    let exportType: ExportType

    enum ExportType: String, Codable {
        case full
        case talks
        case history
    }
}

struct DownloadedTalksExportData: Codable {
    let exportDate: Date
    let talks: [DownloadedTalkExportData]
    let totalSize: Int64
}

struct ListeningHistoryExportData: Codable {
    let exportDate: Date
    let playbackStates: [PlaybackStateExportData]
    let bookmarks: [BookmarkExportData]
}

struct TalkExportData: Codable {
    let id: String
    let title: String
    let speaker: String
    let series: String?
    let biblePassage: String?
    let dateRecorded: Date?
    let duration: Int
    let isDownloaded: Bool
    let isFavorite: Bool
    let lastAccessedAt: Date?
    let fileSize: Int64?
}

struct DownloadedTalkExportData: Codable {
    let id: String
    let title: String
    let speaker: String
    let series: String?
    let downloadDate: Date
    let fileSize: Int64?
}

struct BookmarkExportData: Codable {
    let id: UUID
    let talkId: String
    let position: Double
    let title: String?
    let createdAt: Date
}

struct PlaybackStateExportData: Codable {
    let talkId: String
    let position: Double
    let isCompleted: Bool
    let lastPlayedAt: Date
    let playbackSpeed: Float
}

struct DownloadExportData: Codable {
    let id: String
    let talkId: String
    let status: String
    let progress: Float
    let totalBytes: Int64
    let downloadedBytes: Int64
    let createdAt: Date
    let completedAt: Date?
}

// MARK: - Privacy Policy and Terms

struct PrivacyDocument {
    let title: String
    let content: String
    let lastUpdated: Date
    let url: URL?

    static let privacyPolicy = PrivacyDocument(
        title: "Privacy Policy",
        content: """
        Privacy Policy for PT Resources

        Last updated: \(Date().formatted(date: .long, time: .omitted))

        1. Information We Collect

        We collect information about how you use our app, including:
        - Talks you listen to
        - Downloads you make
        - Bookmarks and playback positions
        - App usage statistics

        2. How We Use Your Information

        We use this information to:
        - Provide and improve our services
        - Personalize your experience
        - Analyze app performance

        3. Data Storage and Security

        Your data is stored securely and is never shared with third parties without your consent.

        4. Your Rights

        You have the right to:
        - Export your data
        - Delete your data
        - Opt out of analytics

        For more information, please contact us.
        """,
        lastUpdated: Date(),
        url: URL(string: Config.privacyPolicyURL)
    )

    static let termsOfService = PrivacyDocument(
        title: "Terms of Service",
        content: """
        Terms of Service for PT Resources

        Last updated: \(Date().formatted(date: .long, time: .omitted))

        By using PT Resources, you agree to these terms:

        1. Use of Service
        - The app is for personal, non-commercial use
        - Content is provided by Proclamation Trust

        2. Content
        - All talks and content remain property of Proclamation Trust
        - Downloaded content is for offline use only

        3. Privacy
        - Your privacy is protected as described in our Privacy Policy

        For the complete terms, please visit our website.
        """,
        lastUpdated: Date(),
        url: URL(string: Config.termsOfServiceURL)
    )
}

