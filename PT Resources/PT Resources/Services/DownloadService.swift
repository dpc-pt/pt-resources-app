//
//  DownloadService.swift
//  PT Resources
//
//  Service for downloading and managing offline talk files
//

import Foundation
import CoreData
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
        
        // Check if already downloaded
        if await isDownloaded(talk.id) {
            print("Talk \(talk.id) is already downloaded")
            return
        }
        
        // Check if download is already in progress
        if activeDownloads.contains(where: { $0.talkID == talk.id }) {
            print("Download for talk \(talk.id) is already in progress")
            return
        }
        
        // Get download URL from API
        let downloadResponse = try await apiService.getDownloadURL(for: talk.id)
        
        guard let downloadURL = URL(string: downloadResponse.downloadURL) else {
            throw DownloadError.invalidDownloadURL
        }
        
        // Create download task
        let downloadTask = DownloadTask(
            id: UUID().uuidString,
            talkID: talk.id,
            downloadURL: downloadResponse.downloadURL,
            status: .pending,
            totalBytes: downloadResponse.fileSize ?? 0
        )
        
        // Save to Core Data
        try await persistenceController.performBackgroundTask { context in
            let entity = DownloadTaskEntity(context: context)
            entity.id = downloadTask.id
            entity.talkID = downloadTask.talkID
            entity.downloadURL = downloadTask.downloadURL
            entity.status = downloadTask.status.rawValue
            entity.totalBytes = downloadTask.totalBytes
            entity.createdAt = Date()
        }
        
        // Start URLSession download
        let urlDownloadTask = urlSession.downloadTask(with: downloadURL)
        urlDownloadTask.resume()
        
        // Update active downloads
        activeDownloads.append(downloadTask)
        downloadProgress[talk.id] = 0.0
        
        print("Started download for talk: \(talk.title)")
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
        
        // Delete local file
        let localURL = getLocalAudioURL(for: talkID)
        if fileManager.fileExists(atPath: localURL.path) {
            try fileManager.removeItem(at: localURL)
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
        // First check if file exists locally
        let localURL = getLocalAudioURL(for: talkID)
        let fileExists = fileManager.fileExists(atPath: localURL.path)
        
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
            return entities.compactMap { entity in
                guard let id = entity.id,
                      let localPath = entity.localAudioURL,
                      FileManager.default.fileExists(atPath: localPath) else {
                    return nil
                }
                
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
        
        guard let enumerator = fileManager.enumerator(at: audioDirectory, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        
        var totalSize: Int64 = 0
        
        for case let fileURL as URL in enumerator {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey])
                totalSize += Int64(resourceValues.fileSize ?? 0)
            } catch {
                continue
            }
        }
        
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
    
    private func getAudioDirectory() -> URL {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let audioDirectory = documentsPath.appendingPathComponent("audio")
        
        // Create directory if it doesn't exist
        if !fileManager.fileExists(atPath: audioDirectory.path) {
            try? fileManager.createDirectory(at: audioDirectory, withIntermediateDirectories: true)
        }
        
        return audioDirectory
    }
    
    private func getLocalAudioURL(for talkID: String) -> URL {
        return getAudioDirectory().appendingPathComponent("\(talkID).mp3")
    }
    
    private func moveDownloadedFile(from sourceURL: URL, to destinationURL: URL) throws {
        
        // Create directory if needed
        let directory = destinationURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        
        // Remove existing file if it exists
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        
        // Move the downloaded file
        try fileManager.moveItem(at: sourceURL, to: destinationURL)
    }
}

// MARK: - URLSessionDownloadDelegate

extension DownloadService: URLSessionDownloadDelegate {
    
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        
        // Find matching download task
        guard let downloadURL = downloadTask.originalRequest?.url?.absoluteString else {
            return
        }
        
        Task { @MainActor in
            guard let talkID = activeDownloads.first(where: { $0.downloadURL == downloadURL })?.talkID else {
                return
            }
            
            let localURL = getLocalAudioURL(for: talkID)
            
            do {
                try moveDownloadedFile(from: location, to: localURL)
                
                // Update Core Data
                try? await persistenceController.performBackgroundTask { context in
                    // Update talk entity
                    let talkRequest: NSFetchRequest<TalkEntity> = TalkEntity.fetchRequest()
                    talkRequest.predicate = NSPredicate(format: "id == %@", talkID)
                    
                    if let talkEntity = try context.fetch(talkRequest).first {
                        talkEntity.isDownloaded = true
                        talkEntity.localAudioURL = localURL.path
                        talkEntity.lastAccessedAt = Date()
                    }
                    
                    // Update download task entity
                    let downloadRequest: NSFetchRequest<DownloadTaskEntity> = DownloadTaskEntity.fetchRequest()
                    downloadRequest.predicate = NSPredicate(format: "talkID == %@", talkID)
                    
                    if let entity = try context.fetch(downloadRequest).first {
                        entity.status = DownloadStatus.completed.rawValue
                        entity.completedAt = Date()
                        entity.progress = 1.0
                    }
                }
                
                // Update UI state
                if let index = activeDownloads.firstIndex(where: { $0.talkID == talkID }) {
                    activeDownloads[index].status = .completed
                    activeDownloads.remove(at: index)
                }
                
                downloadProgress.removeValue(forKey: talkID)
                
                print("Download completed for talk: \(talkID)")
            } catch {
                print("Failed to move downloaded file: \(error)")
                
                // Update error status
                if let index = activeDownloads.firstIndex(where: { $0.talkID == talkID }) {
                    activeDownloads[index].status = .failed
                }
            }
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
            
            print("Download failed for talk \(talkID): \(error.localizedDescription)")
            
            // Update error status
            if let index = activeDownloads.firstIndex(where: { $0.talkID == talkID }) {
                activeDownloads[index].status = .failed
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
    
    init(id: String, talkID: String, downloadURL: String, status: DownloadStatus = .pending, totalBytes: Int64 = 0, downloadedBytes: Int64 = 0, progress: Float = 0, createdAt: Date = Date()) {
        self.id = id
        self.talkID = talkID
        self.downloadURL = downloadURL
        self.status = status
        self.totalBytes = totalBytes
        self.downloadedBytes = downloadedBytes
        self.progress = progress
        self.createdAt = createdAt
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

enum DownloadError: LocalizedError {
    case invalidDownloadURL
    case downloadTaskNotFound
    case fileSystemError
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .invalidDownloadURL: return "Invalid download URL"
        case .downloadTaskNotFound: return "Download task not found"
        case .fileSystemError: return "File system error"
        case .networkError: return "Network error"
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