# 🏗️ AudioTranscriber Architecture Document

## 📋 Overview

This document outlines the architectural decisions, design patterns, and technical implementation details for the AudioTranscriber iOS application. The app is built with a focus on robustness, scalability, and real-world audio handling challenges.

## 🎯 Architectural Principles

### 1. **Separation of Concerns**
- **AudioService**: Core audio recording and processing logic
- **SwiftDataManager**: Data persistence and management
- **TranscriptionService**: Transcription orchestration
- **UI Layer**: SwiftUI views for user interaction

### 2. **Reactive Programming**
- **@Published Properties**: Real-time UI updates
- **ObservableObject Pattern**: State management across components
- **NotificationCenter**: Cross-component communication

### 3. **Error Handling & Resilience**
- **Graceful Degradation**: Fallback mechanisms for failures
- **Retry Logic**: Exponential backoff for network operations
- **State Recovery**: Automatic recovery from interruptions

### 4. **Security First**
- **AES-GCM Encryption**: All audio files encrypted at rest
- **Keychain Storage**: Secure API key management
- **No Plain Text**: No sensitive data in logs or UI

## 🏛️ System Architecture

### High-Level Architecture Diagram
```
┌─────────────────────────────────────────────────────────────┐
│                    Presentation Layer                       │
├─────────────────────────────────────────────────────────────┤
│  ContentView  │  SessionListView  │  TranscriptionView     │
├─────────────────────────────────────────────────────────────┤
│                    Business Logic Layer                     │
├─────────────────────────────────────────────────────────────┤
│  AudioService │  TranscriptionService │  SwiftDataManager   │
├─────────────────────────────────────────────────────────────┤
│                    Data Layer                               │
├─────────────────────────────────────────────────────────────┤
│  SwiftData    │  FileSystem    │  Keychain    │  Network    │
└─────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

#### **AudioService** (`AudioService.swift`)
**Primary Responsibilities:**
- Audio session management and configuration
- Real-time recording with 30-second segmentation
- Audio interruption handling and recovery
- Background recording support
- Audio processing (noise reduction, level monitoring)

**Key Design Decisions:**
- **Native Format Usage**: Always use input node's native format for compatibility
- **Dual Recording Modes**: Segmented (30s chunks) and legacy (single file)
- **Background Task Management**: Proper iOS background execution
- **Audio Session Reset**: Clean session management for route changes

#### **SwiftDataManager** (`SwiftDataManager.swift`)
**Primary Responsibilities:**
- SwiftData model management and persistence
- Session and segment CRUD operations
- Data relationships and constraints
- Background data processing

**Key Design Decisions:**
- **Single Source of Truth**: Centralized data management
- **Relationship Management**: Proper parent-child relationships
- **Background Context**: Efficient data operations
- **Notification System**: Real-time UI updates

#### **TranscriptionService** (`TranscriptionService.swift`)
**Primary Responsibilities:**
- Transcription orchestration and coordination
- Multi-provider support (OpenAI + Local fallback)
- Retry logic and error handling
- Concurrent processing management

**Key Design Decisions:**
- **Provider Abstraction**: Unified interface for multiple services
- **Fallback Strategy**: Automatic fallback to local transcription
- **Concurrent Processing**: Efficient handling of multiple segments
- **Error Isolation**: Failures don't affect other segments

## 🔧 Design Patterns

### 1. **Service Layer Pattern**
```swift
// Centralized service management
class AudioService: ObservableObject {
    // Core audio functionality
}

class TranscriptionService {
    // Transcription orchestration
}

class SwiftDataManager {
    // Data persistence
}
```

### 2. **Observer Pattern**
```swift
// Real-time UI updates
@Published var isRecording = false
@Published var transcribedText = ""
@Published var audioLevel: Float = 0.0
```

### 3. **Factory Pattern**
```swift
// Transcription provider creation
enum TranscriptionMethod {
    case openAI
    case local
    case openAIWithFallback
}
```

### 4. **Strategy Pattern**
```swift
// Different recording strategies
func startRecording() {
    if UserDefaults.standard.bool(forKey: "useSegmentedRecording") {
        startSegmentedRecording()
    } else {
        startLegacyRecording()
    }
}
```

## 📊 Data Architecture

### SwiftData Models

#### **RecordingSession**
```swift
@Model
class RecordingSession {
    var id: UUID
    var baseFileName: String
    var startDate: Date
    var endDate: Date?
    var totalDuration: TimeInterval
    var segmentCount: Int
    var combinedTranscription: String
    var segments: [TranscriptionSegment]
}
```

#### **TranscriptionSegment**
```swift
@Model
class TranscriptionSegment {
    var id: UUID
    var segmentIndex: Int
    var startTime: TimeInterval
    var duration: TimeInterval
    var transcription: String?
    var transcriptionStatus: String
    var transcriptionMethod: String?
    var errorMessage: String?
    var fileURL: URL
}
```

### Data Relationships
- **One-to-Many**: RecordingSession → TranscriptionSegment
- **Cascade Deletion**: Deleting session removes all segments
- **Indexed Queries**: Efficient filtering and sorting

## 🔄 State Management

### Audio Recording States
```swift
enum RecordingState {
    case idle
    case recording
    case paused
    case processing
    case completed
    case error
}
```

### Transcription States
```swift
enum TranscriptionState {
    case pending
    case inProgress
    case completed
    case failed
    case retrying
}
```

### State Transitions
```
Idle → Recording → Processing → Completed
  ↓        ↓          ↓
Paused ← Resume ← Error Recovery
```

## 🛡️ Error Handling Strategy

### 1. **Graceful Degradation**
- **Network Failures**: Fallback to local transcription
- **Audio Interruptions**: Automatic pause/resume
- **Storage Issues**: Early detection and user notification

### 2. **Retry Mechanisms**
```swift
// Exponential backoff for network requests
private func retryWithBackoff(attempt: Int, maxAttempts: Int = 3) {
    let delay = pow(2.0, Double(attempt)) // Exponential backoff
    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
        // Retry logic
    }
}
```

### 3. **Error Recovery**
- **Audio Session Reset**: Clean recovery from interruptions
- **Data Consistency**: Transaction-based operations
- **User Feedback**: Clear error messages and recovery options

## 🔒 Security Architecture

### Encryption Strategy
```swift
// AES-GCM encryption for all audio files
class AudioEncryptionService {
    static let shared = AudioEncryptionService()
    
    func encryptFile(at url: URL) throws {
        // AES-GCM encryption with random IV
    }
    
    func decryptFile(at url: URL) throws -> Data {
        // Decryption with integrity verification
    }
}
```

### Key Management
- **Keychain Storage**: Secure API key storage
- **No Hardcoded Secrets**: All sensitive data in Keychain
- **Access Control**: Proper keychain access restrictions

## 📱 UI Architecture

### SwiftUI View Hierarchy
```
ContentView
├── RecordingControls
├── AudioVisualizer
├── LiveTranscriptionBox
├── SessionListView
├── TranscriptionProgressView
└── SettingsView
```

### State Binding
```swift
// Clean state management
@StateObject private var audioService = AudioService()
@ObservedObject var dataManager = SwiftDataManager.shared
```

## 🚀 Performance Considerations

### 1. **Memory Management**
- **Buffer Management**: Efficient audio buffer handling
- **Temporary File Cleanup**: Automatic cleanup of temp files
- **Background Processing**: Non-blocking UI operations

### 2. **Storage Optimization**
- **Compression**: Audio file compression
- **Cleanup Policies**: Automatic old file removal
- **Efficient Queries**: Indexed SwiftData queries

### 3. **Battery Optimization**
- **Background Task Limits**: Proper iOS background execution
- **Network Batching**: Efficient API request batching
- **Audio Processing**: Optimized DSP algorithms

## 🔧 Configuration Management

### User Preferences
```swift
// Centralized configuration
struct AudioQualitySettings {
    let sampleRate: Double
    let bitDepth: Int
    let format: String
}

struct TranscriptionSettings {
    let method: TranscriptionMethod
    let retryCount: Int
    let timeout: TimeInterval
}
```

### Environment Configuration
- **Development**: Debug logging, test endpoints
- **Production**: Optimized settings, production APIs
- **Testing**: Mock services, test data

## 🧪 Testing Strategy

### Unit Testing
- **Service Layer**: Mock dependencies for isolated testing
- **Data Layer**: SwiftData in-memory testing
- **Business Logic**: Pure function testing

### Integration Testing
- **Audio Pipeline**: End-to-end recording tests
- **Transcription Flow**: Complete transcription testing
- **Data Persistence**: SwiftData integration tests

### UI Testing
- **User Flows**: Complete user journey testing
- **Accessibility**: VoiceOver and accessibility testing
- **Performance**: UI responsiveness testing

## 📈 Scalability Considerations

### 1. **Data Scalability**
- **Pagination**: Efficient large dataset handling
- **Lazy Loading**: On-demand data loading
- **Caching**: Intelligent data caching

### 2. **Performance Scalability**
- **Concurrent Processing**: Parallel transcription processing
- **Background Operations**: Non-blocking operations
- **Memory Efficiency**: Optimized memory usage

### 3. **Feature Scalability**
- **Modular Design**: Easy feature addition
- **Plugin Architecture**: Extensible transcription providers
- **Configuration Driven**: Runtime configuration changes

## 🔮 Future Enhancements

### Planned Architecture Improvements
1. **Microservices**: Separate transcription service
2. **Cloud Sync**: Multi-device synchronization
3. **Advanced Analytics**: Usage analytics and insights
4. **Machine Learning**: Custom transcription models

### Technical Debt
1. **Code Refactoring**: Extract common utilities
2. **Documentation**: Comprehensive API documentation
3. **Performance Optimization**: Further memory and battery optimization
4. **Testing Coverage**: Increase test coverage

---

**This architecture document serves as a living document and should be updated as the application evolves.** 