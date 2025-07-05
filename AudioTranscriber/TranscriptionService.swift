import Foundation
import Speech
import Combine

// MARK: - Transcription Method Enum
enum TranscriptionMethod: String, Codable, CaseIterable {
    case local = "local"
    case openAI = "openai"
    case openAIWithFallback = "openai_with_fallback"
    
    var description: String {
        switch self {
        case .local:
            return "Uses Apple's built-in speech recognition (offline, fast)"
        case .openAI:
            return "Uses OpenAI Whisper API (online, high accuracy)"
        case .openAIWithFallback:
            return "Uses OpenAI Whisper, falls back to local if it fails after 5 attempts"
        }
    }
    
    var displayName: String {
        switch self {
        case .local: return "Local (Apple Speech)"
        case .openAI: return "OpenAI Whisper"
        case .openAIWithFallback: return "OpenAI + Local Fallback"
        }
    }
    
    var requiresAPIKey: Bool {
        switch self {
        case .local:
            return false
        case .openAI, .openAIWithFallback:
            return true
        }
    }
}

// MARK: - Unified Transcription Result
enum UnifiedTranscriptionResult {
    case success(String, TranscriptionMethod)
    case failure(String, TranscriptionMethod?)
}

// MARK: - Transcription Service
class TranscriptionService: ObservableObject {
    static let shared = TranscriptionService()
    
    private let logger = DebugLogger.shared
    private let openAIService = OpenAIWhisperService.shared
    private var speechRecognizer: SFSpeechRecognizer?
    
    // User preferences
    @Published var preferredMethod: TranscriptionMethod = .openAIWithFallback
    
    private init() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }
    
    // MARK: - Main Transcription Method
    func transcribeAudio(fileURL: URL, 
                        method: TranscriptionMethod? = nil, 
                        completion: @escaping (UnifiedTranscriptionResult) -> Void) {
        
        let transcriptionMethod = method ?? preferredMethod
        logger.logInfo("🎯 Starting transcription with method: \(transcriptionMethod.rawValue)")
        
        switch transcriptionMethod {
        case .local:
            transcribeWithLocal(fileURL: fileURL, completion: completion)
            
        case .openAI:
            transcribeWithOpenAI(fileURL: fileURL, completion: completion)
            
        case .openAIWithFallback:
            transcribeWithOpenAIAndFallback(fileURL: fileURL, completion: completion)
        }
    }
    
    // MARK: - Local Transcription
    private func transcribeWithLocal(fileURL: URL, completion: @escaping (UnifiedTranscriptionResult) -> Void) {
        logger.logInfo("🍎 Starting local transcription...")
        
        // Check if we have a cached transcript first
        if let cachedTranscript = TranscriptManager.shared.getTranscript(for: fileURL) {
            logger.logInfo("📋 Using cached transcript for: \(fileURL.lastPathComponent)")
            completion(.success(cachedTranscript, .local))
            return
        }
        
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            logger.logError("Speech recognizer not available")
            completion(.failure("Speech recognition is not available on this device", .local))
            return
        }
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            logger.logError("Audio file does not exist: \(fileURL.path)")
            completion(.failure("Audio file not found", .local))
            return
        }
        
        // Decrypt the file data first
        do {
            let decryptedData = try AudioEncryptionService.shared.decryptFile(at: fileURL)
            
            // Create temporary file for speech recognition
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".caf")
            try decryptedData.write(to: tempURL)
            
            let request = SFSpeechURLRecognitionRequest(url: tempURL)
            request.shouldReportPartialResults = false
            
            // Add timeout to prevent hanging
            var hasCompleted = false
            let timeoutSeconds = 30.0
            
            let timeoutTimer = Timer.scheduledTimer(withTimeInterval: timeoutSeconds, repeats: false) { _ in
                if !hasCompleted {
                    hasCompleted = true
                    // Clean up temp file
                    try? FileManager.default.removeItem(at: tempURL)
                    completion(.failure("Local transcription timed out after \(Int(timeoutSeconds)) seconds", .local))
                }
            }
            
            speechRecognizer.recognitionTask(with: request) { result, error in
                DispatchQueue.main.async {
                    guard !hasCompleted else { return }
                    hasCompleted = true
                    timeoutTimer.invalidate()
                    
                    // Clean up temp file
                    try? FileManager.default.removeItem(at: tempURL)
                    
                    if let error = error {
                        self.logger.logError("Local transcription error: \(error.localizedDescription)")
                        completion(.failure("Local transcription failed: \(error.localizedDescription)", .local))
                        return
                    }
                    
                    if let result = result {
                        let transcription = result.bestTranscription.formattedString.trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        if transcription.isEmpty {
                            completion(.success("[No speech detected]", .local))
                        } else {
                            // Cache the successful transcription
                            TranscriptManager.shared.saveTranscript(transcription, for: fileURL)
                            self.logger.logSuccess("✅ Local transcription completed")
                            completion(.success(transcription, .local))
                        }
                    } else {
                        completion(.failure("No transcription result from local service", .local))
                    }
                }
            }
        } catch {
            logger.logError("Failed to decrypt audio file for transcription", error: error)
            completion(.failure("Failed to decrypt audio file: \(error.localizedDescription)", .local))
        }
    }
    
    // MARK: - OpenAI Transcription
    private func transcribeWithOpenAI(fileURL: URL, completion: @escaping (UnifiedTranscriptionResult) -> Void) {
        logger.logInfo("🤖 Starting OpenAI transcription...")
        
        // Check if we have a cached transcript first
        if let cachedTranscript = TranscriptManager.shared.getTranscript(for: fileURL) {
            logger.logInfo("📋 Using cached transcript for: \(fileURL.lastPathComponent)")
            completion(.success(cachedTranscript, .openAI))
            return
        }
        
        // Decrypt the file data first
        do {
            let decryptedData = try AudioEncryptionService.shared.decryptFile(at: fileURL)
            
            // Create temporary file for OpenAI
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".caf")
            try decryptedData.write(to: tempURL)
            
            openAIService.transcribeAudio(fileURL: tempURL) { result in
                // Clean up temp file
                try? FileManager.default.removeItem(at: tempURL)
                
                DispatchQueue.main.async {
                    switch result {
                    case .success(let transcription):
                        // Cache the successful transcription
                        TranscriptManager.shared.saveTranscript(transcription, for: fileURL)
                        completion(.success(transcription, .openAI))
                        
                    case .failure(let error):
                        completion(.failure(error.localizedDescription, .openAI))
                    }
                }
            }
        } catch {
            logger.logError("Failed to decrypt audio file for transcription", error: error)
            completion(.failure("Failed to decrypt audio file: \(error.localizedDescription)", .openAI))
        }
    }
    
    // MARK: - OpenAI with Local Fallback
    private func transcribeWithOpenAIAndFallback(fileURL: URL, completion: @escaping (UnifiedTranscriptionResult) -> Void) {
        logger.logInfo("🔄 Starting OpenAI transcription with local fallback...")
        
        // Check if we have a cached transcript first
        if let cachedTranscript = TranscriptManager.shared.getTranscript(for: fileURL) {
            logger.logInfo("📋 Using cached transcript for: \(fileURL.lastPathComponent)")
            completion(.success(cachedTranscript, .openAIWithFallback))
            return
        }
        
        // Try OpenAI first
        openAIService.transcribeAudio(fileURL: fileURL) { [weak self] result in
            switch result {
            case .success(let transcription):
                DispatchQueue.main.async {
                    // Cache the successful transcription
                    TranscriptManager.shared.saveTranscript(transcription, for: fileURL)
                    self?.logger.logSuccess("✅ OpenAI transcription succeeded")
                    completion(.success(transcription, .openAI))
                }
                
            case .failure(let error):
                // OpenAI failed, try local fallback
                self?.logger.logWarning("⚠️ OpenAI failed, falling back to local: \(error.localizedDescription ?? "Unknown error")")
                
                DispatchQueue.main.async {
                    self?.transcribeWithLocal(fileURL: fileURL) { fallbackResult in
                        switch fallbackResult {
                        case .success(let transcription, _):
                            self?.logger.logSuccess("✅ Local fallback succeeded")
                            completion(.success(transcription + " (fallback)", .local))
                            
                        case .failure(let fallbackError, _):
                            self?.logger.logError("❌ Both OpenAI and local transcription failed")
                            let combinedError = "OpenAI failed: \(error.localizedDescription ?? "Unknown error"), Local fallback failed: \(fallbackError)"
                            completion(.failure(combinedError, .openAIWithFallback))
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Utility Methods
    func canUseMethod(_ method: TranscriptionMethod) -> (Bool, String?) {
        switch method {
        case .local:
            guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
                return (false, "Speech recognition is not available on this device")
            }
            return (true, nil)
            
        case .openAI, .openAIWithFallback:
            guard openAIService.hasValidAPIKey() else {
                return (false, "OpenAI API key not configured")
            }
            return (true, nil)
        }
    }
    
    func getMethodStatus() -> [(TranscriptionMethod, Bool, String?)] {
        return TranscriptionMethod.allCases.map { method in
            let (canUse, reason) = canUseMethod(method)
            return (method, canUse, reason)
        }
    }
    
    // MARK: - Settings Management
    func setPreferredMethod(_ method: TranscriptionMethod) {
        let (canUse, reason) = canUseMethod(method)
        if canUse {
            preferredMethod = method
            UserDefaults.standard.set(method.rawValue, forKey: "preferredTranscriptionMethod")
            logger.logInfo("📝 Preferred transcription method set to: \(method.rawValue)")
        } else {
            logger.logWarning("Cannot set preferred method to \(method.rawValue): \(reason ?? "Unknown reason")")
        }
    }
    
    func loadPreferredMethod() {
        if let savedMethod = UserDefaults.standard.string(forKey: "preferredTranscriptionMethod"),
           let method = TranscriptionMethod(rawValue: savedMethod) {
            let (canUse, _) = canUseMethod(method)
            if canUse {
                preferredMethod = method
            } else {
                // Fallback to a working method
                for fallbackMethod in TranscriptionMethod.allCases {
                    let (canUseFallback, _) = canUseMethod(fallbackMethod)
                    if canUseFallback {
                        preferredMethod = fallbackMethod
                        break
                    }
                }
            }
        }
    }
    
    // Retry all pending transcriptions with exponential backoff
    @MainActor
    func retryPendingTranscriptions() {
        Task {
            let pendingSegments = await SwiftDataManager.shared.fetchPendingTranscriptions()
            for segment in pendingSegments {
                await retryTranscription(for: segment, attempt: 1)
            }
        }
    }

    @MainActor
    private func retryTranscription(for segment: TranscriptionSegment, attempt: Int) async {
        let maxAttempts = 5
        let delay = pow(2.0, Double(attempt - 1))
        logger.logInfo("Retrying transcription for segment \(segment.segmentIndex), attempt \(attempt)")
        transcribeAudio(fileURL: segment.fileURL) { result in
            Task { @MainActor in
                switch result {
                case .success(let transcription, let method):
                    await SwiftDataManager.shared.updateSegmentTranscription(segment, transcription: transcription, method: method)
                case .failure(let error, _):
                    if attempt < maxAttempts {
                        DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                            Task { @MainActor in
                                await self.retryTranscription(for: segment, attempt: attempt + 1)
                            }
                        }
                    } else {
                        await SwiftDataManager.shared.markSegmentTranscriptionFailed(segment, error: error)
                    }
                }
            }
        }
    }
}

// MARK: - UserDefaults Extension for convenience
extension UserDefaults {
    var preferredTranscriptionMethod: TranscriptionMethod {
        get {
            if let rawValue = string(forKey: "preferredTranscriptionMethod"),
               let method = TranscriptionMethod(rawValue: rawValue) {
                return method
            }
            return .openAIWithFallback // Default
        }
        set {
            set(newValue.rawValue, forKey: "preferredTranscriptionMethod")
        }
    }
}
