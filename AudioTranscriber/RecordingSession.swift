import SwiftData
import Foundation

@Model
final class RecordingSession {
    // MARK: - Properties
    @Attribute(.unique) var id: UUID
    var startDate: Date
    var endDate: Date?
    var baseFileName: String
    var totalDuration: TimeInterval
    var segmentCount: Int
    var isCompleted: Bool
    var combinedTranscription: String
    var recordingStatus: String // Store as string to avoid enum conflicts
    var transcriptionStatus: String // Store as string to avoid enum conflicts
    var createdAt: Date
    var updatedAt: Date
    
    // MARK: - Relationships
    @Relationship(deleteRule: .cascade)
    var segments: [TranscriptionSegment] = []
    
    // MARK: - Computed Properties
    var duration: TimeInterval {
        return endDate?.timeIntervalSince(startDate) ?? 0
    }
    
    var hasTranscriptions: Bool {
        return segments.contains { $0.transcriptionStatus == TranscriptionStatus.completed.rawValue }
    }
    
    var completedTranscriptionCount: Int {
        return segments.filter { $0.transcriptionStatus == TranscriptionStatus.completed.rawValue }.count
    }
    
    // MARK: - Initialization
    init(baseFileName: String) {
        self.id = UUID()
        self.startDate = Date()
        self.baseFileName = baseFileName
        self.totalDuration = 0
        self.segmentCount = 0
        self.isCompleted = false
        self.combinedTranscription = ""
        self.recordingStatus = RecordingStatus.recording.rawValue
        self.transcriptionStatus = TranscriptionStatus.notStarted.rawValue
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    // MARK: - Methods
    func updateCombinedTranscription() {
        combinedTranscription = segments
            .sorted(by: { $0.startTime < $1.startTime })
            .compactMap { $0.transcription }
            .joined(separator: " ")
        updatedAt = Date()
    }
    
    func markCompleted() {
        isCompleted = true
        endDate = Date()
        recordingStatus = RecordingStatus.completed.rawValue
        updatedAt = Date()
    }
}

// MARK: - Supporting Enums
enum RecordingStatus: String, Codable, CaseIterable {
    case recording = "recording"
    case paused = "paused"
    case completed = "completed"
    case failed = "failed"
    
    var displayName: String {
        switch self {
        case .recording: return "Recording"
        case .paused: return "Paused"
        case .completed: return "Completed"
        case .failed: return "Failed"
        }
    }
}

enum TranscriptionStatus: String, Codable, CaseIterable {
    case notStarted = "not_started"
    case inProgress = "in_progress"
    case completed = "completed"
    case failed = "failed"
    case skipped = "skipped"
    
    var displayName: String {
        switch self {
        case .notStarted: return "Not Started"
        case .inProgress: return "In Progress"
        case .completed: return "Completed"
        case .failed: return "Failed"
        case .skipped: return "Skipped"
        }
    }
} 