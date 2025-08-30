//
//  Transcription.swift
//  PT Resources
//
//  Models for transcription data and processing
//

import Foundation

/// Transcription segment with timestamp
public struct TranscriptSegment: Codable, Identifiable, Hashable {
    public let id: String
    public let startTime: TimeInterval
    public let endTime: TimeInterval
    public let text: String
    public let confidence: Double?
    
    public var duration: TimeInterval {
        endTime - startTime
    }
    
    public init(id: String, startTime: TimeInterval, endTime: TimeInterval, text: String, confidence: Double? = nil) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.text = text
        self.confidence = confidence
    }
    
    var formattedStartTime: String {
        let minutes = Int(startTime) / 60
        let seconds = Int(startTime) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case startTime = "start_time"
        case endTime = "end_time"
        case text
        case confidence
    }
}

/// Complete transcript for a talk
struct Transcript: Codable, Identifiable {
    let id: String
    let talkID: String
    let text: String
    let segments: [TranscriptSegment]
    let language: String
    let status: TranscriptionStatus
    let createdAt: Date
    let completedAt: Date?
    
    /// Get segment at specific time position
    func segment(at time: TimeInterval) -> TranscriptSegment? {
        return segments.first { segment in
            time >= segment.startTime && time <= segment.endTime
        }
    }
    
    /// Get all segments within a time range
    func segments(from startTime: TimeInterval, to endTime: TimeInterval) -> [TranscriptSegment] {
        return segments.filter { segment in
            segment.endTime >= startTime && segment.startTime <= endTime
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case talkID = "talk_id"
        case text
        case segments
        case language
        case status
        case createdAt = "created_at"
        case completedAt = "completed_at"
    }
}

/// Transcription job status
enum TranscriptionStatus: String, Codable, CaseIterable {
    case pending = "pending"
    case processing = "processing"
    case completed = "completed"
    case failed = "failed"
    case cancelled = "cancelled"
    
    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .processing: return "Processing"
        case .completed: return "Completed"
        case .failed: return "Failed"
        case .cancelled: return "Cancelled"
        }
    }
    
    var isComplete: Bool {
        return self == .completed
    }
    
    var isInProgress: Bool {
        return self == .pending || self == .processing
    }
    
    var isFailed: Bool {
        return self == .failed || self == .cancelled
    }
}

/// Transcription job creation request
struct CreateTranscriptionRequest: Codable {
    let audioURL: String
    let talkID: String
    let language: String
    let priority: TranscriptionPriority
    
    enum CodingKeys: String, CodingKey {
        case audioURL = "audio_url"
        case talkID = "talk_id"
        case language
        case priority
    }
}

/// Transcription job creation response
struct CreateTranscriptionResponse: Codable {
    let jobID: String
    let status: TranscriptionStatus
    let estimatedCompletionTime: Date?
    
    enum CodingKeys: String, CodingKey {
        case jobID = "job_id"
        case status
        case estimatedCompletionTime = "estimated_completion_time"
    }
}

/// Transcription job status response
struct TranscriptionJobStatus: Codable {
    let jobID: String
    let status: TranscriptionStatus
    let progress: Double?
    let result: Transcript?
    let error: String?
    let estimatedCompletionTime: Date?
    
    enum CodingKeys: String, CodingKey {
        case jobID = "job_id"
        case status
        case progress
        case result
        case error
        case estimatedCompletionTime = "estimated_completion_time"
    }
}

/// Transcription priority levels
enum TranscriptionPriority: String, Codable, CaseIterable {
    case low = "low"
    case normal = "normal"
    case high = "high"
    
    var displayName: String {
        switch self {
        case .low: return "Low"
        case .normal: return "Normal"
        case .high: return "High"
        }
    }
    
    var queuePosition: Int {
        switch self {
        case .high: return 0
        case .normal: return 1
        case .low: return 2
        }
    }
}

/// Local transcription queue item
struct TranscriptionQueueItem: Identifiable {
    let id = UUID()
    let talkID: String
    let jobID: String?
    let priority: TranscriptionPriority
    let status: TranscriptionStatus
    let createdAt: Date
    let progress: Double?
    
    init(talkID: String, jobID: String? = nil, priority: TranscriptionPriority = .normal, status: TranscriptionStatus = .pending, progress: Double? = nil) {
        self.talkID = talkID
        self.jobID = jobID
        self.priority = priority
        self.status = status
        self.createdAt = Date()
        self.progress = progress
    }
}

// MARK: - Mock Data

extension Transcript {
    static let mockTranscript = Transcript(
        id: "transcript-1",
        talkID: "mock-1",
        text: "Welcome to this study of John's Gospel. Today we're looking at the prologue, verses 1 through 18, where John introduces us to the Word who became flesh and dwelt among us.",
        segments: [
            TranscriptSegment(
                id: "seg-1",
                startTime: 0,
                endTime: 8.5,
                text: "Welcome to this study of John's Gospel.",
                confidence: 0.95
            ),
            TranscriptSegment(
                id: "seg-2",
                startTime: 8.5,
                endTime: 18.2,
                text: "Today we're looking at the prologue, verses 1 through 18,",
                confidence: 0.92
            ),
            TranscriptSegment(
                id: "seg-3",
                startTime: 18.2,
                endTime: 28.7,
                text: "where John introduces us to the Word who became flesh and dwelt among us.",
                confidence: 0.89
            )
        ],
        language: "en",
        status: .completed,
        createdAt: Date().addingTimeInterval(-3600), // 1 hour ago
        completedAt: Date().addingTimeInterval(-3300) // 55 minutes ago
    )
}