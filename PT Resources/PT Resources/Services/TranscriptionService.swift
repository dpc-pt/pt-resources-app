//
//  TranscriptionService.swift
//  PT Resources
//
//  Service for managing server-side Whisper transcription
//

import Foundation
import CoreData
import Combine
import WhisperKit

extension Notification.Name {
    static let transcriptionCompleted = Notification.Name("transcriptionCompleted")
    static let transcriptionProgress = Notification.Name("transcriptionProgress")
    static let transcriptionSegmentAdded = Notification.Name("transcriptionSegmentAdded")
}

// Streaming transcript model for real-time updates
public struct StreamingTranscript {
    let talkID: String
    var segments: [TranscriptSegment]
    var currentText: String
    var progress: Float
    var isCompleted: Bool
    
    public init(talkID: String) {
        self.talkID = talkID
        self.segments = []
        self.currentText = ""
        self.progress = 0.0
        self.isCompleted = false
    }
    
    public mutating func addSegment(_ segment: TranscriptSegment) {
        segments.append(segment)
        currentText = segments.map { $0.text }.joined(separator: " ")
    }
    
    public mutating func updateProgress(_ newProgress: Float) {
        progress = newProgress
    }
    
    public mutating func complete() {
        isCompleted = true
        progress = 1.0
    }
}

@MainActor
final class TranscriptionService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var transcriptionQueue: [TranscriptionQueueItem] = []
    @Published var isProcessing = false
    
    // MARK: - Private Properties
    
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let persistenceController: PersistenceController
    
    private var pollingTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    private var whisperKit: WhisperKit?
    private let fileManager = FileManager.default
    private var isInitializingWhisperKit = false
    
    // Streaming transcription state
    @Published var streamingTranscripts: [String: StreamingTranscript] = [:]
    
    // MARK: - Initialization
    
    init(session: URLSession = .shared, persistenceController: PersistenceController = .shared) {
        self.session = session
        self.persistenceController = persistenceController
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
        
        // Configure date handling
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        decoder.dateDecodingStrategy = .formatted(formatter)
        encoder.dateEncodingStrategy = .formatted(formatter)
        
        loadTranscriptionQueue()
        startPolling()
        
        // Initialize WhisperKit asynchronously
        Task {
            await initializeWhisperKit()
        }
    }
    
    deinit {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }
    
    // MARK: - Public Methods
    
    func transcribeLocalAudio(for talk: Talk, priority: TranscriptionPriority = .normal) async throws {
        // Check if transcription already exists
        if await hasTranscript(for: talk.id) {
            print("Transcript already exists for talk: \(talk.id)")
            return
        }
        
        // Check if already in progress
        if transcriptionQueue.contains(where: { $0.talkID == talk.id }) {
            print("Transcription already queued for talk: \(talk.id)")
            return
        }
        
        // Get local audio file path
        let audioURL = getLocalAudioURL(for: talk.id)
        guard fileManager.fileExists(atPath: audioURL.path) else {
            throw TranscriptionError.audioFileNotFound
        }
        
        // Add to queue as processing
        let queueItem = TranscriptionQueueItem(
            talkID: talk.id,
            jobID: "local-\(UUID().uuidString)",
            priority: priority,
            status: .processing
        )
        
        transcriptionQueue.append(queueItem)
        sortTranscriptionQueue()
        
        // Save to Core Data
        try await saveTranscriptionJob(jobID: queueItem.jobID!, talkID: talk.id, status: .processing)
        
        print("Starting local transcription for talk: \(talk.title)")
        
        // Perform transcription in background task
        Task.detached { [weak self] in
            await self?.performLocalTranscription(for: talk, audioURL: audioURL, queueItem: queueItem)
        }
    }
    
    func requestTranscription(for talk: Talk, priority: TranscriptionPriority = .normal) async throws {
        // Redirect to local transcription - this is now the only supported method
        try await transcribeLocalAudio(for: talk, priority: priority)
    }
    
    func cancelTranscription(for talkID: String) async throws {
        
        // Remove from queue
        if let index = transcriptionQueue.firstIndex(where: { $0.talkID == talkID }) {
            let item = transcriptionQueue[index]
            transcriptionQueue.remove(at: index)
            
            // Cancel on server if job ID exists
            if let jobID = item.jobID, !Config.useMockServices {
                try await cancelTranscriptionJob(jobID: jobID)
            }
        }
        
        // Update Core Data
        try await persistenceController.performBackgroundTask { context in
            let request: NSFetchRequest<TranscriptEntity> = TranscriptEntity.fetchRequest()
            request.predicate = NSPredicate(format: "talkID == %@", talkID)
            
            if let entity = try context.fetch(request).first {
                entity.status = TranscriptionStatus.cancelled.rawValue
            }
        }
        
        print("Transcription cancelled for talk: \(talkID)")
    }
    
    func getTranscript(for talkID: String) async throws -> Transcript? {
        
        return try await persistenceController.performBackgroundTask { context in
            let request: NSFetchRequest<TranscriptEntity> = TranscriptEntity.fetchRequest()
            request.predicate = NSPredicate(format: "talkID == %@ AND status == %@", talkID, TranscriptionStatus.completed.rawValue)
            
            guard let entity = try context.fetch(request).first else {
                return nil
            }
            
            let segments: [TranscriptSegment]
            if let segmentsData = entity.segments {
                segments = (try? JSONDecoder().decode([TranscriptSegment].self, from: segmentsData)) ?? []
            } else {
                segments = []
            }
            
            return Transcript(
                id: entity.id ?? "",
                talkID: entity.talkID ?? "",
                text: entity.text ?? "",
                segments: segments,
                language: entity.language ?? "en",
                status: TranscriptionStatus(rawValue: entity.status ?? "") ?? .pending,
                createdAt: entity.createdAt ?? Date(),
                completedAt: entity.completedAt
            )
        }
    }
    
    func hasTranscript(for talkID: String) async -> Bool {
        do {
            let transcript = try await getTranscript(for: talkID)
            return transcript != nil
        } catch {
            return false
        }
    }
    
    func getTranscriptionStatus(for talkID: String) -> TranscriptionStatus? {
        if let queueItem = transcriptionQueue.first(where: { $0.talkID == talkID }) {
            return queueItem.status
        }
        
        // Check Core Data for completed transcriptions
        // This would need to be async, but for now return nil
        return nil
    }
    
    func clearCompletedTranscriptions() {
        transcriptionQueue.removeAll { $0.status == .completed || $0.status == .failed || $0.status == .cancelled }
    }
    
    // MARK: - Private Methods
    
    private func loadTranscriptionQueue() {
        Task {
            let items = try await persistenceController.performBackgroundTask { context in
                let request: NSFetchRequest<TranscriptEntity> = TranscriptEntity.fetchRequest()
                request.predicate = NSPredicate(format: "status IN %@", [
                    TranscriptionStatus.pending.rawValue,
                    TranscriptionStatus.processing.rawValue
                ])
                
                let entities = try context.fetch(request)
                return entities.compactMap { entity -> TranscriptionQueueItem? in
                    guard let talkID = entity.talkID,
                          let statusString = entity.status,
                          let status = TranscriptionStatus(rawValue: statusString) else {
                        return nil
                    }
                    
                    return TranscriptionQueueItem(
                        talkID: talkID,
                        jobID: entity.jobID,
                        priority: .normal, // Default priority for existing items
                        status: status
                    )
                }
            }
            
            await MainActor.run {
                self.transcriptionQueue = items
                self.sortTranscriptionQueue()
            }
        }
    }
    
    private func sortTranscriptionQueue() {
        transcriptionQueue.sort { item1, item2 in
            // First by priority
            if item1.priority.queuePosition != item2.priority.queuePosition {
                return item1.priority.queuePosition < item2.priority.queuePosition
            }
            // Then by creation date
            return item1.createdAt < item2.createdAt
        }
    }
    
    private func startPolling() {
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task {
                await self?.pollTranscriptionStatus()
            }
        }
    }
    
    private func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }
    
    private func pollTranscriptionStatus() async {
        
        guard !transcriptionQueue.isEmpty else { return }
        
        isProcessing = true
        defer { isProcessing = false }
        
        let inProgressItems = transcriptionQueue.filter { $0.status.isInProgress }
        
        for item in inProgressItems {
            guard let jobID = item.jobID else { continue }
            
            // Skip polling for local transcriptions (they handle their own completion)
            if jobID.hasPrefix("local-") {
                continue
            }
            
            do {
                if Config.useMockServices {
                    await mockPollTranscriptionStatus(item: item)
                } else {
                    try await checkTranscriptionStatus(jobID: jobID, talkID: item.talkID)
                }
            } catch {
                print("Failed to poll transcription status for job \(jobID): \(error)")
            }
        }
    }
    
    private func checkTranscriptionStatus(jobID: String, talkID: String) async throws {
        
        let endpoint = Config.APIEndpoint.transcriptionStatus(jobID: jobID)
        guard let url = URL(string: endpoint.url) else {
            throw TranscriptionError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(Config.transcriptionAPIKey)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranscriptionError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw TranscriptionError.httpError(httpResponse.statusCode)
        }
        
        let statusResponse = try decoder.decode(TranscriptionJobStatus.self, from: data)
        
        // Update queue item
        if let index = transcriptionQueue.firstIndex(where: { $0.jobID == jobID }) {
            transcriptionQueue[index] = TranscriptionQueueItem(
                talkID: talkID,
                jobID: jobID,
                priority: transcriptionQueue[index].priority,
                status: statusResponse.status,
                progress: statusResponse.progress
            )
        }
        
        // Handle completion
        if statusResponse.status == .completed, let transcript = statusResponse.result {
            try await saveCompletedTranscript(transcript)
            
            // Remove from queue
            if let index = transcriptionQueue.firstIndex(where: { $0.jobID == jobID }) {
                transcriptionQueue.remove(at: index)
            }
        } else if statusResponse.status.isFailed {
            // Remove failed jobs from queue
            if let index = transcriptionQueue.firstIndex(where: { $0.jobID == jobID }) {
                transcriptionQueue.remove(at: index)
            }
        }
        
        // Update Core Data status
        try await updateTranscriptionStatus(jobID: jobID, status: statusResponse.status)
    }
    
    private func saveTranscriptionJob(jobID: String, talkID: String, status: TranscriptionStatus) async throws {
        try await persistenceController.performBackgroundTask { context in
            let entity = TranscriptEntity(context: context)
            entity.id = UUID().uuidString
            entity.jobID = jobID
            entity.talkID = talkID
            entity.status = status.rawValue
            entity.createdAt = Date()
        }
    }
    
    private func updateTranscriptionStatus(jobID: String, status: TranscriptionStatus) async throws {
        try await persistenceController.performBackgroundTask { context in
            let request: NSFetchRequest<TranscriptEntity> = TranscriptEntity.fetchRequest()
            request.predicate = NSPredicate(format: "jobID == %@", jobID)
            
            if let entity = try context.fetch(request).first {
                entity.status = status.rawValue
                if status == .completed {
                    entity.completedAt = Date()
                }
            }
        }
    }
    
    private func saveCompletedTranscript(_ transcript: Transcript) async throws {
        try await persistenceController.performBackgroundTask { context in
            let request: NSFetchRequest<TranscriptEntity> = TranscriptEntity.fetchRequest()
            request.predicate = NSPredicate(format: "talkID == %@", transcript.talkID)
            
            let entity = try context.fetch(request).first ?? TranscriptEntity(context: context)
            
            entity.id = transcript.id
            entity.talkID = transcript.talkID
            entity.text = transcript.text
            entity.language = transcript.language
            entity.status = transcript.status.rawValue
            entity.createdAt = transcript.createdAt
            entity.completedAt = transcript.completedAt
            
            // Encode segments as JSON
            if let segmentsData = try? JSONEncoder().encode(transcript.segments) {
                entity.segments = segmentsData
            }
        }
    }
    
    private func cancelTranscriptionJob(jobID: String) async throws {
        // TODO: Implement server-side job cancellation
        // This would typically be a DELETE or POST request to cancel the job
        print("Cancelling transcription job: \(jobID)")
    }
    
    private func initializeWhisperKit() async {
        guard !isInitializingWhisperKit && whisperKit == nil else { return }
        
        isInitializingWhisperKit = true
        defer { isInitializingWhisperKit = false }
        
        do {
            print("Initializing WhisperKit...")
            whisperKit = try await WhisperKit()
            print("WhisperKit initialized successfully")
        } catch {
            print("Failed to initialize WhisperKit: \(error)")
        }
    }
    
    private func ensureWhisperKitReady() async -> Bool {
        // If WhisperKit is already initialized, return immediately
        if whisperKit != nil {
            print("WhisperKit already initialized, proceeding...")
            return true
        }
        
        // If already initializing, wait for it to complete
        if isInitializingWhisperKit {
            print("WhisperKit is initializing, waiting...")
            // Wait for initialization to complete (max 30 seconds)
            for i in 0..<60 {
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                if whisperKit != nil {
                    print("WhisperKit initialization completed after waiting")
                    return true
                }
                if !isInitializingWhisperKit {
                    print("WhisperKit initialization failed during wait")
                    break
                }
                if i % 10 == 0 && i > 0 {
                    print("Still waiting for WhisperKit initialization... (\(i/2) seconds)")
                }
            }
            return whisperKit != nil
        }
        
        // Otherwise, initialize now
        print("Starting WhisperKit initialization...")
        await initializeWhisperKit()
        let success = whisperKit != nil
        print("WhisperKit initialization result: \(success ? "success" : "failed")")
        return success
    }
    
    private func getLocalAudioURL(for talkID: String) -> URL {
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let audioDirectory = documentsURL.appendingPathComponent("audio")
        return audioDirectory.appendingPathComponent("\(talkID).mp3")
    }
    
    private func performLocalTranscription(for talk: Talk, audioURL: URL, queueItem: TranscriptionQueueItem) async {
        // Ensure WhisperKit is ready before proceeding
        let isReady = await ensureWhisperKitReady()
        guard isReady, let whisperKit = whisperKit else {
            print("WhisperKit failed to initialize or is not available")
            await handleTranscriptionFailure(for: queueItem)
            return
        }
        
        do {
            print("Starting streaming transcription for: \(audioURL.path)")
            
            // Initialize streaming transcript
            await MainActor.run {
                streamingTranscripts[talk.id] = StreamingTranscript(talkID: talk.id)
            }
            
            // Update queue status
            await MainActor.run {
                if let index = transcriptionQueue.firstIndex(where: { $0.talkID == queueItem.talkID }) {
                    transcriptionQueue[index] = TranscriptionQueueItem(
                        talkID: queueItem.talkID,
                        jobID: queueItem.jobID,
                        priority: queueItem.priority,
                        status: .processing,
                        progress: 0.1
                    )
                }
            }
            
            // Start progress simulation in background
            Task.detached { [weak self] in
                for progress in stride(from: 0.1, through: 0.9, by: 0.1) {
                    try? await Task.sleep(nanoseconds: UInt64(2 * 1_000_000_000)) // 2 seconds
                    
                    await MainActor.run {
                        guard let self = self else { return }
                        
                        // Update progress
                        self.streamingTranscripts[talk.id]?.updateProgress(Float(progress))
                        
                        // Update queue progress
                        if let index = self.transcriptionQueue.firstIndex(where: { $0.talkID == queueItem.talkID }) {
                            self.transcriptionQueue[index] = TranscriptionQueueItem(
                                talkID: queueItem.talkID,
                                jobID: queueItem.jobID,
                                priority: queueItem.priority,
                                status: .processing,
                                progress: Double(progress)
                            )
                        }
                        
                        // Notify UI of progress
                        NotificationCenter.default.post(
                            name: .transcriptionProgress,
                            object: nil,
                            userInfo: ["talkID": talk.id, "progress": Float(progress)]
                        )
                    }
                }
            }
            
            // Perform actual transcription
            let results = try await whisperKit.transcribe(audioPath: audioURL.path)
            
            guard let firstResult = results.first else {
                throw TranscriptionError.transcriptionFailed
            }
            
            // Simulate streaming segments by adding them one by one with delays
            for (index, segment) in firstResult.segments.enumerated() {
                let transcriptSegment = TranscriptSegment(
                    id: UUID().uuidString,
                    startTime: TimeInterval(segment.start),
                    endTime: TimeInterval(segment.end),
                    text: cleanTranscriptText(segment.text),
                    confidence: 0.95
                )
                
                // Add segment to streaming transcript
                await MainActor.run {
                    streamingTranscripts[talk.id]?.addSegment(transcriptSegment)
                    
                    // Notify UI of new segment
                    NotificationCenter.default.post(
                        name: .transcriptionSegmentAdded,
                        object: nil,
                        userInfo: [
                            "talkID": talk.id,
                            "segment": transcriptSegment,
                            "streamingTranscript": streamingTranscripts[talk.id] as Any
                        ]
                    )
                }
                
                print("Added segment \(index + 1)/\(firstResult.segments.count): \(transcriptSegment.text)")
                
                // Add small delay to simulate streaming (but not too slow)
                if index < firstResult.segments.count - 1 {
                    try? await Task.sleep(nanoseconds: UInt64(0.5 * 1_000_000_000)) // 0.5 seconds
                }
            }
            
            // Create final transcript from result
            let segments = firstResult.segments.map { segment in
                TranscriptSegment(
                    id: UUID().uuidString,
                    startTime: TimeInterval(segment.start),
                    endTime: TimeInterval(segment.end),
                    text: cleanTranscriptText(segment.text),
                    confidence: 0.95
                )
            }
            
            let transcript = Transcript(
                id: "local-transcript-\(talk.id)",
                talkID: talk.id,
                text: cleanTranscriptText(firstResult.text),
                segments: segments,
                language: "en",
                status: .completed,
                createdAt: Date(),
                completedAt: Date()
            )
            
            // Complete streaming transcript
            await MainActor.run {
                streamingTranscripts[talk.id]?.complete()
            }
            
            // Save completed transcript
            try await saveCompletedTranscript(transcript)
            
            // Remove from queue
            await MainActor.run {
                if let index = transcriptionQueue.firstIndex(where: { $0.talkID == queueItem.talkID }) {
                    transcriptionQueue.remove(at: index)
                }
            }
            
            // Notify UI that transcription completed
            await MainActor.run {
                NotificationCenter.default.post(
                    name: .transcriptionCompleted,
                    object: nil,
                    userInfo: ["talkID": talk.id, "transcript": transcript]
                )
                
                // Clean up streaming state
                streamingTranscripts.removeValue(forKey: talk.id)
            }
            
            print("Streaming transcription completed for talk: \(talk.title)")
            
        } catch {
            print("Streaming transcription failed for talk \(talk.title): \(error)")
            await MainActor.run {
                streamingTranscripts.removeValue(forKey: talk.id)
            }
            await handleTranscriptionFailure(for: queueItem)
        }
    }
    
    private func handleTranscriptionFailure(for queueItem: TranscriptionQueueItem) async {
        await MainActor.run {
            if let index = transcriptionQueue.firstIndex(where: { $0.talkID == queueItem.talkID }) {
                transcriptionQueue[index] = TranscriptionQueueItem(
                    talkID: queueItem.talkID,
                    jobID: queueItem.jobID,
                    priority: queueItem.priority,
                    status: .failed
                )
            }
        }
        
        // Update Core Data
        do {
            try await updateTranscriptionStatus(jobID: queueItem.jobID!, status: .failed)
        } catch {
            print("Failed to update transcription status in Core Data: \(error)")
        }
    }
}

// MARK: - Mock Implementation

extension TranscriptionService {
    
    private func mockRequestTranscription(for talk: Talk, priority: TranscriptionPriority) async {
        let jobID = "mock-job-\(UUID().uuidString.prefix(8))"
        
        let queueItem = TranscriptionQueueItem(
            talkID: talk.id,
            jobID: jobID,
            priority: priority,
            status: .pending
        )
        
        transcriptionQueue.append(queueItem)
        sortTranscriptionQueue()
        
        // Save mock job to Core Data
        try? await saveTranscriptionJob(jobID: jobID, talkID: talk.id, status: .pending)
        
        print("Mock transcription requested for talk: \(talk.title)")
    }
    
    private func mockPollTranscriptionStatus(item: TranscriptionQueueItem) async {
        
        // Simulate transcription progress
        let mockProgress: Double = Double.random(in: 0.1...1.0)
        
        if mockProgress > 0.9 {
            // Complete the transcription
            let mockTranscript = Transcript(
                id: "transcript-\(item.talkID)",
                talkID: item.talkID,
                text: "This is a mock transcript for the talk. In a real implementation, this would contain the actual transcribed text with proper timestamps and segments.",
                segments: [
                    TranscriptSegment(
                        id: "seg-1",
                        startTime: 0,
                        endTime: 10,
                        text: "This is a mock transcript for the talk.",
                        confidence: 0.95
                    ),
                    TranscriptSegment(
                        id: "seg-2",
                        startTime: 10,
                        endTime: 20,
                        text: "In a real implementation, this would contain actual transcribed text.",
                        confidence: 0.92
                    )
                ],
                language: "en",
                status: .completed,
                createdAt: item.createdAt,
                completedAt: Date()
            )
            
            try? await saveCompletedTranscript(mockTranscript)
            
            // Remove from queue
            if let index = transcriptionQueue.firstIndex(where: { $0.talkID == item.talkID }) {
                transcriptionQueue.remove(at: index)
            }
            
            print("Mock transcription completed for talk: \(item.talkID)")
            
        } else {
            // Update progress
            if let index = transcriptionQueue.firstIndex(where: { $0.talkID == item.talkID }) {
                transcriptionQueue[index] = TranscriptionQueueItem(
                    talkID: item.talkID,
                    jobID: item.jobID,
                    priority: item.priority,
                    status: .processing,
                    progress: mockProgress
                )
            }
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func cleanTranscriptText(_ text: String) -> String {
        var cleanedText = text
        
        // Remove WhisperKit time tags and control markers like <|startoftranscript|>, <|en|>, <|transcribe|>, <|0.00|>
        cleanedText = cleanedText.replacingOccurrences(of: #"<\|[^|]*\|>"#, with: "", options: .regularExpression)
        
        // Remove any remaining angle bracket tags
        cleanedText = cleanedText.replacingOccurrences(of: #"<[^>]*>"#, with: "", options: .regularExpression)
        
        // Clean up multiple spaces and trim
        cleanedText = cleanedText.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        cleanedText = cleanedText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return cleanedText
    }
}

// MARK: - Error Types

enum TranscriptionError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case networkError(Error)
    case jobNotFound
    case rateLimited
    case quotaExceeded
    case unsupportedLanguage
    case audioFileNotFound
    case transcriptionFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid transcription service URL"
        case .invalidResponse:
            return "Invalid response from transcription service"
        case .httpError(let code):
            switch code {
            case 404:
                return "Transcription job not found"
            case 429:
                return "Rate limited - please try again later"
            case 402:
                return "Transcription quota exceeded"
            case 400:
                return "Invalid transcription request"
            default:
                return "Transcription service error: \(code)"
            }
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .jobNotFound:
            return "Transcription job not found"
        case .rateLimited:
            return "Transcription service rate limited"
        case .quotaExceeded:
            return "Transcription quota exceeded"
        case .unsupportedLanguage:
            return "Unsupported language for transcription"
        case .audioFileNotFound:
            return "Local audio file not found for transcription"
        case .transcriptionFailed:
            return "WhisperKit transcription failed"
        }
    }
}