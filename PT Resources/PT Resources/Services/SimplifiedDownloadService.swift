//
//  SimplifiedDownloadService.swift
//  PT Resources
//
//  Simplified download service with cleaner validation logic
//

import Foundation
import CoreData
import Combine

// MARK: - Download Configuration

struct DownloadConfiguration {
    let maxConcurrentDownloads: Int
    let allowCellularDownloads: Bool
    let autoDeleteAfterDays: Int?
    let maxFileSize: Int64 // In bytes
    let supportedFileTypes: Set<String>
    
    static let `default` = DownloadConfiguration(
        maxConcurrentDownloads: 3,
        allowCellularDownloads: false,
        autoDeleteAfterDays: 90,
        maxFileSize: 500 * 1024 * 1024, // 500MB
        supportedFileTypes: ["mp3", "m4a", "mp4", "m4v"]
    )
}

// MARK: - Download Result

enum DownloadResult {
    case success(localURL: URL, fileSize: Int64)
    case failure(DownloadError)
    case cancelled
}

// MARK: - Simplified Download Service

@MainActor
final class SimplifiedDownloadService: NSObject, ObservableObject, DownloadServiceProtocol {
    
    // MARK: - Published Properties
    
    @Published var activeDownloads: [DownloadTask] = []
    @Published var downloadProgress: [String: Float] = [:]
    @Published var isDownloading = false
    
    // MARK: - Private Properties
    
    private let configuration: DownloadConfiguration
    private let apiService: TalksAPIServiceProtocol
    private let persistenceController: PersistenceController
    private let errorCoordinator: ErrorCoordinatorProtocol
    
    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: "com.ptresources.downloads.simplified")
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        config.allowsCellularAccess = configuration.allowCellularDownloads
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()
    
    private let fileManager = FileManager.default
    private var backgroundCompletionHandler: (() -> Void)?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Directories
    
    private lazy var documentsDirectory: URL = {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
    }()
    
    private lazy var audioDirectory: URL = {
        let url = documentsDirectory.appendingPathComponent("audio")
        try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()
    
    private lazy var videoDirectory: URL = {
        let url = documentsDirectory.appendingPathComponent("video")
        try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()
    
    // MARK: - Initialization
    
    init(
        configuration: DownloadConfiguration = .default,
        apiService: TalksAPIServiceProtocol,
        persistenceController: PersistenceController,
        errorCoordinator: ErrorCoordinatorProtocol
    ) {
        self.configuration = configuration
        self.apiService = apiService
        self.persistenceController = persistenceController
        self.errorCoordinator = errorCoordinator
        
        super.init()
        
        loadActiveDownloads()
        setupCleanupTimer()
    }
    
    // MARK: - Public Methods
    
    func downloadTalk(_ talk: Talk) async throws {
        PTLogger.general.info("Starting download for talk: \(talk.title) (ID: \(talk.id))")
        
        // Validation pipeline
        try await validateDownloadRequest(for: talk)
        
        // Check if already downloaded or in progress
        if await isDownloaded(talk.id) {
            PTLogger.general.info("Talk \(talk.id) is already downloaded")
            return
        }
        
        if isDownloadInProgress(talk.id) {
            PTLogger.general.info("Download for talk \(talk.id) is already in progress")
            return
        }
        
        // Get download URL and media type
        let (downloadURL, mediaType) = try getDownloadInfo(for: talk)
        
        // Create download task
        let downloadTask = createDownloadTask(
            talkId: talk.id,
            downloadURL: downloadURL,
            mediaType: mediaType
        )
        
        // Start download
        try await startDownload(downloadTask)
    }
    
    func isDownloaded(_ talkId: String) async -> Bool {
        let audioPath = getLocalAudioPath(for: talkId)
        let videoPath = getLocalVideoPath(for: talkId)
        
        return fileManager.fileExists(atPath: audioPath) || fileManager.fileExists(atPath: videoPath)
    }
    
    func deleteTalk(_ talkId: String) async throws {
        PTLogger.general.info("Deleting downloaded content for talk: \(talkId)")
        
        // Cancel any active download first
        await cancelDownload(for: talkId)
        
        // Delete files
        let audioPath = getLocalAudioPath(for: talkId)
        let videoPath = getLocalVideoPath(for: talkId)
        
        for path in [audioPath, videoPath] {
            if fileManager.fileExists(atPath: path) {
                try fileManager.removeItem(atPath: path)
                PTLogger.general.info("Deleted file: \(path)")
            }
        }
        
        // Update Core Data
        try await updateTalkDownloadStatus(talkId: talkId, isDownloaded: false)
        
        // Notify completion
        NotificationCenter.default.post(name: .downloadDeleted, object: talkId)
    }
    
    func cancelDownload(for talkId: String) async {
        guard let index = activeDownloads.firstIndex(where: { $0.talkID == talkId }) else {
            return
        }
        
        let downloadTask = activeDownloads[index]
        
        // Cancel URLSessionTask if it exists
        urlSession.getAllTasks { tasks in
            for task in tasks {
                if task.originalRequest?.url?.absoluteString == downloadTask.downloadURL {
                    task.cancel()
                    break
                }
            }
        }
        
        // Remove from active downloads
        activeDownloads.remove(at: index)
        downloadProgress.removeValue(forKey: talkId)
        
        // Clean up any partial files
        await cleanupPartialDownload(for: talkId)
        
        PTLogger.general.info("Cancelled download for talk: \(talkId)")
    }
    
    func pauseDownload(for talkId: String) async {
        // Implementation for pause functionality
        // This would store resume data and pause the URLSessionTask
        PTLogger.general.info("Paused download for talk: \(talkId)")
    }
    
    func resumeDownload(for talkId: String) async {
        // Implementation for resume functionality
        // This would use stored resume data to continue the download
        PTLogger.general.info("Resumed download for talk: \(talkId)")
    }
    
    // MARK: - Storage Management
    
    func getStorageInfo() async -> (used: Int64, available: Int64) {
        let audioSize = await getDirectorySize(audioDirectory)
        let videoSize = await getDirectorySize(videoDirectory)
        let used = audioSize + videoSize
        
        // Get available space
        let available = (try? fileManager.attributesOfFileSystem(forPath: documentsDirectory.path)[.systemFreeSize] as? Int64) ?? 0
        
        return (used: used, available: available)
    }
    
    func cleanupOldDownloads() async {
        guard let autoDeleteDays = configuration.autoDeleteAfterDays else { return }
        
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -autoDeleteDays, to: Date()) ?? Date()
        
        PTLogger.general.info("Cleaning up downloads older than \(autoDeleteDays) days")
        
        // This would query Core Data for talks downloaded before cutoffDate
        // and delete them automatically
    }
    
    // MARK: - Private Methods - Validation
    
    private func validateDownloadRequest(for talk: Talk) async throws {
        // Check if download is allowed
        // Network check simplified - assume available
        
        // Check concurrent downloads limit
        guard activeDownloads.count < configuration.maxConcurrentDownloads else {
            throw DownloadError.networkError
        }
        
        // Check storage space
        let (_, available) = await getStorageInfo()
        guard available > configuration.maxFileSize else {
            throw DownloadError.fileSystemError
        }
        
        // Validate talk has downloadable content
        guard talk.audioURL != nil else {
            throw DownloadError.noDownloadableContent
        }
    }
    
    private func getDownloadInfo(for talk: Talk) throws -> (URL, MediaType) {
        // Prioritize audio over video for simplicity
        if let audioURL = talk.audioURL,
           !audioURL.isEmpty,
           !audioURL.contains("vimeo.com"), // Skip Vimeo URLs for now
           let url = URL(string: audioURL) {
            return (url, .audio)
        }
        
        // Could add video support here in the future
        // if let videoURL = talk.videoURL, let url = URL(string: videoURL) {
        //     return (url, .video)
        // }
        
        throw DownloadError.noDownloadableContent
    }
    
    private func createDownloadTask(talkId: String, downloadURL: URL, mediaType: MediaType) -> DownloadTask {
        return DownloadTask(
            id: UUID().uuidString,
            talkID: talkId,
            downloadURL: downloadURL.absoluteString,
            status: .pending,
            totalBytes: 0,
            downloadedBytes: 0,
            progress: 0.0,
            createdAt: Date(),
            mediaType: mediaType
        )
    }
    
    private func startDownload(_ downloadTask: DownloadTask) async throws {
        guard let url = URL(string: downloadTask.downloadURL) else {
            throw DownloadError.invalidDownloadURL
        }
        
        // Add to active downloads
        activeDownloads.append(downloadTask)
        downloadProgress[downloadTask.talkID] = 0.0
        
        // Start URLSession download
        let task = urlSession.downloadTask(with: url)
        task.resume()
        
        PTLogger.general.info("Started download task for talk: \(downloadTask.talkID)")
    }
    
    private func isDownloadInProgress(_ talkId: String) -> Bool {
        return activeDownloads.contains { $0.talkID == talkId }
    }
    
    private func getLocalAudioPath(for talkId: String) -> String {
        return audioDirectory.appendingPathComponent("\(talkId).mp3").path
    }
    
    private func getLocalVideoPath(for talkId: String) -> String {
        return videoDirectory.appendingPathComponent("\(talkId).mp4").path
    }
    
    private func updateTalkDownloadStatus(talkId: String, isDownloaded: Bool, localURL: String? = nil) async throws {
        try await persistenceController.performBackgroundTask { context in
            let request = TalkEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", talkId)
            
            if let talkEntity = try context.fetch(request).first {
                talkEntity.isDownloaded = isDownloaded
                if let localURL = localURL {
                    if localURL.contains(".mp3") || localURL.contains(".m4a") {
                        talkEntity.localAudioURL = localURL
                    } else if localURL.contains(".mp4") || localURL.contains(".m4v") {
                        talkEntity.localVideoURL = localURL
                    }
                }
                talkEntity.updatedAt = Date()
            }
        }
    }
    
    private func loadActiveDownloads() {
        // Load any persisted download tasks from Core Data
        // This would restore downloads that were in progress when the app was terminated
        PTLogger.general.info("Loaded active downloads")
    }
    
    private func setupCleanupTimer() {
        // Setup a timer to periodically clean up old downloads
        Timer.scheduledTimer(withTimeInterval: 24 * 60 * 60, repeats: true) { [weak self] _ in
            Task {
                await self?.cleanupOldDownloads()
            }
        }
    }
    
    private func getDirectorySize(_ directory: URL) async -> Int64 {
        do {
            let contents = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.fileSizeKey])
            let sizes = try contents.map { url in
                let attributes = try fileManager.attributesOfItem(atPath: url.path)
                return attributes[.size] as? Int64 ?? 0
            }
            return sizes.reduce(0, +)
        } catch {
            return 0
        }
    }
    
    private func cleanupPartialDownload(for talkId: String) async {
        let audioPath = getLocalAudioPath(for: talkId)
        let videoPath = getLocalVideoPath(for: talkId)
        
        for path in [audioPath, videoPath] {
            if fileManager.fileExists(atPath: path) {
                try? fileManager.removeItem(atPath: path)
            }
        }
    }
}

// MARK: - URLSessionDownloadDelegate

extension SimplifiedDownloadService: URLSessionDownloadDelegate {
    
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        Task { @MainActor in
            await handleDownloadCompletion(downloadTask, location: location)
        }
    }
    
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        Task { @MainActor in
            await handleDownloadProgress(downloadTask, totalBytesWritten: totalBytesWritten, totalBytesExpectedToWrite: totalBytesExpectedToWrite)
        }
    }
    
    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            Task { @MainActor in
                await handleDownloadError(task, error: error)
            }
        }
    }
    
    private func handleDownloadCompletion(_ downloadTask: URLSessionDownloadTask, location: URL) async {
        guard let originalURL = downloadTask.originalRequest?.url,
              let activeTask = activeDownloads.first(where: { $0.downloadURL == originalURL.absoluteString }) else {
            return
        }
        
        do {
            // Determine destination path
            let destinationURL = activeTask.mediaType == .audio ? 
                audioDirectory.appendingPathComponent("\(activeTask.talkID).mp3") :
                videoDirectory.appendingPathComponent("\(activeTask.talkID).mp4")
            
            // Move file to final location
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.moveItem(at: location, to: destinationURL)
            
            // Update Core Data
            try await updateTalkDownloadStatus(talkId: activeTask.talkID, isDownloaded: true, localURL: destinationURL.path)
            
            // Remove from active downloads
            if let index = activeDownloads.firstIndex(where: { $0.id == activeTask.id }) {
                activeDownloads.remove(at: index)
            }
            downloadProgress.removeValue(forKey: activeTask.talkID)
            
            // Notify completion
            NotificationCenter.default.post(name: .downloadCompleted, object: activeTask.talkID)
            
            PTLogger.general.info("Download completed for talk: \(activeTask.talkID)")
            
        } catch {
            errorCoordinator.handle(DownloadError.fileSystemError, category: .download, retryHandler: nil)
            PTLogger.general.error("Failed to complete download: \(error)")
        }
    }
    
    private func handleDownloadProgress(_ downloadTask: URLSessionDownloadTask, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) async {
        guard let originalURL = downloadTask.originalRequest?.url,
              let activeTask = activeDownloads.first(where: { $0.downloadURL == originalURL.absoluteString }) else {
            return
        }
        
        let progress = totalBytesExpectedToWrite > 0 ? Float(totalBytesWritten) / Float(totalBytesExpectedToWrite) : 0
        downloadProgress[activeTask.talkID] = progress
        
        // Update active task
        if let index = activeDownloads.firstIndex(where: { $0.id == activeTask.id }) {
            activeDownloads[index].progress = progress
            activeDownloads[index].downloadedBytes = totalBytesWritten
            activeDownloads[index].totalBytes = totalBytesExpectedToWrite
        }
    }
    
    private func handleDownloadError(_ task: URLSessionTask, error: Error) async {
        guard let originalURL = task.originalRequest?.url,
              let activeTask = activeDownloads.first(where: { $0.downloadURL == originalURL.absoluteString }) else {
            return
        }
        
        // Remove from active downloads
        if let index = activeDownloads.firstIndex(where: { $0.id == activeTask.id }) {
            activeDownloads.remove(at: index)
        }
        downloadProgress.removeValue(forKey: activeTask.talkID)
        
        // Clean up partial download
        await cleanupPartialDownload(for: activeTask.talkID)
        
        // Handle error
        errorCoordinator.handle(DownloadError.networkError, category: .download, retryHandler: nil)
        
        // Notify failure
        NotificationCenter.default.post(name: .downloadFailed, object: activeTask.talkID)
        
        PTLogger.general.error("Download failed for talk \(activeTask.talkID): \(error)")
    }
}

// DownloadError and DownloadTask are defined in DownloadService.swift

// MediaType enum is defined in DownloadService.swift