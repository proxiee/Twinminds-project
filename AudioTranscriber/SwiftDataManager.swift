import SwiftData
import Foundation

// manages all the database stuff - sessions, segments, transcriptions
@MainActor
class SwiftDataManager: ObservableObject {
    static let shared = SwiftDataManager()
    
    private let logger = DebugLogger.shared
    private var _modelContainer: ModelContainer?
    
    @Published var sessions: [RecordingSession] = []
    @Published var isLoading = false
    
    // Public access to model container for app configuration
    var modelContainer: ModelContainer? {
        return _modelContainer
    }
    
    private init() {
        setupModelContainer()
    }
    
    // MARK: - Setup
    // set up the database with our models
    private func setupModelContainer() {
        do {
            let schema = Schema([
                RecordingSession.self,
                TranscriptionSegment.self
            ])
            
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true
            )
            
            _modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
            
            logger.logSuccess("SwiftData model container initialized successfully")
        } catch {
            logger.logError("Failed to initialize SwiftData model container", error: error)
        }
    }
    
    // MARK: - Context Management
    private var modelContext: ModelContext? {
        guard let modelContainer = _modelContainer else { return nil }
        return ModelContext(modelContainer)
    }
    
    // MARK: - Session Management
    // create a new recording session
    func createSession(baseFileName: String) -> RecordingSession? {
        guard let context = modelContext else {
            logger.logError("Model context not available")
            return nil
        }
        
        let session = RecordingSession(baseFileName: baseFileName)
        context.insert(session)
        
        do {
            try context.save()
            logger.logSuccess("Created new recording session: \(baseFileName)")
            return session
        } catch {
            logger.logError("Failed to save new session", error: error)
            return nil
        }
    }
    
    // add a segment to an existing session
    func addSegment(to session: RecordingSession, segmentIndex: Int, startTime: TimeInterval, duration: TimeInterval, fileURL: URL) -> TranscriptionSegment? {
        guard let context = modelContext else {
            logger.logError("Model context not available")
            return nil
        }
        
        let segment = TranscriptionSegment(
            segmentIndex: segmentIndex,
            startTime: startTime,
            duration: duration,
            fileURL: fileURL,
            session: session
        )
        
        context.insert(segment)
        session.segments.append(segment)
        session.segmentCount = session.segments.count
        session.totalDuration = session.segments.last?.endTime ?? 0
        session.updatedAt = Date()
        
        do {
            try context.save()
            logger.logSuccess("Added segment \(segmentIndex) to session \(session.baseFileName)")
            return segment
        } catch {
            logger.logError("Failed to save segment", error: error)
            return nil
        }
    }
    
    // mark a session as done
    func markSessionCompleted(_ session: RecordingSession) {
        guard let context = modelContext else { return }
        
        session.markCompleted()
        
        do {
            try context.save()
            logger.logSuccess("Marked session as completed: \(session.baseFileName)")
        } catch {
            logger.logError("Failed to mark session as completed", error: error)
        }
    }
    
    // update transcription for a segment
    func updateSegmentTranscription(_ segment: TranscriptionSegment, transcription: String, method: TranscriptionMethod) {
        guard let context = modelContext else { return }
        
        segment.markTranscriptionCompleted(transcription, method: method)
        segment.session?.updateCombinedTranscription()
        
        do {
            try context.save()
            logger.logSuccess("Updated transcription for segment \(segment.segmentIndex)")
        } catch {
            logger.logError("Failed to update segment transcription", error: error)
        }
    }
    
    // mark transcription as failed
    func markSegmentTranscriptionFailed(_ segment: TranscriptionSegment, error: String) {
        guard let context = modelContext else { return }
        
        segment.markTranscriptionFailed(error)
        
        do {
            try context.save()
            logger.logWarning("Marked segment \(segment.segmentIndex) transcription as failed: \(error)")
        } catch {
            logger.logError("Failed to mark segment transcription as failed", error: error)
        }
    }
    
    // MARK: - Query Methods
    // get all sessions
    func fetchSessions(limit: Int = 100) -> [RecordingSession] {
        guard let context = modelContext else { return [] }
        
        do {
            var descriptor = FetchDescriptor<RecordingSession>(
                sortBy: [SortDescriptor(\.startDate, order: .reverse)]
            )
            descriptor.fetchLimit = limit
            
            let sessions = try context.fetch(descriptor)
            logger.logInfo("Fetched \(sessions.count) recording sessions")
            return sessions
        } catch {
            logger.logError("Failed to fetch sessions", error: error)
            return []
        }
    }
    
    // get recent sessions for the widget
    func fetchRecentSessions(limit: Int = 10) -> [RecordingSession] {
        guard let context = modelContext else { return [] }
        
        do {
            var descriptor = FetchDescriptor<RecordingSession>(
                sortBy: [SortDescriptor(\.startDate, order: .reverse)]
            )
            descriptor.fetchLimit = limit
            
            let sessions = try context.fetch(descriptor)
            return sessions
        } catch {
            logger.logError("Failed to fetch recent sessions", error: error)
            return []
        }
    }
    
    // get a specific session by ID
    func fetchSession(by id: UUID) -> RecordingSession? {
        guard let context = modelContext else { return nil }
        
        do {
            let descriptor = FetchDescriptor<RecordingSession>(
                predicate: #Predicate<RecordingSession> { session in
                    session.id == id
                }
            )
            
            let sessions = try context.fetch(descriptor)
            return sessions.first
        } catch {
            logger.logError("Failed to fetch session by ID", error: error)
            return nil
        }
    }
    
    // get segments that still need transcription
    func fetchPendingTranscriptions() -> [TranscriptionSegment] {
        guard let context = modelContext else { return [] }
        
        do {
            let descriptor = FetchDescriptor<TranscriptionSegment>(
                predicate: #Predicate<TranscriptionSegment> { segment in
                    segment.transcriptionStatus == "not_started" || segment.transcriptionStatus == "failed"
                },
                sortBy: [SortDescriptor(\.createdAt, order: .forward)]
            )
            
            let segments = try context.fetch(descriptor)
            logger.logInfo("Fetched \(segments.count) pending transcription segments")
            return segments
        } catch {
            logger.logError("Failed to fetch pending transcriptions", error: error)
            return []
        }
    }
    
    // MARK: - Offline Queuing & Retry Logic
    func markSegmentPending(_ segment: TranscriptionSegment) {
        guard let context = modelContext else { return }
        segment.transcriptionStatus = "not_started"
        segment.processingStatus = "pending"
        segment.updatedAt = Date()
        do {
            try context.save()
            logger.logInfo("Marked segment as pending for retry: \(segment.segmentIndex)")
        } catch {
            logger.logError("Failed to mark segment as pending", error: error)
        }
    }
    
    // MARK: - Cleanup
    func deleteSession(_ session: RecordingSession) {
        guard let context = modelContext else { return }
        
        // Delete associated audio files
        for segment in session.segments {
            try? FileManager.default.removeItem(at: segment.fileURL)
        }
        
        context.delete(session)
        
        do {
            try context.save()
            logger.logSuccess("Deleted session: \(session.baseFileName)")
        } catch {
            logger.logError("Failed to delete session", error: error)
        }
    }
    
    // MARK: - Refresh Data
    func refreshSessions() {
        sessions = fetchSessions()
    }
} 