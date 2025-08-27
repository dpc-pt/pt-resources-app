//
//  DownloadService.swift
//  PT Resources
//
//  Service for downloading and managing offline talk files
//

import Foundation
import CoreData

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
    
    // MARK: - Private Properties
    
    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: "com.proctrust.downloads")
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()
    
    private let apiService: TalksAPIServiceProtocol
    private let persistenceController: PersistenceController
    private let fileManager = FileManager.default
    
    private var backgroundCompletionHandler: (() -> Void)?
    
    // MARK: - Initialization
    
    init(apiService: TalksAPIServiceProtocol, persistenceController: PersistenceController = .shared) {
        self.apiService = apiService
        self.persistenceController = persistenceController
        super.init()
        
        // Load existing download tasks
        loadDownloadTasks()
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
                // TODO: Add mediaType field to Core Data schema
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
                
                downloadTask.cancel { [weak self] resumeData in
                    Task { @MainActor in
                        if let resumeData = resumeData {
                            await self?.saveResumeData(resumeData, for: talkID)
                        }
                    }
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
        
        if fileManager.fileExists(atPath: audioURL.path) {
            try fileManager.removeItem(at: audioURL)
        }
        if fileManager.fileExists(atPath: videoURL.path) {
            try fileManager.removeItem(at: videoURL)
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
        
        // Post notification that download was deleted
        NotificationCenter.default.post(name: .downloadDeleted, object: nil, userInfo: ["talkID": talkID])
    }
    
    func pauseDownload(for talkID: String) async {
        
        let tasks = await urlSession.allTasks
        for task in tasks {
            if let downloadTask = task as? URLSessionDownloadTask,
               let url = downloadTask.originalRequest?.url?.absoluteString,
               activeDownloads.contains(where: { $0.downloadURL == url && $0.talkID == talkID }) {
                
                downloadTask.cancel { [weak self] resumeData in
                    Task { @MainActor in
                        if let resumeData = resumeData {
                            await self?.saveResumeData(resumeData, for: talkID)
                        }
                    }
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
        let fileExists = fileManager.fileExists(atPath: audioURL.path) || 
                        fileManager.fileExists(atPath: videoURL.path)
        
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
    
    func getDownloadedTalks() async throws -> [String] {
        return try await persistenceController.performBackgroundTask { context in
            let request: NSFetchRequest<TalkEntity> = TalkEntity.fetchRequest()
            request.predicate = NSPredicate(format: "isDownloaded == YES")
            
            let entities = try context.fetch(request)
            return entities.compactMap { $0.id }
        }
    }
    
    func getDownloadedTalksWithMetadata() async throws -> [DownloadedTalk] {
        return try await persistenceController.performBackgroundTask { context in
            let request: NSFetchRequest<TalkEntity> = TalkEntity.fetchRequest()
            request.predicate = NSPredicate(format: "isDownloaded == YES")
            
            let entities = try context.fetch(request)
            PTLogger.general.info("Found \(entities.count) talks marked as downloaded in Core Data")
            
            return entities.compactMap { entity in
                guard let id = entity.id else {
                    PTLogger.general.error("Downloaded talk entity has no ID")
                    return nil
                }
                
                guard let localPath = entity.localAudioURL else {
                    PTLogger.general.error("Downloaded talk \(id) has no localAudioURL")
                    return nil
                }
                
                let fileExists = FileManager.default.fileExists(atPath: localPath)
                if !fileExists {
                    PTLogger.general.error("Downloaded talk \(id) file does not exist at path: \(localPath)")
                    return nil
                }
                
                PTLogger.general.info("Successfully found downloaded talk: \(entity.title ?? id)")
                
                return DownloadedTalk(
                    id: id,
                    title: entity.title ?? "",
                    speaker: entity.speaker ?? "",
                    series: entity.series,
                    duration: Int(entity.duration),
                    fileSize: entity.fileSize,
                    localAudioURL: localPath,
                    lastAccessedAt: entity.lastAccessedAt ?? Date(),
                    createdAt: entity.createdAt ?? Date()
                )
            }
        }
    }
    
    func getTotalStorageUsed() async -> Int64 {
        let audioDirectory = getAudioDirectory()
        let videoDirectory = getVideoDirectory()
        
        PTLogger.general.info("Calculating storage usage...")
        PTLogger.general.info("Audio directory: \(audioDirectory.path)")
        PTLogger.general.info("Video directory: \(videoDirectory.path)")
        
        var totalSize: Int64 = 0
        
        // Check audio directory
        if fileManager.fileExists(atPath: audioDirectory.path) {
            guard let enumerator = fileManager.enumerator(at: audioDirectory, includingPropertiesForKeys: [.fileSizeKey]) else {
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
        if fileManager.fileExists(atPath: videoDirectory.path) {
            guard let enumerator = fileManager.enumerator(at: videoDirectory, includingPropertiesForKeys: [.fileSizeKey]) else {
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
        guard fileManager.fileExists(atPath: url.path) else {
            PTLogger.general.error("Downloaded file does not exist at path: \(url.path)")
            return false
        }
        
        // Check file size
        do {
            let attributes = try fileManager.attributesOfItem(atPath: url.path)
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
                        id: entity.id ?? "",
                        talkID: entity.talkID ?? "",
                        downloadURL: entity.downloadURL ?? "",
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
    
    private func saveResumeData(_ resumeData: Data, for talkID: String) async {
        try? await persistenceController.performBackgroundTask { context in
            let request: NSFetchRequest<DownloadTaskEntity> = DownloadTaskEntity.fetchRequest()
            request.predicate = NSPredicate(format: "talkID == %@", talkID)
            
            if let entity = try context.fetch(request).first {
                entity.resumeData = resumeData
            }
        }
    }
    
    nonisolated private func getAudioDirectory() -> URL {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let audioDirectory = documentsPath.appendingPathComponent("audio")
        
        PTLogger.general.info("📁 Audio directory path: \(audioDirectory.path)")
        
        // Create directory if it doesn't exist
        if !fileManager.fileExists(atPath: audioDirectory.path) {
            do {
                try fileManager.createDirectory(at: audioDirectory, withIntermediateDirectories: true, attributes: nil)
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
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let videoDirectory = documentsURL.appendingPathComponent("video")
        
        PTLogger.general.info("📁 Video directory path: \(videoDirectory.path)")
        
        // Create directory if it doesn't exist
        if !fileManager.fileExists(atPath: videoDirectory.path) {
            do {
                try fileManager.createDirectory(at: videoDirectory, withIntermediateDirectories: true, attributes: nil)
                PTLogger.general.info("📁 Created video directory successfully")
            } catch {
                PTLogger.general.error("📁 Failed to create video directory: \(error)")
            }
        } else {
            PTLogger.general.info("📁 Video directory already exists")
        }
        
        return videoDirectory
    }
    
    nonisolated private func moveDownloadedFile(from sourceURL: URL, to destinationURL: URL) throws {
        PTLogger.general.info("🚚 Moving file from \(sourceURL.path) to \(destinationURL.path)")
        
        // Check if source file exists
        guard fileManager.fileExists(atPath: sourceURL.path) else {
            PTLogger.general.error("🚨 Source file does not exist: \(sourceURL.path)")
            throw DownloadError.fileNotFound
        }
        
        // Create directory if needed
        let directory = destinationURL.deletingLastPathComponent()
        PTLogger.general.info("📁 Ensuring directory exists: \(directory.path)")
        
        if !fileManager.fileExists(atPath: directory.path) {
            do {
                try fileManager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
                PTLogger.general.info("📁 Created directory: \(directory.path)")
            } catch {
                PTLogger.general.error("📁 Failed to create directory: \(error)")
                throw error
            }
        } else {
            PTLogger.general.info("📁 Directory already exists: \(directory.path)")
        }
        
        // Remove existing file if it exists
        if fileManager.fileExists(atPath: destinationURL.path) {
            PTLogger.general.info("🗑️ Removing existing file: \(destinationURL.path)")
            try fileManager.removeItem(at: destinationURL)
        }
        
        // Try to move the file
        do {
            try fileManager.moveItem(at: sourceURL, to: destinationURL)
            PTLogger.general.info("✅ Successfully moved file to: \(destinationURL.path)")
            
            // Verify the file was actually moved
            if fileManager.fileExists(atPath: destinationURL.path) {
                let attributes = try fileManager.attributesOfItem(atPath: destinationURL.path)
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
                try fileManager.copyItem(at: sourceURL, to: destinationURL)
                PTLogger.general.info("✅ Successfully copied file to: \(destinationURL.path)")
                
                // Remove the original file after successful copy
                try? fileManager.removeItem(at: sourceURL)
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
        do {
            // Validate the downloaded file (no size expectation - just check it exists and is reasonable)
            guard validateDownloadedFile(at: localURL, expectedSize: nil) else {
                PTLogger.general.error("Downloaded file validation failed for talk: \(talkID)")
                
                // Remove invalid file
                try? fileManager.removeItem(at: localURL)
                
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
                        PTLogger.general.info("Updating talk entity: \(talkEntity.title ?? "Unknown") - setting isDownloaded=true, localAudioURL=\(localURL.path)")
                        talkEntity.isDownloaded = true
                        talkEntity.localAudioURL = localURL.path
                        talkEntity.lastAccessedAt = Date()
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
                        newTalkEntity.duration = 0 // Will be updated when played
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
            } catch {
                PTLogger.general.error("Failed to save Core Data changes for talk \(talkID): \(error)")
            }
            
            // Update UI state - mark as completed and clear progress
            if let index = activeDownloads.firstIndex(where: { $0.talkID == talkID }) {
                activeDownloads[index].status = .completed
                activeDownloads.remove(at: index)
            }
            
            // Clear progress to show checkmark instead of 100%
            downloadProgress.removeValue(forKey: talkID)
            
            PTLogger.general.info("Download completed and validated for talk: \(talkID)")
            
            // Post notification that download completed
            NotificationCenter.default.post(name: .downloadCompleted, object: nil, userInfo: ["talkID": talkID])
            
        } catch {
            PTLogger.general.error("Failed to handle download completion: \(error)")
            
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
    let totalBytes: Int64
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
}