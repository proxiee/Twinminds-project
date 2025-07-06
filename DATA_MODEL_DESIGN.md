# 📊 AudioTranscriber Data Model Design

## 📋 Overview

This document outlines the SwiftData schema design, data relationships, performance optimizations, and data management strategies for the AudioTranscriber iOS application. The data model is designed to handle large-scale audio recording sessions with efficient querying and storage.

## 🏗️ SwiftData Schema Design

### Core Data Models

#### **RecordingSession** - Main Session Entity
```swift
@Model
class RecordingSession {
    // Primary identifier
    var id: UUID
    
    // Session metadata
    var baseFileName: String
    var startDate: Date
    var endDate: Date?
    var totalDuration: TimeInterval
    var segmentCount: Int
    
    // Transcription data
    var combinedTranscription: String
    var transcriptionStatus: String
    
    // Relationships
    @Relationship(deleteRule: .cascade, inverse: \TranscriptionSegment.session)
    var segments: [TranscriptionSegment]
    
    // Metadata
    var createdAt: Date
    var updatedAt: Date
    var isCompleted: Bool
}
```

**Design Rationale:**
- **UUID Primary Key**: Ensures uniqueness across devices and sync scenarios
- **Cascade Delete Rule**: Automatically removes segments when session is deleted
- **Optional End Date**: Allows for ongoing sessions
- **Status Tracking**: Enables efficient filtering and progress tracking

#### **TranscriptionSegment** - Individual Audio Segments
```swift
@Model
class TranscriptionSegment {
    // Primary identifier
    var id: UUID
    
    // Segment metadata
    var segmentIndex: Int
    var startTime: TimeInterval
    var duration: TimeInterval
    var fileURL: URL
    
    // Transcription data
    var transcription: String?
    var transcriptionStatus: String
    var transcriptionMethod: String?
    var errorMessage: String?
    
    // Performance metadata
    var processingStartTime: Date?
    var processingEndTime: Date?
    var retryCount: Int
    
    // Relationships
    var session: RecordingSession?
    
    // Metadata
    var createdAt: Date
    var updatedAt: Date
}
```

**Design Rationale:**
- **Index-based Ordering**: `segmentIndex` ensures proper segment ordering
- **Status Tracking**: Enables progress monitoring and error handling
- **Performance Metrics**: Tracks processing times for optimization
- **Retry Mechanism**: Supports automatic retry for failed transcriptions

### Data Relationships

#### **One-to-Many Relationship**
```
RecordingSession (1) ←→ (N) TranscriptionSegment
```

**Relationship Configuration:**
```swift
// In RecordingSession
@Relationship(deleteRule: .cascade, inverse: \TranscriptionSegment.session)
var segments: [TranscriptionSegment]

// In TranscriptionSegment
var session: RecordingSession?
```

**Benefits:**
- **Cascade Deletion**: Deleting a session removes all associated segments
- **Bidirectional Access**: Navigate from session to segments and vice versa
- **Data Integrity**: Ensures referential integrity

## 📈 Performance Optimizations

### 1. **Indexing Strategy**

#### **Primary Indexes**
```swift
// RecordingSession indexes
@Attribute(.unique) var id: UUID
@Attribute(.indexed) var startDate: Date
@Attribute(.indexed) var isCompleted: Bool
@Attribute(.indexed) var transcriptionStatus: String

// TranscriptionSegment indexes
@Attribute(.unique) var id: UUID
@Attribute(.indexed) var segmentIndex: Int
@Attribute(.indexed) var transcriptionStatus: String
@Attribute(.indexed) var session: RecordingSession?
```

#### **Composite Indexes**
```swift
// For efficient session queries
@Attribute(.indexed) var (startDate, isCompleted): (Date, Bool)

// For efficient segment queries
@Attribute(.indexed) var (session, segmentIndex): (RecordingSession?, Int)
```

### 2. **Query Optimization**

#### **Efficient Session Queries**
```swift
// Fetch recent sessions with pagination
func fetchRecentSessions(limit: Int = 20, offset: Int = 0) -> [RecordingSession] {
    let descriptor = FetchDescriptor<RecordingSession>(
        predicate: #Predicate<RecordingSession> { session in
            session.isCompleted == true
        },
        sortBy: [SortDescriptor(\.startDate, order: .reverse)],
        fetchLimit: limit,
        fetchOffset: offset
    )
    return try? modelContext.fetch(descriptor) ?? []
}

// Fetch sessions by status
func fetchSessionsByStatus(_ status: String) -> [RecordingSession] {
    let descriptor = FetchDescriptor<RecordingSession>(
        predicate: #Predicate<RecordingSession> { session in
            session.transcriptionStatus == status
        },
        sortBy: [SortDescriptor(\.startDate, order: .reverse)]
    )
    return try? modelContext.fetch(descriptor) ?? []
}
```

#### **Efficient Segment Queries**
```swift
// Fetch segments for a session
func fetchSegmentsForSession(_ session: RecordingSession) -> [TranscriptionSegment] {
    let descriptor = FetchDescriptor<TranscriptionSegment>(
        predicate: #Predicate<TranscriptionSegment> { segment in
            segment.session?.id == session.id
        },
        sortBy: [SortDescriptor(\.segmentIndex, order: .forward)]
    )
    return try? modelContext.fetch(descriptor) ?? []
}

// Fetch failed segments for retry
func fetchFailedSegments() -> [TranscriptionSegment] {
    let descriptor = FetchDescriptor<TranscriptionSegment>(
        predicate: #Predicate<TranscriptionSegment> { segment in
            segment.transcriptionStatus == "failed" && segment.retryCount < 3
        },
        sortBy: [SortDescriptor(\.createdAt, order: .forward)]
    )
    return try? modelContext.fetch(descriptor) ?? []
}
```

### 3. **Batch Operations**

#### **Batch Insert**
```swift
func createSessionWithSegments(baseFileName: String, segmentCount: Int) -> RecordingSession? {
    let session = RecordingSession(baseFileName: baseFileName)
    
    // Batch create segments
    var segments: [TranscriptionSegment] = []
    for i in 0..<segmentCount {
        let segment = TranscriptionSegment(
            segmentIndex: i,
            startTime: Double(i) * 30.0,
            duration: 30.0,
            fileURL: generateSegmentURL(index: i)
        )
        segment.session = session
        segments.append(segment)
    }
    
    session.segments = segments
    
    do {
        try modelContext.save()
        return session
    } catch {
        logger.logError("Failed to create session with segments", error: error)
        return nil
    }
}
```

#### **Batch Update**
```swift
func updateTranscriptionStatus(for session: RecordingSession) {
    let completedSegments = session.segments.filter { $0.transcriptionStatus == "completed" }
    let totalSegments = session.segments.count
    
    if completedSegments.count == totalSegments {
        session.transcriptionStatus = "completed"
        session.isCompleted = true
        session.endDate = Date()
    } else if completedSegments.count > 0 {
        session.transcriptionStatus = "in_progress"
    } else {
        session.transcriptionStatus = "pending"
    }
    
    session.updatedAt = Date()
    
    do {
        try modelContext.save()
    } catch {
        logger.logError("Failed to update session status", error: error)
    }
}
```

## 🔄 Data Management Strategies

### 1. **CRUD Operations**

#### **Create Operations**
```swift
func createSession(baseFileName: String) -> RecordingSession? {
    let session = RecordingSession(baseFileName: baseFileName)
    session.createdAt = Date()
    session.updatedAt = Date()
    
    do {
        modelContext.insert(session)
        try modelContext.save()
        return session
    } catch {
        logger.logError("Failed to create session", error: error)
        return nil
    }
}

func addSegment(to session: RecordingSession, segmentIndex: Int, 
                startTime: TimeInterval, duration: TimeInterval, fileURL: URL) -> TranscriptionSegment? {
    let segment = TranscriptionSegment(
        segmentIndex: segmentIndex,
        startTime: startTime,
        duration: duration,
        fileURL: fileURL
    )
    segment.session = session
    segment.createdAt = Date()
    segment.updatedAt = Date()
    
    do {
        modelContext.insert(segment)
        try modelContext.save()
        return segment
    } catch {
        logger.logError("Failed to add segment", error: error)
        return nil
    }
}
```

#### **Read Operations**
```swift
func fetchSessions() -> [RecordingSession] {
    let descriptor = FetchDescriptor<RecordingSession>(
        sortBy: [SortDescriptor(\.startDate, order: .reverse)]
    )
    return try? modelContext.fetch(descriptor) ?? []
}

func fetchSession(by id: UUID) -> RecordingSession? {
    let descriptor = FetchDescriptor<RecordingSession>(
        predicate: #Predicate<RecordingSession> { session in
            session.id == id
        }
    )
    return try? modelContext.fetch(descriptor).first
}
```

#### **Update Operations**
```swift
func updateSegmentTranscription(_ segment: TranscriptionSegment, 
                               transcription: String, method: TranscriptionMethod) {
    segment.transcription = transcription
    segment.transcriptionStatus = "completed"
    segment.transcriptionMethod = method.rawValue
    segment.processingEndTime = Date()
    segment.updatedAt = Date()
    
    do {
        try modelContext.save()
    } catch {
        logger.logError("Failed to update segment transcription", error: error)
    }
}

func markSegmentTranscriptionFailed(_ segment: TranscriptionSegment, error: Error) {
    segment.transcriptionStatus = "failed"
    segment.errorMessage = error.localizedDescription
    segment.retryCount += 1
    segment.processingEndTime = Date()
    segment.updatedAt = Date()
    
    do {
        try modelContext.save()
    } catch {
        logger.logError("Failed to mark segment as failed", error: error)
    }
}
```

#### **Delete Operations**
```swift
func deleteSession(_ session: RecordingSession) {
    do {
        modelContext.delete(session)
        try modelContext.save()
        logger.logSuccess("Session deleted: \(session.baseFileName)")
    } catch {
        logger.logError("Failed to delete session", error: error)
    }
}

func deleteSegment(_ segment: TranscriptionSegment) {
    do {
        modelContext.delete(segment)
        try modelContext.save()
        logger.logSuccess("Segment deleted: \(segment.segmentIndex)")
    } catch {
        logger.logError("Failed to delete segment", error: error)
    }
}
```

### 2. **Data Migration Strategy**

#### **Version Management**
```swift
// Schema version tracking
@Model
class SchemaVersion {
    var version: Int
    var appliedAt: Date
    var description: String
}

// Migration handling
func migrateIfNeeded() {
    let currentVersion = getCurrentSchemaVersion()
    let requiredVersion = 2 // Current schema version
    
    if currentVersion < requiredVersion {
        performMigration(from: currentVersion, to: requiredVersion)
    }
}
```

#### **Migration Operations**
```swift
func performMigration(from oldVersion: Int, to newVersion: Int) {
    switch (oldVersion, newVersion) {
    case (1, 2):
        migrateToVersion2()
    case (2, 3):
        migrateToVersion3()
    default:
        logger.logWarning("Unknown migration path: \(oldVersion) -> \(newVersion)")
    }
}

func migrateToVersion2() {
    // Add new fields to existing models
    let sessions = fetchAllSessions()
    for session in sessions {
        if session.transcriptionStatus.isEmpty {
            session.transcriptionStatus = "pending"
        }
    }
    
    try? modelContext.save()
    updateSchemaVersion(to: 2)
}
```

### 3. **Data Validation**

#### **Model Validation**
```swift
extension RecordingSession {
    var isValid: Bool {
        return !baseFileName.isEmpty && 
               startDate <= Date() && 
               segmentCount >= 0 &&
               totalDuration >= 0
    }
    
    var validationErrors: [String] {
        var errors: [String] = []
        
        if baseFileName.isEmpty {
            errors.append("Base file name cannot be empty")
        }
        
        if startDate > Date() {
            errors.append("Start date cannot be in the future")
        }
        
        if segmentCount < 0 {
            errors.append("Segment count cannot be negative")
        }
        
        if totalDuration < 0 {
            errors.append("Total duration cannot be negative")
        }
        
        return errors
    }
}
```

#### **Business Logic Validation**
```swift
func validateSessionData(_ session: RecordingSession) -> Bool {
    // Check if all segments are properly linked
    for segment in session.segments {
        if segment.session?.id != session.id {
            logger.logError("Segment \(segment.id) is not properly linked to session \(session.id)")
            return false
        }
    }
    
    // Check if segment indices are sequential
    let sortedSegments = session.segments.sorted { $0.segmentIndex < $1.segmentIndex }
    for (index, segment) in sortedSegments.enumerated() {
        if segment.segmentIndex != index {
            logger.logError("Segment indices are not sequential")
            return false
        }
    }
    
    return true
}
```

## 📊 Performance Monitoring

### 1. **Query Performance Tracking**
```swift
func measureQueryPerformance<T>(_ query: () throws -> [T], name: String) -> [T] {
    let startTime = CFAbsoluteTimeGetCurrent()
    
    do {
        let result = try query()
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        
        logger.logInfo("Query '\(name)' completed in \(duration * 1000)ms")
        return result
    } catch {
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        
        logger.logError("Query '\(name)' failed after \(duration * 1000)ms", error: error)
        throw error
    }
}
```

### 2. **Memory Usage Monitoring**
```swift
func monitorMemoryUsage() {
    let memoryUsage = getMemoryUsage()
    logger.logInfo("Current memory usage: \(memoryUsage)MB")
    
    if memoryUsage > 100 { // 100MB threshold
        logger.logWarning("High memory usage detected: \(memoryUsage)MB")
        performMemoryCleanup()
    }
}

func performMemoryCleanup() {
    // Clear any cached data
    modelContext.refreshAllObjects()
    
    // Force garbage collection if available
    #if os(iOS)
    // iOS doesn't have explicit garbage collection, but we can help the system
    autoreleasepool {
        // Perform cleanup operations
    }
    #endif
}
```

## 🔒 Data Security

### 1. **Encryption at Rest**
```swift
// Sensitive data encryption
extension TranscriptionSegment {
    var encryptedTranscription: Data? {
        get {
            guard let transcription = transcription else { return nil }
            return try? AudioEncryptionService.shared.encrypt(transcription.data(using: .utf8) ?? Data())
        }
        set {
            guard let data = newValue else { transcription = nil; return }
            transcription = String(data: try! AudioEncryptionService.shared.decrypt(data), encoding: .utf8)
        }
    }
}
```

### 2. **Access Control**
```swift
// Data access validation
func validateDataAccess(for session: RecordingSession) -> Bool {
    // Check if user has permission to access this session
    // This could be expanded for multi-user scenarios
    return session.createdAt > Date().addingTimeInterval(-365 * 24 * 60 * 60) // Within last year
}
```

## 🧪 Testing Strategy

### 1. **Unit Tests**
```swift
class SwiftDataManagerTests: XCTestCase {
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    
    override func setUp() {
        super.setUp()
        modelContainer = try! ModelContainer(for: RecordingSession.self, TranscriptionSegment.self)
        modelContext = ModelContext(modelContainer)
    }
    
    func testCreateSession() {
        let session = SwiftDataManager.shared.createSession(baseFileName: "test_session")
        XCTAssertNotNil(session)
        XCTAssertEqual(session?.baseFileName, "test_session")
    }
    
    func testAddSegment() {
        let session = SwiftDataManager.shared.createSession(baseFileName: "test_session")
        let segment = SwiftDataManager.shared.addSegment(
            to: session!,
            segmentIndex: 0,
            startTime: 0,
            duration: 30,
            fileURL: URL(fileURLWithPath: "/test/path")
        )
        XCTAssertNotNil(segment)
        XCTAssertEqual(segment?.segmentIndex, 0)
    }
}
```

### 2. **Performance Tests**
```swift
func testBulkInsertPerformance() {
    measure {
        for i in 0..<100 {
            let session = SwiftDataManager.shared.createSession(baseFileName: "bulk_test_\(i)")
            for j in 0..<10 {
                _ = SwiftDataManager.shared.addSegment(
                    to: session!,
                    segmentIndex: j,
                    startTime: Double(j) * 30,
                    duration: 30,
                    fileURL: URL(fileURLWithPath: "/test/path_\(i)_\(j)")
                )
            }
        }
    }
}
```

## 🔮 Future Enhancements

### 1. **Planned Schema Improvements**
- **User Management**: Multi-user support with user-specific sessions
- **Cloud Sync**: iCloud integration for cross-device synchronization
- **Advanced Analytics**: Usage statistics and performance metrics
- **Tagging System**: Session and segment tagging for better organization

### 2. **Performance Optimizations**
- **Lazy Loading**: On-demand loading of large datasets
- **Caching Layer**: Intelligent caching for frequently accessed data
- **Background Processing**: Offline processing queue for large operations
- **Compression**: Data compression for storage optimization

### 3. **Data Analytics**
- **Usage Patterns**: Track user behavior and optimize accordingly
- **Performance Metrics**: Monitor query performance and optimize indexes
- **Storage Analytics**: Track storage usage and implement cleanup policies
- **Error Tracking**: Monitor and analyze data-related errors

---

**This data model design document provides a comprehensive overview of the SwiftData implementation and should be referenced when making changes to the data layer.** 