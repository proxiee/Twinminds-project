import SwiftData
import Foundation

// individual 30-second audio segment with its transcription
@Model
final class TranscriptionSegment {
    // MARK: - Properties
    @Attribute(.unique) var id: UUID
    var segmentIndex: Int
    var startTime: TimeInterval
    var duration: TimeInterval
    var fileURL: URL
    var transcription: String?
    var transcriptionMethod: String? // Store as string to avoid enum conflicts
    var retryCount: Int
    var processingStatus: String // Store as string to avoid enum conflicts
    var transcriptionStatus: String // Store as string to avoid enum conflicts
    var errorMessage: String?
    var createdAt: Date
    var updatedAt: Date
    
    // MARK: - Relationships
    var session: RecordingSession?
    
    // MARK: - Computed Properties
    // when this segment ends
    var endTime: TimeInterval {
        return startTime + duration
    }
    
    // just the filename for display
    var fileName: String {
        return fileURL.lastPathComponent
    }
    
    // MARK: - Initialization
    init(segmentIndex: Int, startTime: TimeInterval, duration: TimeInterval, fileURL: URL, session: RecordingSession) {
        self.id = UUID()
        self.segmentIndex = segmentIndex
        self.startTime = startTime
        self.duration = duration
        self.fileURL = fileURL
        self.transcription = nil
        self.transcriptionMethod = nil
        self.retryCount = 0
        self.processingStatus = ProcessingStatus.pending.rawValue
        self.transcriptionStatus = TranscriptionStatus.notStarted.rawValue
        self.errorMessage = nil
        self.createdAt = Date()
        self.updatedAt = Date()
        self.session = session
    }
    
    // MARK: - Methods
    // mark transcription as successful
    func markTranscriptionCompleted(_ transcription: String, method: TranscriptionMethod) {
        self.transcription = transcription
        self.transcriptionMethod = method.rawValue
        self.transcriptionStatus = TranscriptionStatus.completed.rawValue
        self.processingStatus = ProcessingStatus.completed.rawValue
        self.updatedAt = Date()
    }
    
    // mark transcription as failed
    func markTranscriptionFailed(_ error: String) {
        self.transcriptionStatus = TranscriptionStatus.failed.rawValue
        self.processingStatus = ProcessingStatus.failed.rawValue
        self.errorMessage = error
        self.retryCount += 1
        self.updatedAt = Date()
    }
    
    // reset for retry attempt
    func resetForRetry() {
        self.processingStatus = ProcessingStatus.pending.rawValue
        self.transcriptionStatus = TranscriptionStatus.notStarted.rawValue
        self.updatedAt = Date()
    }
}

// MARK: - Supporting Enums
// different states processing can be in
enum ProcessingStatus: String, Codable, CaseIterable {
    case pending = "pending"
    case processing = "processing"
    case completed = "completed"
    case failed = "failed"
    case queued = "queued"
    
    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .processing: return "Processing"
        case .completed: return "Completed"
        case .failed: return "Failed"
        case .queued: return "Queued"
        }
    }
} 