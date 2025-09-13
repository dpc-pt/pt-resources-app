//
//  DownloadService.swift
//  PT Resources
//
//  Service for downloading and managing offline talk files
//

import Foundation
import CoreData
import AVFoundation

extension Notification.Name {
    static let downloadCompleted = Notification.Name("downloadCompleted")
    static let downloadDeleted = Notification.Name("downloadDeleted")
    static let downloadFailed = Notification.Name("downloadFailed")
}
import Combine

@MainActor
final class DownloadService: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var activeDownloads: [DownloadTask] = []
    @Published var downloadProgress: [String: Float] = [:]
    @Published var cachedDownloadedTalks: [DownloadedTalk] = []
    @Published var isCacheValid = false
    
    // MARK: - Private Properties
    
    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: "com.proctrust.downloads")
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()
    
    private let apiService: TalksAPIServiceProtocol
    private let persistenceController: PersistenceController
    // FileManager is not Sendable, so we'll use FileManager.default directly in methods
    
    private var backgroundCompletionHandler: (() -> Void)?
    private var lastCacheUpdate: Date?
    private let cacheValidityDuration: TimeInterval = 300 // 5 minutes
    
    // MARK: - Initialization
    
    init(apiService: TalksAPIServiceProtocol, persistenceController: PersistenceController = .shared) {
        self.apiService = apiService
        self.persistenceController = persistenceController
        super.init()
        
        // Load existing download tasks
        loadDownloadTasks()
        
        // Preload cached downloaded talks for immediate UI display
        Task {
            await preloadDownloadedTalks()
        }
    }
    
    // MARK: - Public Methods
    
    func downloadTalk(_ talk: Talk) async throws {
        
        PTLogger.general.info("Starting download for talk: \(talk.title) (ID: \(talk.id))")
        
        // Check if already downloaded
        if await isDownloaded(talk.id) {
            PTLogger.general.info("Talk \(talk.id) is already downloaded")
            return
        }
        
        // Check if download is already in progress
        if activeDownloads.contains(where: { $0.talkID == talk.id }) {
            PTLogger.general.info("Download for talk \(talk.id) is already in progress")
            return
        }
        
        // Only allow downloading of audio content
        // Skip Vimeo videos and other video content
        PTLogger.general.info("Talk audio URL: '\(talk.audioURL ?? "nil")'")
        PTLogger.general.info("Talk video URL: '\(talk.videoURL ?? "nil")'")
        
        guard let audioURL = talk.audioURL, 
              !audioURL.isEmpty,
              !audioURL.contains("vimeo.com") else {
            PTLogger.general.error("No downloadable audio content available for talk \(talk.id)")
            if let videoURL = talk.videoURL, videoURL.contains("vimeo.com") {
                PTLogger.general.info("Talk has Vimeo video content, but downloads are audio-only")
            }
            throw DownloadError.noDownloadableContent
        }
        
        let downloadURLString = audioURL
        let mediaType: MediaType = .audio
        let estimatedFileSize: Int64 = 0 // Let URLSession determine the actual size
        
        PTLogger.general.info("Selected download URL: '\(downloadURLString)'")
        PTLogger.general.info("Selected media type: \(mediaType.rawValue)")
        
        guard let downloadURL = URL(string: downloadURLString) else {
            PTLogger.general.error("Invalid audio URL for talk \(talk.id): '\(downloadURLString)'")
            throw DownloadError.invalidDownloadURL
        }
        
        do {
            // Validate URL is reachable
            try await validateDownloadURL(downloadURL)
            
            // Create download task
            let downloadTask = DownloadTask(
                id: UUID().uuidString,
                talkID: talk.id,
                downloadURL: downloadURLString,
                status: .pending,
                totalBytes: estimatedFileSize,
                mediaType: mediaType
            )
            
            // Save to Core Data
            try await persistenceController.performBackgroundTask { context in
                let entity = DownloadTaskEntity(context: context)
                entity.id = downloadTask.id
                entity.talkID = downloadTask.talkID
                entity.downloadURL = downloadTask.downloadURL
                entity.status = downloadTask.status.rawValue
                entity.totalBytes = downloadTask.totalBytes
                // Note: mediaType field can be added to Core Data schema in future version
                // entity.mediaType = mediaType.rawValue
                entity.createdAt = Date()
            }
            
            // Start URLSession download
            let urlDownloadTask = urlSession.downloadTask(with: downloadURL)
            urlDownloadTask.resume()
            
            // Update active downloads
            activeDownloads.append(downloadTask)
            downloadProgress[talk.id] = 0.0
            
            PTLogger.general.info("Started \(mediaType.rawValue) download for talk: \(talk.title)")
            
        } catch {
            // Clean up progress indicator on error
            downloadProgress.removeValue(forKey: talk.id)
            
            // Remove from active downloads if it was added
            if let index = activeDownloads.firstIndex(where: { $0.talkID == talk.id }) {
                activeDownloads[index].status = .failed
                activeDownloads.remove(at: index)
            }
            
            PTLogger.general.error("Failed to start download for talk \(talk.id): \(error)")
            throw error
        }
    }
    
    func cancelDownload(for talkID: String) async {
        
        // Find and cancel URLSession task
        let tasks = await urlSession.allTasks
        for task in tasks {
            if let downloadTask = task as? URLSessionDownloadTask,
               let url = downloadTask.originalRequest?.url?.absoluteString,
               activeDownloads.contains(where: { $0.downloadURL == url && $0.talkID == talkID }) {
                
                Task {
                    let resumeData = await downloadTask.cancelByProducingResumeData()
                    await self.saveResumeData(resumeData, for: talkID)
                }
                break
            }
        }
        
        // Update status
        if let index = activeDownloads.firstIndex(where: { $0.talkID == talkID }) {
            activeDownloads[index].status = .cancelled
            activeDownloads.remove(at: index)
        }
        
        downloadProgress.removeValue(forKey: talkID)
        
        // Update Core Data
        try? await persistenceController.performBackgroundTask { context in
            let request: NSFetchRequest<DownloadTaskEntity> = DownloadTaskEntity.fetchRequest()
            request.predicate = NSPredicate(format: "talkID == %@", talkID)
            
            if let entity = try context.fetch(request).first {
                entity.status = DownloadStatus.cancelled.rawValue
            }
        }
    }
    
    func deleteDownload(for talkID: String) async throws {
        
        // Cancel active download if in progress
        await cancelDownload(for: talkID)
        
        // Delete local files (check both audio and video)
        let audioURL = getLocalMediaURL(for: talkID, mediaType: .audio)
        let videoURL = getLocalMediaURL(for: talkID, mediaType: .video)
        
        if FileManager.default.fileExists(atPath: audioURL.path) {
            try FileManager.default.removeItem(at: audioURL)
        }
        if FileManager.default.fileExists(atPath: videoURL.path) {
            try FileManager.default.removeItem(at: videoURL)
        }
        
        // Update Core Data
        try await persistenceController.performBackgroundTask { context in
            // Update talk entity
            let talkRequest: NSFetchRequest<TalkEntity> = TalkEntity.fetchRequest()
            talkRequest.predicate = NSPredicate(format: "id == %@", talkID)
            
            if let talkEntity = try context.fetch(talkRequest).first {
                talkEntity.isDownloaded = false
                talkEntity.localAudioURL = nil
            }
            
            // Delete download task entity
            let downloadRequest: NSFetchRequest<DownloadTaskEntity> = DownloadTaskEntity.fetchRequest()
            downloadRequest.predicate = NSPredicate(format: "talkID == %@", talkID)
            
            let downloadEntities = try context.fetch(downloadRequest)
            for entity in downloadEntities {
                context.delete(entity)
            }
        }
        
        // Invalidate cache
        invalidateCache()
        
        // Post notification that download was deleted
        NotificationCenter.default.post(name: .downloadDeleted, object: nil, userInfo: ["talkID": talkID])
    }
    
    func pauseDownload(for talkID: String) async {
        
        let tasks = await urlSession.allTasks
        for task in tasks {
            if let downloadTask = task as? URLSessionDownloadTask,
               let url = downloadTask.originalRequest?.url?.absoluteString,
               activeDownloads.contains(where: { $0.downloadURL == url && $0.talkID == talkID }) {
                
                Task {
                    let resumeData = await downloadTask.cancelByProducingResumeData()
                    await self.saveResumeData(resumeData, for: talkID)
                }
                break
            }
        }
        
        // Update status
        if let index = activeDownloads.firstIndex(where: { $0.talkID == talkID }) {
            activeDownloads[index].status = .paused
        }
    }
    
    func resumeDownload(for talkID: String) async throws {
        
        guard let downloadTask = activeDownloads.first(where: { $0.talkID == talkID && $0.status == .paused }) else {
            throw DownloadError.downloadTaskNotFound
        }
        
        // Get resume data from Core Data
        let resumeData = try await persistenceController.performBackgroundTask { context in
            let request: NSFetchRequest<DownloadTaskEntity> = DownloadTaskEntity.fetchRequest()
            request.predicate = NSPredicate(format: "talkID == %@", talkID)
            
            return try context.fetch(request).first?.resumeData
        }
        
        let urlDownloadTask: URLSessionDownloadTask
        if let resumeData = resumeData {
            urlDownloadTask = urlSession.downloadTask(withResumeData: resumeData)
        } else {
            guard let downloadURL = URL(string: downloadTask.downloadURL) else {
                throw DownloadError.invalidDownloadURL
            }
            urlDownloadTask = urlSession.downloadTask(with: downloadURL)
        }
        
        urlDownloadTask.resume()
        
        // Update status
        if let index = activeDownloads.firstIndex(where: { $0.talkID == talkID }) {
            activeDownloads[index].status = .downloading
        }
    }
    
    func isDownloaded(_ talkID: String) async -> Bool {
        // Check if either audio or video file exists locally
        let audioURL = getLocalMediaURL(for: talkID, mediaType: .audio)
        let videoURL = getLocalMediaURL(for: talkID, mediaType: .video)
        let fileExists = FileManager.default.fileExists(atPath: audioURL.path) || 
                        FileManager.default.fileExists(atPath: videoURL.path)
        
        // Also check Core Data to ensure consistency
        let isMarkedDownloaded = try? await persistenceController.performBackgroundTask { context in
            let request: NSFetchRequest<TalkEntity> = TalkEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", talkID)
            
            if let entity = try context.fetch(request).first {
                return entity.isDownloaded
            }
            return false
        }
        
        // Return true only if both file exists and is marked as downloaded
        return fileExists && (isMarkedDownloaded ?? false)
    }
    
    /// Synchronous version for UI rendering - only checks file system
    nonisolated func isDownloadedSync(_ talkID: String) -> Bool {
        let audioURL = getLocalMediaURL(for: talkID, mediaType: .audio)
        let videoURL = getLocalMediaURL(for: talkID, mediaType: .video)
        return FileManager.default.fileExists(atPath: audioURL.path) || 
               FileManager.default.fileExists(atPath: videoURL.path)
    }
    
    func getDownloadedTalks() async throws -> [String] {
        return try await persistenceController.performBackgroundTask { context in
            let request: NSFetchRequest<TalkEntity> = TalkEntity.fetchRequest()
            request.predicate = NSPredicate(format: "isDownloaded == YES")
            
            let entities = try context.fetch(request)
            return entities.compactMap { $0.id }
        }
    }
    
    func getDownloadedTalksWithMetadata() async throws -> [DownloadedTalk] {
        // Return cached data if available and valid
        if isCacheValid, !cachedDownloadedTalks.isEmpty {
            PTLogger.general.info("Returning cached downloaded talks: \(self.cachedDownloadedTalks.count)")
            return cachedDownloadedTalks
        }
        
        // Otherwise, refresh the cache
        return try await refreshDownloadedTalksCache()
    }
    
    func refreshDownloadedTalksCache() async throws -> [DownloadedTalk] {
        // First, scan filesystem to ensure we don't miss any downloaded files
        await scanAndReconcileDownloadedFiles()
        
        let talks = try await persistenceController.performBackgroundTask { context in
            let request: NSFetchRequest<TalkEntity> = TalkEntity.fetchRequest()
            request.predicate = NSPredicate(format: "isDownloaded == YES")
            
            let entities = try context.fetch(request)
            PTLogger.general.info("Found \(entities.count) talks marked as downloaded in Core Data")
            
            return entities.compactMap { entity -> DownloadedTalk? in
                guard !entity.id.isEmpty else {
                    PTLogger.general.error("Downloaded talk entity has no ID")
                    return nil
                }
                
                guard let localPath = entity.localAudioURL else {
                    PTLogger.general.error("Downloaded talk \(entity.id) has no localAudioURL")
                    return nil
                }
                
                let fileExists = FileManager.default.fileExists(atPath: localPath)
                if !fileExists {
                    PTLogger.general.error("Downloaded talk \(entity.id) file does not exist at path: \(localPath)")
                    // Mark as not downloaded if file doesn't exist
                    entity.isDownloaded = false
                    entity.localAudioURL = nil
                    return nil
                }
                
                PTLogger.general.info("Successfully found downloaded talk: \(entity.title.isEmpty ? entity.id : entity.title)")
                
                // Get actual duration from audio file
                let actualDuration = self.getAudioFileDuration(filePath: localPath)
                
                return DownloadedTalk(
                    id: entity.id,
                    title: entity.title.isEmpty ? "Downloaded Talk" : entity.title,
                    speaker: entity.speaker?.isEmpty == false ? entity.speaker! : "Unknown Speaker",
                    series: entity.series,
                    duration: actualDuration,
                    fileSize: entity.fileSize,
                    localAudioURL: localPath,
                    lastAccessedAt: entity.lastAccessedAt ?? Date(),
                    createdAt: entity.createdAt ?? Date(),
                    imageURL: entity.imageURL,
                    conferenceImageURL: entity.conferenceImageURL,
                    defaultImageURL: entity.defaultImageURL
                )
            }
        }
        
        // Update cache
        await MainActor.run {
            self.cachedDownloadedTalks = talks
            self.isCacheValid = true
            self.lastCacheUpdate = Date()
        }
        
        return talks
    }
    
    // MARK: - Cache Management
    
    func preloadDownloadedTalks() async {
        PTLogger.general.info("🔄 Preloading downloaded talks cache...")
        
        do {
            // Try to load from Core Data first (fast path)
            let talks = try await loadDownloadedTalksFromCoreData()
            
            await MainActor.run {
                self.cachedDownloadedTalks = talks
                self.isCacheValid = true
                self.lastCacheUpdate = Date()
            }
            
            PTLogger.general.info("✅ Preloaded \(talks.count) downloaded talks from cache")
            
            // If we found talks, we're good. If not, try a background refresh
            if talks.isEmpty {
                PTLogger.general.info("No talks found in Core Data, attempting background refresh...")
                Task {
                    do {
                        try await refreshDownloadedTalksCache()
                    } catch {
                        PTLogger.general.error("❌ Background refresh failed: \(error.localizedDescription)")
                    }
                }
            } else if shouldRefreshCache() {
                Task {
                    do {
                        try await refreshDownloadedTalksCache()
                    } catch {
                        PTLogger.general.error("❌ Background refresh failed: \(error.localizedDescription)")
                    }
                }
            }
        } catch {
            PTLogger.general.error("❌ Failed to preload downloaded talks: \(error.localizedDescription)")
            // Try to refresh cache as fallback
            Task {
                do {
                    try await refreshDownloadedTalksCache()
                } catch {
                    PTLogger.general.error("❌ Fallback refresh also failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func loadDownloadedTalksFromCoreData() async throws -> [DownloadedTalk] {
        return try await persistenceController.performBackgroundTask { context in
            let request: NSFetchRequest<TalkEntity> = TalkEntity.fetchRequest()
            request.predicate = NSPredicate(format: "isDownloaded == YES")
            
            let entities = try context.fetch(request)
            PTLogger.general.info("Found \(entities.count) talks marked as downloaded in Core Data")
            
            // Debug: Log all entities found
            for entity in entities {
                PTLogger.general.info("Entity: \(entity.id) - isDownloaded: \(entity.isDownloaded) - localAudioURL: \(entity.localAudioURL ?? "nil")")
            }
            
            return entities.compactMap { entity -> DownloadedTalk? in
                guard !entity.id.isEmpty else {
                    PTLogger.general.error("Downloaded talk entity has no ID")
                    return nil
                }
                
                guard let localPath = entity.localAudioURL else {
                    PTLogger.general.error("Downloaded talk \(entity.id) has no localAudioURL")
                    return nil
                }
                
                let fileExists = FileManager.default.fileExists(atPath: localPath)
                if !fileExists {
                    PTLogger.general.error("Downloaded talk \(entity.id) file does not exist at path: \(localPath)")
                    return nil
                }
                
                // Get actual duration from audio file
                let actualDuration = self.getAudioFileDuration(filePath: localPath)
                
                return DownloadedTalk(
                    id: entity.id,
                    title: entity.title.isEmpty ? "Downloaded Talk" : entity.title,
                    speaker: entity.speaker?.isEmpty == false ? entity.speaker! : "Unknown Speaker",
                    series: entity.series,
                    duration: actualDuration,
                    fileSize: entity.fileSize,
                    localAudioURL: localPath,
                    lastAccessedAt: entity.lastAccessedAt ?? Date(),
                    createdAt: entity.createdAt ?? Date(),
                    imageURL: entity.imageURL,
                    conferenceImageURL: entity.conferenceImageURL,
                    defaultImageURL: entity.defaultImageURL
                )
            }
        }
    }
    
    private func shouldRefreshCache() -> Bool {
        guard let lastUpdate = lastCacheUpdate else { return true }
        return Date().timeIntervalSince(lastUpdate) > cacheValidityDuration
    }
    
    func invalidateCache() {
        isCacheValid = false
        cachedDownloadedTalks = []
        lastCacheUpdate = nil
    }
    
    // MARK: - Audio File Duration
    
    nonisolated private func getAudioFileDuration(filePath: String) -> Int {
        let url = URL(fileURLWithPath: filePath)
        
        do {
            let audioFile = try AVAudioFile(forReading: url)
            let frameCount = audioFile.length
            let sampleRate = audioFile.fileFormat.sampleRate
            let duration = Double(frameCount) / sampleRate
            return Int(duration)
        } catch {
            PTLogger.general.error("Failed to get audio duration for \(filePath): \(error.localizedDescription)")
            
            // Fallback: try to estimate from file size (very rough estimate)
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: filePath)
                if let fileSize = attributes[.size] as? Int64 {
                    // Rough estimate: assume 128kbps MP3 (16KB per second)
                    let estimatedDuration = Int(fileSize / 16000)
                    return max(estimatedDuration, 0)
                }
            } catch {
                PTLogger.general.error("Failed to get file size for duration estimation: \(error.localizedDescription)")
            }
            
            return 0
        }
    }
    
    // MARK: - Filesystem Scanning
    
    func scanAndReconcileDownloadedFiles() async {
        PTLogger.general.info("🔍 Scanning filesystem for downloaded audio files...")
        
        let audioDirectory = getAudioDirectory()
        
        guard FileManager.default.fileExists(atPath: audioDirectory.path) else {
            PTLogger.general.info("📁 Audio directory does not exist, nothing to scan")
            return
        }
        
        do {
            let audioFiles = try FileManager.default.contentsOfDirectory(at: audioDirectory, includingPropertiesForKeys: [.fileSizeKey, .creationDateKey, .contentModificationDateKey], options: .skipsHiddenFiles)
            
            PTLogger.general.info("📁 Found \(audioFiles.count) audio files in directory")
            
            // Process files in batches to avoid memory pressure
            let batchSize = 10
            for batch in audioFiles.chunked(into: batchSize) {
                await processBatch(batch)
                // Yield to prevent blocking the main queue
                await Task.yield()
            }
        } catch {
            PTLogger.general.error("❌ Failed to scan audio directory: \(error.localizedDescription)")
        }
    }
    
    private func processBatch(_ audioFiles: [URL]) async {
        for audioFile in audioFiles {
            do {
                let fileName = audioFile.deletingPathExtension().lastPathComponent
                
                // Extract talk ID from filename (assuming format: {talkID}.mp3)
                let talkID = fileName
                
                PTLogger.general.info("📄 Processing audio file: \(fileName) -> Talk ID: \(talkID)")
                
                // Check if this file is already properly tracked in Core Data
                let isTracked = try await persistenceController.performBackgroundTask { context in
                    let request: NSFetchRequest<TalkEntity> = TalkEntity.fetchRequest()
                    request.predicate = NSPredicate(format: "id == %@ AND isDownloaded == YES AND localAudioURL != nil", talkID)
                    
                    let count = try context.count(for: request)
                    return count > 0
                }
                
                if !isTracked {
                    PTLogger.general.info("📂 File \(fileName) not tracked in Core Data, attempting to create entry")
                    
                    // Try to get file information
                    let resourceValues = try audioFile.resourceValues(forKeys: [.fileSizeKey, .creationDateKey, .contentModificationDateKey])
                    let fileSize = Int64(resourceValues.fileSize ?? 0)
                    let createdAt = resourceValues.creationDate ?? Date()
                    
                    // Try to get talk metadata from API or create minimal entry
                    await createOrUpdateTalkEntity(
                        talkID: talkID,
                        localAudioURL: audioFile.path,
                        fileSize: fileSize,
                        createdAt: createdAt
                    )
                }
            } catch {
                PTLogger.general.error("❌ Failed to process audio file \(audioFile.lastPathComponent): \(error.localizedDescription)")
            }
        }
    }
    
    private func createOrUpdateTalkEntity(talkID: String, localAudioURL: String, fileSize: Int64, createdAt: Date) async {
        do {
            // First, try to fetch talk metadata from API if we're online
            var talkMetadata: Talk? = nil
            
            // Only try API if we have network connectivity (simple check)
            let canReachAPI = await testAPIConnectivity()
            if canReachAPI {
                talkMetadata = try? await apiService.fetchTalkDetail(id: talkID)
                PTLogger.general.info("📡 Fetched metadata for talk \(talkID) from API")
            } else {
                PTLogger.general.info("📴 Offline - creating minimal metadata for talk \(talkID)")
            }
            
            // Create or update Core Data entity
            try await persistenceController.performBackgroundTask { context in
                let request: NSFetchRequest<TalkEntity> = TalkEntity.fetchRequest()
                request.predicate = NSPredicate(format: "id == %@", talkID)
                
                let entity: TalkEntity
                if let existingEntity = try context.fetch(request).first {
                    entity = existingEntity
                    PTLogger.general.info("📝 Updating existing entity for talk \(talkID)")
                } else {
                    entity = TalkEntity(context: context)
                    entity.id = talkID
                    entity.createdAt = createdAt
                    PTLogger.general.info("➕ Creating new entity for talk \(talkID)")
                }
                
                // Update with API metadata if available, otherwise use minimal data
                if let talk = talkMetadata {
                    entity.title = talk.title
                    entity.speaker = talk.speaker
                    entity.series = talk.series
                    entity.duration = Int32(talk.duration)
                    entity.desc = talk.description
                    entity.audioURL = talk.audioURL
                    entity.imageURL = talk.imageURL
                    entity.conferenceImageURL = talk.conferenceImageURL
                    entity.defaultImageURL = talk.defaultImageURL
                    entity.dateRecorded = talk.dateRecorded
                    entity.biblePassage = talk.biblePassage
                } else {
                    // Enhanced metadata for offline files with better estimates
                    if entity.title.isEmpty {
                        entity.title = "Downloaded Talk"
                        // Try to extract meaningful info from talkID if it follows a pattern
                        if let titleFromID = self.extractTitleFromID(talkID) {
                            entity.title = titleFromID
                        }
                    }
                    if entity.speaker == nil || entity.speaker?.isEmpty == true {
                        entity.speaker = "Unknown Speaker"
                    }
                    if entity.duration == 0 {
                        // Better duration estimation based on audio file analysis
                        let estimatedDuration = self.estimateAudioDuration(fileSize: fileSize, filePath: localAudioURL)
                        entity.duration = Int32(estimatedDuration)
                    }
                }
                
                // Set download-specific properties
                entity.isDownloaded = true
                entity.localAudioURL = localAudioURL
                entity.fileSize = fileSize
                entity.lastAccessedAt = Date()
                entity.updatedAt = Date()
                
                try context.save()
                PTLogger.general.info("✅ Successfully saved entity for talk \(talkID)")
            }
            
        } catch {
            PTLogger.general.error("❌ Failed to create/update entity for talk \(talkID): \(error)")
        }
    }
    
    private func testAPIConnectivity() async -> Bool {
        do {
            let url = URL(string: "https://www.proctrust.org.uk/api/resources/talks")!
            var request = URLRequest(url: url)
            request.httpMethod = "HEAD"
            request.timeoutInterval = 5.0
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode == 200
            }
            return false
        } catch {
            return false
        }
    }
    
    // MARK: - Metadata Enhancement Helpers
    
    private func extractTitleFromID(_ talkID: String) -> String? {
        // Try to extract meaningful titles from common ID patterns
        // Examples: "talk-123-sermon-title" -> "Sermon Title"
        //           "2023-john-smith-gospel" -> "Gospel (John Smith, 2023)"
        
        let components = talkID.replacingOccurrences(of: "-", with: " ")
                               .replacingOccurrences(of: "_", with: " ")
                               .split(separator: " ")
                               .map { $0.capitalized }
        
        if components.count >= 2 {
            // Filter out numeric-only components and common prefixes
            let meaningfulComponents = components.filter { component in
                !component.allSatisfy { $0.isNumber } && 
                !["Talk", "Audio", "Mp3", "File"].contains(component)
            }
            
            if !meaningfulComponents.isEmpty {
                return meaningfulComponents.joined(separator: " ")
            }
        }
        
        return nil
    }
    
    private func estimateAudioDuration(fileSize: Int64, filePath: String) -> Int {
        // More sophisticated duration estimation
        // MP3 files typically have bitrates between 128-320 kbps
        // Average estimate: 192 kbps = 24 KB/s = 1440 KB/min
        
        let averageBytesPerSecond: Int64 = 24000 // 192 kbps = 24 KB/s
        let estimatedSeconds = max(30, fileSize / averageBytesPerSecond) // Minimum 30 seconds
        
        // Cap at reasonable maximum (4 hours = 14400 seconds)
        return min(14400, Int(estimatedSeconds))
    }
    
    func getTotalStorageUsed() async -> Int64 {
        let audioDirectory = getAudioDirectory()
        let videoDirectory = getVideoDirectory()
        
        PTLogger.general.info("Calculating storage usage...")
        PTLogger.general.info("Audio directory: \(audioDirectory.path)")
        PTLogger.general.info("Video directory: \(videoDirectory.path)")
        
        var totalSize: Int64 = 0
        
        // Check audio directory
        if FileManager.default.fileExists(atPath: audioDirectory.path) {
            guard let enumerator = FileManager.default.enumerator(at: audioDirectory, includingPropertiesForKeys: [.fileSizeKey]) else {
                PTLogger.general.error("Failed to create enumerator for audio directory")
                return 0
            }
            
            for case let fileURL as URL in enumerator.allObjects {
                do {
                    let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey])
                    let fileSize = Int64(resourceValues.fileSize ?? 0)
                    totalSize += fileSize
                    PTLogger.general.info("Audio file: \(fileURL.lastPathComponent) - \(fileSize) bytes")
                } catch {
                    PTLogger.general.error("Failed to get size for audio file \(fileURL.lastPathComponent): \(error)")
                }
            }
        } else {
            PTLogger.general.info("Audio directory does not exist")
        }
        
        // Check video directory
        if FileManager.default.fileExists(atPath: videoDirectory.path) {
            guard let enumerator = FileManager.default.enumerator(at: videoDirectory, includingPropertiesForKeys: [.fileSizeKey]) else {
                PTLogger.general.error("Failed to create enumerator for video directory")
                return totalSize
            }
            
            for case let fileURL as URL in enumerator.allObjects {
                do {
                    let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey])
                    let fileSize = Int64(resourceValues.fileSize ?? 0)
                    totalSize += fileSize
                    PTLogger.general.info("Video file: \(fileURL.lastPathComponent) - \(fileSize) bytes")
                } catch {
                    PTLogger.general.error("Failed to get size for video file \(fileURL.lastPathComponent): \(error)")
                }
            }
        } else {
            PTLogger.general.info("Video directory does not exist")
        }
        
        PTLogger.general.info("Total storage used: \(totalSize) bytes")
        return totalSize
    }
    
    func cleanupExpiredDownloads() async throws {
        let expiredDate = Date().addingTimeInterval(-TimeInterval(Config.defaultAutoDeleteDays * 24 * 60 * 60))
        
        let expiredTalkIDs = try await persistenceController.performBackgroundTask { context in
            let request: NSFetchRequest<TalkEntity> = TalkEntity.fetchRequest()
            request.predicate = NSPredicate(format: "isDownloaded == YES AND lastAccessedAt < %@", expiredDate as NSDate)
            
            let entities = try context.fetch(request)
            return entities.compactMap { $0.id }
        }
        
        for talkID in expiredTalkIDs {
            try await deleteDownload(for: talkID)
        }
    }
    
    // MARK: - Private Methods
    
    private func validateDownloadURL(_ url: URL) async throws {
        // Perform HEAD request to validate URL
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 10.0
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw DownloadError.invalidDownloadURL
            }
            
            guard httpResponse.statusCode == 200 else {
                PTLogger.general.error("Download URL validation failed with status: \(httpResponse.statusCode)")
                throw DownloadError.invalidDownloadURL
            }
            
            PTLogger.general.info("Download URL validated successfully: \(url.absoluteString)")
            
        } catch {
            PTLogger.general.error("Failed to validate download URL: \(error)")
            throw DownloadError.networkError
        }
    }
    
    private func validateDownloadedFile(at url: URL, expectedSize: Int64?) -> Bool {
        guard FileManager.default.fileExists(atPath: url.path) else {
            PTLogger.general.error("Downloaded file does not exist at path: \(url.path)")
            return false
        }
        
        // Check file size
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let fileSize = attributes[.size] as? Int64 ?? 0
            
            if let expectedSize = expectedSize, expectedSize > 0 {
                let sizeTolerance: Int64 = 1024 * 10 // 10KB tolerance
                if abs(fileSize - expectedSize) > sizeTolerance {
                    PTLogger.general.error("File size mismatch. Expected: \(expectedSize), Actual: \(fileSize)")
                    return false
                }
            }
            
            // Check if file is a valid audio file (basic check)
            if fileSize < 1000 { // File should be at least 1KB
                PTLogger.general.error("Downloaded file is too small: \(fileSize) bytes")
                return false
            }
            
            PTLogger.general.info("Downloaded file validation passed: \(fileSize) bytes")
            return true
            
        } catch {
            PTLogger.general.error("Failed to validate downloaded file: \(error)")
            return false
        }
    }
    
    private func loadDownloadTasks() {
        Task {
            let tasks = try await persistenceController.performBackgroundTask { context in
                let request: NSFetchRequest<DownloadTaskEntity> = DownloadTaskEntity.fetchRequest()
                request.predicate = NSPredicate(format: "status IN %@", [DownloadStatus.pending.rawValue, DownloadStatus.downloading.rawValue, DownloadStatus.paused.rawValue])
                
                let entities = try context.fetch(request)
                return entities.map { entity in
                    DownloadTask(
                        id: entity.id,
                        talkID: entity.talkID,
                        downloadURL: entity.downloadURL,
                        status: DownloadStatus(rawValue: entity.status ?? "") ?? .pending,
                        totalBytes: entity.totalBytes,
                        downloadedBytes: entity.downloadedBytes,
                        progress: entity.progress,
                        createdAt: entity.createdAt ?? Date()
                    )
                }
            }
            
            await MainActor.run {
                self.activeDownloads = tasks
                
                // Initialize progress for active downloads
                for task in tasks {
                    if task.status == .downloading || task.status == .pending {
                        self.downloadProgress[task.talkID] = task.progress
                    }
                }
            }
        }
    }
    
    private func saveResumeData(_ resumeData: Data?, for talkID: String) async {
        guard let resumeData = resumeData else { return }
        try? await persistenceController.performBackgroundTask { context in
            let request: NSFetchRequest<DownloadTaskEntity> = DownloadTaskEntity.fetchRequest()
            request.predicate = NSPredicate(format: "talkID == %@", talkID)
            
            if let entity = try context.fetch(request).first {
                entity.resumeData = resumeData
            }
        }
    }
    
    nonisolated private func getAudioDirectory() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let audioDirectory = documentsPath.appendingPathComponent("audio")
        
        PTLogger.general.info("📁 Audio directory path: \(audioDirectory.path)")
        
        // Create directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: audioDirectory.path) {
            do {
                try FileManager.default.createDirectory(at: audioDirectory, withIntermediateDirectories: true, attributes: nil)
                PTLogger.general.info("📁 Created audio directory successfully")
            } catch {
                PTLogger.general.error("📁 Failed to create audio directory: \(error)")
            }
        } else {
            PTLogger.general.info("📁 Audio directory already exists")
        }
        
        return audioDirectory
    }
    
    nonisolated private func getLocalMediaURL(for talkID: String, mediaType: MediaType) -> URL {
        let directory = mediaType == .audio ? getAudioDirectory() : getVideoDirectory()
        let fileExtension = mediaType == .audio ? "mp3" : "mp4"
        return directory.appendingPathComponent("\(talkID).\(fileExtension)")
    }
    
    nonisolated private func getVideoDirectory() -> URL {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let videoDirectory = documentsURL.appendingPathComponent("video")
        
        // Create directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: videoDirectory.path) {
            do {
                try FileManager.default.createDirectory(at: videoDirectory, withIntermediateDirectories: true, attributes: nil)
            } catch {
                PTLogger.general.error("📁 Failed to create video directory: \(error)")
            }}
        
        return videoDirectory
    }
    
    nonisolated private func moveDownloadedFile(from sourceURL: URL, to destinationURL: URL) throws {
        PTLogger.general.info("🚚 Moving file from \(sourceURL.path) to \(destinationURL.path)")
        
        // Check if source file exists
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            PTLogger.general.error("🚨 Source file does not exist: \(sourceURL.path)")
            throw DownloadError.fileNotFound
        }
        
        // Create directory if needed
        let directory = destinationURL.deletingLastPathComponent()
        PTLogger.general.info("📁 Ensuring directory exists: \(directory.path)")
        
        if !FileManager.default.fileExists(atPath: directory.path) {
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
                PTLogger.general.info("📁 Created directory: \(directory.path)")
            } catch {
                PTLogger.general.error("📁 Failed to create directory: \(error)")
                throw error
            }
        } else {
            PTLogger.general.info("📁 Directory already exists: \(directory.path)")
        }
        
        // Remove existing file if it exists
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            PTLogger.general.info("🗑️ Removing existing file: \(destinationURL.path)")
            try FileManager.default.removeItem(at: destinationURL)
        }
        
        // Try to move the file
        do {
            try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
            PTLogger.general.info("✅ Successfully moved file to: \(destinationURL.path)")
            
            // Verify the file was actually moved
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                let attributes = try FileManager.default.attributesOfItem(atPath: destinationURL.path)
                let fileSize = attributes[.size] as? Int64 ?? 0
                PTLogger.general.info("📊 Moved file size: \(fileSize) bytes")
            } else {
                PTLogger.general.error("❌ File move reported success but destination file doesn't exist")
                throw DownloadError.fileMoveFailed
            }
        } catch {
            PTLogger.general.error("🚨 Failed to move file: \(error)")
            
            // Try copying instead of moving as a fallback
            PTLogger.general.info("🔄 Attempting to copy file as fallback...")
            do {
                try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
                PTLogger.general.info("✅ Successfully copied file to: \(destinationURL.path)")
                
                // Remove the original file after successful copy
                try? FileManager.default.removeItem(at: sourceURL)
                PTLogger.general.info("🗑️ Removed original file after copy")
            } catch let copyError {
                PTLogger.general.error("🚨 Copy fallback also failed: \(copyError)")
                throw copyError
            }
        }
    }
}

// MARK: - URLSessionDownloadDelegate

extension DownloadService: URLSessionDownloadDelegate {
    
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        
        // Find matching download task
        guard let downloadURL = downloadTask.originalRequest?.url?.absoluteString else {
            PTLogger.general.error("No download URL found in finished download task")
            return
        }
        
        PTLogger.general.info("📥 Download finished for URL: \(downloadURL)")
        PTLogger.general.info("📍 Temporary file location: \(location.path)")
        
        // CRITICAL: We must move the file immediately within this delegate callback
        // The temporary file location is only valid during this method execution
        
        // First, get the download task info synchronously 
        var talkID: String?
        var mediaType: MediaType?
        
        // Access activeDownloads synchronously to get task info before file disappears
        DispatchQueue.main.sync {
            if let task = self.activeDownloads.first(where: { $0.downloadURL == downloadURL }) {
                talkID = task.talkID
                mediaType = task.mediaType
                PTLogger.general.info("✅ Found matching download task for talk: \(task.talkID)")
            } else {
                PTLogger.general.error("❌ No matching download task found for URL: \(downloadURL)")
            }
        }
        
        guard let validTalkID = talkID, let validMediaType = mediaType else {
            PTLogger.general.error("Missing talk ID or media type for download")
            return
        }
        
        let localURL = getLocalMediaURL(for: validTalkID, mediaType: validMediaType)
        
        // Move the file IMMEDIATELY while the temp file still exists
        do {
            try moveDownloadedFile(from: location, to: localURL)
            PTLogger.general.info("🎉 File successfully moved to: \(localURL.path)")
            
            // Now handle the async Core Data updates
            Task { @MainActor in
                await handleDownloadCompletion(talkID: validTalkID, localURL: localURL, downloadURL: downloadURL)
            }
        } catch {
            PTLogger.general.error("❌ Failed to move downloaded file: \(error)")
            
            // Update download task status to failed
            Task { @MainActor in
                if let index = self.activeDownloads.firstIndex(where: { $0.talkID == validTalkID }) {
                    self.activeDownloads[index].status = .failed
                }
            }
        }
    }
    
    @MainActor
    private func handleDownloadCompletion(talkID: String, localURL: URL, downloadURL: String) async {
        // Validate the downloaded file (no size expectation - just check it exists and is reasonable)
        guard validateDownloadedFile(at: localURL, expectedSize: nil) else {
            PTLogger.general.error("Downloaded file validation failed for talk: \(talkID)")
            
            // Remove invalid file
            try? FileManager.default.removeItem(at: localURL)
            
            // Update download task status to failed
            if let index = activeDownloads.firstIndex(where: { $0.talkID == talkID }) {
                activeDownloads[index].status = .failed
            }
            
            return
        }
        
        // Update Core Data
        do {
            try await persistenceController.performBackgroundTask { context in
                // Update talk entity
                let talkRequest: NSFetchRequest<TalkEntity> = TalkEntity.fetchRequest()
                talkRequest.predicate = NSPredicate(format: "id == %@", talkID)
                
                let talkEntities = try context.fetch(talkRequest)
                PTLogger.general.info("Found \(talkEntities.count) talk entities with ID \(talkID)")
                
                if let talkEntity = talkEntities.first {
                    PTLogger.general.info("Updating talk entity: \(talkEntity.title) - setting isDownloaded=true, localAudioURL=\(localURL.path)")
                    talkEntity.isDownloaded = true
                    talkEntity.localAudioURL = localURL.path
                    talkEntity.lastAccessedAt = Date()
                    
                    // Get actual duration from the downloaded audio file
                    let actualDuration = self.getAudioFileDuration(filePath: localURL.path)
                    talkEntity.duration = Int32(actualDuration)
                    
                    if let attributes = try? FileManager.default.attributesOfItem(atPath: localURL.path),
                       let size = attributes[.size] as? Int64 {
                        talkEntity.fileSize = size
                    }
                } else {
                    PTLogger.general.error("No talk entity found with ID \(talkID) - creating new one")
                    // This shouldn't normally happen, but we'll create a minimal entity
                    let newTalkEntity = TalkEntity(context: context)
                    newTalkEntity.id = talkID
                    newTalkEntity.title = "Downloaded Talk" // Placeholder - should be populated from Talk object
                    newTalkEntity.speaker = "Unknown Speaker" // Placeholder
                    
                    // Get actual duration from the downloaded audio file
                    let actualDuration = self.getAudioFileDuration(filePath: localURL.path)
                    newTalkEntity.duration = Int32(actualDuration)
                    
                    newTalkEntity.isDownloaded = true
                    newTalkEntity.localAudioURL = localURL.path
                    newTalkEntity.lastAccessedAt = Date()
                    newTalkEntity.createdAt = Date()
                    if let attributes = try? FileManager.default.attributesOfItem(atPath: localURL.path),
                       let size = attributes[.size] as? Int64 {
                        newTalkEntity.fileSize = size
                    }
                }
                
                // Update download task entity
                let downloadRequest: NSFetchRequest<DownloadTaskEntity> = DownloadTaskEntity.fetchRequest()
                downloadRequest.predicate = NSPredicate(format: "talkID == %@", talkID)
                
                if let entity = try context.fetch(downloadRequest).first {
                    entity.status = DownloadStatus.completed.rawValue
                    entity.completedAt = Date()
                    entity.progress = 1.0
                }
                
                // Force save the context
                try context.save()
                PTLogger.general.info("Successfully saved Core Data changes for talk \(talkID)")
            }
            
            // Update UI state - mark as completed and clear progress
            if let index = activeDownloads.firstIndex(where: { $0.talkID == talkID }) {
                activeDownloads[index].status = .completed
                activeDownloads.remove(at: index)
            }
            
            // Clear progress to show checkmark instead of 100%
            downloadProgress.removeValue(forKey: talkID)
            
            PTLogger.general.info("Download completed and validated for talk: \(talkID)")
            
            // Invalidate cache to refresh downloaded talks list
            invalidateCache()
            
            // Post notification that download completed
            NotificationCenter.default.post(name: .downloadCompleted, object: nil, userInfo: ["talkID": talkID])
            
        } catch {
            PTLogger.general.error("Failed to save Core Data changes for talk \(talkID): \(error)")
            
            // Update error status
            if let index = activeDownloads.firstIndex(where: { $0.talkID == talkID }) {
                activeDownloads[index].status = .failed
            }
            
            // Post notification that download failed
            NotificationCenter.default.post(name: .downloadFailed, object: nil, userInfo: ["talkID": talkID, "error": error.localizedDescription])
        }
    }
    
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        
        guard let downloadURL = downloadTask.originalRequest?.url?.absoluteString else {
            return
        }
        
        let progress = totalBytesExpectedToWrite > 0 ? Float(totalBytesWritten) / Float(totalBytesExpectedToWrite) : 0.0
        
        Task { @MainActor in
            guard let talkID = activeDownloads.first(where: { $0.downloadURL == downloadURL })?.talkID else {
                return
            }
            
            downloadProgress[talkID] = progress
            
            // Update download task
            if let index = activeDownloads.firstIndex(where: { $0.talkID == talkID }) {
                activeDownloads[index].downloadedBytes = totalBytesWritten
                activeDownloads[index].progress = progress
                activeDownloads[index].status = .downloading
            }
            
            // Update Core Data periodically
            if Int(progress * 100) % 10 == 0 { // Update every 10%
                try? await persistenceController.performBackgroundTask { context in
                    let request: NSFetchRequest<DownloadTaskEntity> = DownloadTaskEntity.fetchRequest()
                    request.predicate = NSPredicate(format: "talkID == %@", talkID)
                    
                    if let entity = try context.fetch(request).first {
                        entity.downloadedBytes = totalBytesWritten
                        entity.progress = progress
                        entity.status = DownloadStatus.downloading.rawValue
                    }
                }
            }
        }
    }
    
    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        
        guard let error = error,
              let downloadURL = task.originalRequest?.url?.absoluteString else {
            return
        }
        
        Task { @MainActor in
            guard let talkID = activeDownloads.first(where: { $0.downloadURL == downloadURL })?.talkID else {
                return
            }
            
            PTLogger.general.error("Download failed for talk \(talkID): \(error.localizedDescription)")
            
            // Update error status in Core Data
            try? await persistenceController.performBackgroundTask { context in
                let request: NSFetchRequest<DownloadTaskEntity> = DownloadTaskEntity.fetchRequest()
                request.predicate = NSPredicate(format: "talkID == %@", talkID)
                
                if let entity = try context.fetch(request).first {
                    entity.status = DownloadStatus.failed.rawValue
                }
            }
            
            // Update UI state
            if let index = activeDownloads.firstIndex(where: { $0.talkID == talkID }) {
                activeDownloads[index].status = .failed
                activeDownloads.remove(at: index)
            }
            
            downloadProgress.removeValue(forKey: talkID)
        }
    }
    
    nonisolated func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        DispatchQueue.main.async {
            self.backgroundCompletionHandler?()
            self.backgroundCompletionHandler = nil
        }
    }
}

// MARK: - Supporting Types

struct DownloadTask: Identifiable, Equatable {
    let id: String
    let talkID: String
    let downloadURL: String
    var status: DownloadStatus
    var totalBytes: Int64
    var downloadedBytes: Int64
    var progress: Float
    let createdAt: Date
    let mediaType: MediaType
    
    init(id: String, talkID: String, downloadURL: String, status: DownloadStatus = .pending, totalBytes: Int64 = 0, downloadedBytes: Int64 = 0, progress: Float = 0, createdAt: Date = Date(), mediaType: MediaType = .audio) {
        self.id = id
        self.talkID = talkID
        self.downloadURL = downloadURL
        self.status = status
        self.totalBytes = totalBytes
        self.downloadedBytes = downloadedBytes
        self.progress = progress
        self.createdAt = createdAt
        self.mediaType = mediaType
    }
}

enum DownloadStatus: String, CaseIterable {
    case pending = "pending"
    case downloading = "downloading"
    case paused = "paused"
    case completed = "completed"
    case failed = "failed"
    case cancelled = "cancelled"
    
    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .downloading: return "Downloading"
        case .paused: return "Paused"
        case .completed: return "Completed"
        case .failed: return "Failed"
        case .cancelled: return "Cancelled"
        }
    }
}

enum MediaType: String, CaseIterable {
    case audio = "audio"
    case video = "video"
    
    var displayName: String {
        switch self {
        case .audio: return "Audio"
        case .video: return "Video"
        }
    }
    
    var icon: String {
        switch self {
        case .audio: return "speaker.wave.3"
        case .video: return "video"
        }
    }
}

enum DownloadError: LocalizedError {
    case invalidDownloadURL
    case downloadTaskNotFound
    case fileSystemError
    case networkError
    case fileValidationFailed
    case fileSizeMismatch
    case unsupportedURL
    case noDownloadableContent
    case fileNotFound
    case fileMoveFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidDownloadURL: return "Invalid download URL"
        case .downloadTaskNotFound: return "Download task not found"
        case .fileSystemError: return "File system error"
        case .networkError: return "Network error"
        case .fileValidationFailed: return "Downloaded file validation failed"
        case .fileSizeMismatch: return "Downloaded file size does not match expected size"
        case .unsupportedURL: return "URL type not supported for download"
        case .noDownloadableContent: return "No downloadable audio or video content found"
        case .fileNotFound: return "Downloaded file not found"
        case .fileMoveFailed: return "Failed to move downloaded file"
        }
    }
}

// MARK: - Array Extension for Batching

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

// MARK: - Downloaded Talk Model

struct DownloadedTalk: Identifiable, Equatable {
    let id: String
    let title: String
    let speaker: String
    let series: String?
    let duration: Int
    let fileSize: Int64
    let localAudioURL: String
    let lastAccessedAt: Date
    let createdAt: Date
    
    // Artwork URLs for priority-based image display
    let imageURL: String?
    let conferenceImageURL: String?
    let defaultImageURL: String?
    
    var formattedDuration: String {
        let minutes = duration / 60
        let seconds = duration % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var formattedFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }
    
    var formattedLastAccessed: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: lastAccessedAt, relativeTo: Date())
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