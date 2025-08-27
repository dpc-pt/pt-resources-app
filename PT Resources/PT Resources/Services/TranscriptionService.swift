//
//  TranscriptionService.swift
//  PT Resources
//
//  Service for managing server-side Whisper transcription
//

import Foundation
import CoreData
import Combine

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
    }
    
    deinit {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }
    
    // MARK: - Public Methods
    
    func requestTranscription(for talk: Talk, priority: TranscriptionPriority = .normal) async throws {
        
        // Check if transcription already exists or is in progress
        if await hasTranscript(for: talk.id) {
            print("Transcript already exists for talk: \(talk.id)")
            return
        }
        
        if transcriptionQueue.contains(where: { $0.talkID == talk.id }) {
            print("Transcription already queued for talk: \(talk.id)")
            return
        }
        
        // Use mock service if configured
        if Config.useMockServices {
            return await mockRequestTranscription(for: talk, priority: priority)
        }
        
        // Create transcription request
        let request = CreateTranscriptionRequest(
            audioURL: talk.audioURL ?? "",
            talkID: talk.id,
            language: "en", // TODO: Make configurable
            priority: priority
        )
        
        guard let url = URL(string: Config.APIEndpoint.createTranscription(audioURL: talk.audioURL ?? "", talkID: talk.id).url) else {
            throw TranscriptionError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(Config.transcriptionAPIKey)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = try encoder.encode(request)
        
        do {
            let (data, response) = try await session.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw TranscriptionError.invalidResponse
            }
            
            guard httpResponse.statusCode == 201 || httpResponse.statusCode == 200 else {
                throw TranscriptionError.httpError(httpResponse.statusCode)
            }
            
            let transcriptionResponse = try decoder.decode(CreateTranscriptionResponse.self, from: data)
            
            // Add to queue
            let queueItem = TranscriptionQueueItem(
                talkID: talk.id,
                jobID: transcriptionResponse.jobID,
                priority: priority,
                status: transcriptionResponse.status
            )
            
            transcriptionQueue.append(queueItem)
            sortTranscriptionQueue()
            
            // Save to Core Data
            try await saveTranscriptionJob(jobID: transcriptionResponse.jobID, talkID: talk.id, status: transcriptionResponse.status)
            
            print("Transcription requested for talk: \(talk.title)")
            
        } catch {
            if error is TranscriptionError {
                throw error
            } else {
                throw TranscriptionError.networkError(error)
            }
        }
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
        }
    }
}