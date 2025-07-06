import Foundation
import AVFoundation
import Speech
import SwiftUI
#if os(iOS)
import UIKit
#endif

// MARK: - Audio Segment Data Structures
// holds info about each 30-second chunk of audio
struct AudioSegment: Identifiable {
    let id = UUID()
    let url: URL
    let startTime: TimeInterval
    let duration: TimeInterval
    var transcription: String?
    var isTranscribing: Bool = false
    var transcriptionCompleted: Bool = false
    
    var endTime: TimeInterval {
        return startTime + duration
    }
}

// manages a whole recording session with multiple segments
class SegmentedRecording: ObservableObject {
    let id = UUID()
    let startDate: Date
    let baseFileName: String
    
    @Published var segments: [AudioSegment] = []
    @Published var isRecording: Bool = false
    @Published var totalDuration: TimeInterval = 0
    @Published var combinedTranscription: String = ""
    
    init(baseFileName: String) {
        self.startDate = Date()
        self.baseFileName = baseFileName
    }
    
    func addSegment(_ segment: AudioSegment) {
        segments.append(segment)
        totalDuration = segments.last?.endTime ?? 0
    }
    
    func updateCombinedTranscription() {
        combinedTranscription = segments
            .sorted(by: { $0.startTime < $1.startTime })
            .compactMap { $0.transcription }
            .joined(separator: " ")
    }
}

// the main audio service - does all the heavy lifting for recording and transcription
@MainActor
class AudioService: ObservableObject {
    // core audio components
    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    // published properties that UI can observe
    @Published var isRecording = false
    @Published var transcribedText = ""
    @Published var isTranscribing = false
    @Published var permissionStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    @Published var microphonePermissionGranted = false
    @Published var initializationError: String?
    @Published var audioLevel: Float = 0.0
    @Published var isBackgroundRecording: Bool = false
    
    // MARK: - Segmentation Properties
    @Published var currentSegmentedRecording: SegmentedRecording?
    @Published var currentSegmentIndex: Int = 0
    @Published var recordingProgress: TimeInterval = 0
    
    // MARK: - SwiftData Integration
    @Published var currentRecordingSession: RecordingSession?
    private let swiftDataManager = SwiftDataManager.shared
    
    // internal state tracking
    private var currentRecordingURL: URL?
    private var segmentTimer: Timer?
    private var recordingStartTime: Date?
    private let segmentDuration: TimeInterval = 30.0 // 30 seconds
    private let logger = DebugLogger.shared
    
    #if os(iOS)
    private var audioSession: AVAudioSession = AVAudioSession.sharedInstance()
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    private var backgroundTaskTimer: Timer?
    #endif
    
    // User feedback for interruptions
    @Published var interruptionStatus: String? = nil
    
    @Published var isPaused = false
    
    private let qualityManager = AudioQualityManager.shared
    
    @Published var noiseReductionEnabled: Bool = false

    init() {
        logger.logInfo("🚀 AudioService initialization started")
        
        do {
            logger.logInfo("Creating AVAudioEngine")
            audioEngine = AVAudioEngine()
            logger.logSuccess("AVAudioEngine created successfully")
            
            logger.logInfo("Creating SFSpeechRecognizer")
            speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
            
            if speechRecognizer != nil {
                logger.logSuccess("SFSpeechRecognizer created successfully")
            } else {
                logger.logWarning("SFSpeechRecognizer is nil - speech recognition may not be available")
            }
            
            logger.logInfo("Checking permissions")
            checkPermissions()
            
            #if os(iOS)
            logger.logInfo("Setting up iOS-specific audio session")
            configureAudioSession()
            setupNotifications()
            #endif
            
            logger.logSuccess("AudioService initialization completed")
            
        } catch {
            logger.logError("AudioService initialization failed", error: error)
            DispatchQueue.main.async {
                self.initializationError = "Failed to initialize audio service: \(error.localizedDescription)"
            }
        }
    }
    
    deinit {
        #if os(iOS)
        NotificationCenter.default.removeObserver(self)
        #endif
    }
    
    // check if we have permission to record and transcribe
    private func checkPermissions() {
        logger.logInfo("🔐 Requesting speech recognition authorization...")
        SFSpeechRecognizer.requestAuthorization { [weak self] authStatus in
            DispatchQueue.main.async {
                self?.logger.logInfo("Speech recognition authorization status: \(authStatus.rawValue)")
                self?.permissionStatus = authStatus
                
                // Only request microphone permission after speech recognition is authorized
                if authStatus == .authorized {
                    self?.requestMicrophonePermission()
                } else {
                    self?.logger.logWarning("Speech recognition not authorized: \(authStatus)")
                }
            }
        }
    }
    
    // ask for microphone access - required for recording
    private func requestMicrophonePermission() {
        logger.logInfo("🎤 Requesting microphone permission...")
        if #available(iOS 17.0, macOS 14.0, *) {
            AVAudioApplication.requestRecordPermission { [weak self] granted in
                DispatchQueue.main.async {
                    self?.logger.logInfo("Microphone permission granted: \(granted)")
                    self?.microphonePermissionGranted = granted
                }
            }
        } else {
            // Use AVAudioSession for iOS 15-16 compatibility
            #if os(iOS)
            AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
                DispatchQueue.main.async {
                    self?.logger.logInfo("Microphone permission granted: \(granted)")
                    self?.microphonePermissionGranted = granted
                }
            }
            #else
            // macOS doesn't need explicit microphone permission request in the same way
            startRecording()
            #endif
        }
    }

    #if os(iOS)
    // set up audio session for background recording
    private func configureAudioSession() {
        do {
            // Configure for background recording with proper options
            try audioSession.setCategory(.playAndRecord, 
                                       mode: .default, 
                                       options: [.defaultToSpeaker, .allowBluetoothA2DP, .allowBluetooth])
            
            // Enable background audio
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            logger.logInfo("🎵 Audio session configured for background recording")
            print("Audio session configured and activated.")
        } catch {
            logger.logError("Failed to configure audio session", error: error)
            print("Failed to configure audio session: \(error.localizedDescription)")
        }
    }
    
    private func resetAudioSessionForRecording() {
        do {
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothA2DP, .allowBluetooth])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            logger.logInfo("🔄 Audio session reset for recording")
        } catch {
            logger.logError("Failed to reset audio session for recording", error: error)
        }
    }
    #endif
    
    #if os(iOS)
    private func setupNotifications() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleInterruption),
                                               name: AVAudioSession.interruptionNotification,
                                               object: nil)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleRouteChange),
                                               name: AVAudioSession.routeChangeNotification,
                                               object: nil)
    }

    @objc private func handleInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
        case .began:
            print("Audio interruption began.")
            if isRecording {
                // Pause recording instead of stopping
                pauseRecordingForInterruption()
                interruptionStatus = "⏸️ Recording paused due to interruption."
                clearInterruptionStatusAfterDelay()
            }
        case .ended:
            print("Audio interruption ended.")
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else { return }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            if options.contains(.shouldResume) {
                if isRecording {
                    resumeRecordingAfterInterruption()
                    interruptionStatus = "▶️ Recording resumed after interruption."
                    clearInterruptionStatusAfterDelay()
                }
            } else {
                interruptionStatus = "⚠️ Recording stopped due to interruption."
                clearInterruptionStatusAfterDelay()
            }
        @unknown default:
            break
        }
    }
    
    @objc private func handleRouteChange(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        switch reason {
        case .oldDeviceUnavailable:
            if isRecording {
                interruptionStatus = "🎧 Input device removed. Recording stopped."
                clearInterruptionStatusAfterDelay()
                stopRecording()
            }
        case .newDeviceAvailable:
            interruptionStatus = "🎧 New input device available."
            clearInterruptionStatusAfterDelay()
        default:
            break
        }
    }

    private func isInputAvailable() -> Bool {
        #if os(iOS)
        return audioSession.availableInputs?.contains(where: { $0.portType == .builtInMic || $0.portType == .headsetMic || $0.portType == .bluetoothHFP }) ?? false
        #else
        return true
        #endif
    }

    private func pauseRecordingForInterruption() {
        // For now, just stop the audio engine and mark as paused
        if let audioEngine = audioEngine, audioEngine.isRunning {
            audioEngine.pause()
            DispatchQueue.main.async {
                self.isRecording = false
                // TODO: Add user feedback (e.g., show alert or banner)
            }
        }
    }

    private func resumeRecordingAfterInterruption() {
        // Try to resume audio engine if possible
        if let audioEngine = audioEngine, !audioEngine.isRunning {
            do {
                try audioEngine.start()
                DispatchQueue.main.async {
                    self.isRecording = true
                    // TODO: Add user feedback (e.g., show alert or banner)
                }
            } catch {
                print("Failed to resume audio engine: \(error)")
                stopRecording()
            }
        }
    }

    private func clearInterruptionStatusAfterDelay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.interruptionStatus = nil
        }
    }
    #endif

    // MARK: - Background Recording Support
    
    #if os(iOS)
    private func startBackgroundTask() {
        guard backgroundTaskID == .invalid else { return }
        
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "AudioRecording") { [weak self] in
            self?.endBackgroundTask()
        }
        
        logger.logInfo("🔄 Background task started: \(backgroundTaskID.rawValue)")
        
        // Set up a timer to extend background time if needed
        backgroundTaskTimer = Timer.scheduledTimer(withTimeInterval: 25.0, repeats: true) { [weak self] _ in
            self?.extendBackgroundTask()
        }
        
        DispatchQueue.main.async {
            self.isBackgroundRecording = true
        }
    }
    
    private func endBackgroundTask() {
        guard backgroundTaskID != .invalid else { return }
        
        backgroundTaskTimer?.invalidate()
        backgroundTaskTimer = nil
        
        UIApplication.shared.endBackgroundTask(backgroundTaskID)
        logger.logInfo("🔄 Background task ended: \(backgroundTaskID.rawValue)")
        backgroundTaskID = .invalid
        
        DispatchQueue.main.async {
            self.isBackgroundRecording = false
        }
    }
    
    private func extendBackgroundTask() {
        guard backgroundTaskID != .invalid else { return }
        
        let remainingTime = UIApplication.shared.backgroundTimeRemaining
        logger.logInfo("⏰ Background time remaining: \(remainingTime) seconds")
        
        // If we're running low on background time, try to extend
        if remainingTime < 30.0 {
            logger.logWarning("⚠️ Low background time remaining, attempting to extend")
            // The system will automatically extend if we're actively recording
        }
    }
    #endif

    // MARK: - 30-Second Segmented Recording
    
    func startSegmentedRecording() {
        logger.logInfo("🎙️ Starting 30-second segmented recording...")
        
        guard permissionStatus == .authorized else {
            logger.logWarning("Speech recognition not authorized")
            return
        }
        
        guard microphonePermissionGranted else {
            logger.logWarning("Microphone permission not granted")
            return
        }
        
        // Start background task for recording
        #if os(iOS)
        startBackgroundTask()
        resetAudioSessionForRecording()
        #endif
        resetAudioEngine()
        
        guard let audioEngine = audioEngine else {
            logger.logError("AudioEngine is nil - cannot start segmented recording")
            return
        }
        
        // Stop any existing recording first
        if audioEngine.isRunning {
            logger.logInfo("Stopping existing recording")
            stopSegmentedRecording()
        }
        
        // Create new segmented recording
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: Date())
        let baseFileName = "AudioTranscriber_Recording_\(timestamp)"
        
        // Create both legacy and SwiftData recordings for compatibility
        currentSegmentedRecording = SegmentedRecording(baseFileName: baseFileName)
        currentRecordingSession = swiftDataManager.createSession(baseFileName: baseFileName)
        
        currentSegmentIndex = 0
        recordingStartTime = Date()
        recordingProgress = 0
        
        // Start the first segment using the same method as legacy recording
        startFirstSegment()
        
        // Start the segment timer
        startSegmentTimer()
        
        DispatchQueue.main.async {
            self.isRecording = true
            self.currentSegmentedRecording?.isRecording = true
            
            // Update widget with recording status
            self.updateWidgetData()
            self.transcribedText = "" // Clear only when starting a new segmented recording
        }
    }
    
    func stopSegmentedRecording() {
        logger.logInfo("⏹️ Stopping segmented recording...")
        
        // End background task
        #if os(iOS)
        endBackgroundTask()
        #endif
        
        // Stop the segment timer
        segmentTimer?.invalidate()
        segmentTimer = nil
        
        // Stop the current segment
        stopCurrentSegment()
        
        // Mark session as completed in SwiftData
        if let session = currentRecordingSession {
            swiftDataManager.markSessionCompleted(session)
        }
        
        // Process all segments for transcription (no combined files)
        if let recording = currentSegmentedRecording {
            processSegmentsForTranscriptionOnly(recording)
        }
        
        DispatchQueue.main.async {
            self.isRecording = false
            self.currentSegmentedRecording?.isRecording = false
            // Update widget with completed recording
            self.updateWidgetData()
        }
        
        logger.logSuccess("Segmented recording stopped successfully")
    }
    
    private func startSegmentTimer() {
        segmentTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let startTime = self.recordingStartTime else { return }
            
            let elapsed = Date().timeIntervalSince(startTime)
            self.recordingProgress = elapsed
            
            // Check if we need to start a new segment
            let currentSegmentTime = elapsed - (Double(self.currentSegmentIndex) * self.segmentDuration)
            
            // Only start next segment if current segment has reached 30 seconds AND we're still recording
            if currentSegmentTime >= self.segmentDuration && self.isRecording {
                self.logger.logInfo("⏰ Segment \(self.currentSegmentIndex + 1) completed, starting next segment")
                self.stopCurrentSegment()
                self.currentSegmentIndex += 1
                self.startNewSegment()
            }
        }
    }
    
    private func startFirstSegment() {
        logger.logInfo("🎬 Starting first segment using legacy recording method")
        
        guard let audioEngine = audioEngine else {
            logger.logError("AudioEngine is nil - cannot start segment")
            return
        }
        
        logger.logInfo("Getting input node")
        let inputNode = audioEngine.inputNode
        
        // ALWAYS use the input node's native format - this is the key fix!
        let nativeFormat = inputNode.outputFormat(forBus: 0)
        logger.logInfo("📊 Using native input format: \(nativeFormat.description)")

        // Connect the input to the main mixer using the native format
        audioEngine.connect(inputNode, to: audioEngine.mainMixerNode, format: nativeFormat)

        // Get documents directory
        let documentPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        // Create segment filename with timestamp and segment number
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: Date())
        // Use .caf extension for native format compatibility
        let fileName = "AudioTranscriber_Recording_\(timestamp)_segment_\(String(format: "%03d", currentSegmentIndex + 1)).caf"
        
        let segmentURL = documentPath.appendingPathComponent(fileName)
        currentRecordingURL = segmentURL
        
        logger.logInfo("📁 Recording segment to: \(segmentURL.path)")
        logger.logInfo("📂 Documents directory: \(documentPath.path)")
        logger.logInfo("🎵 Segment file name: \(fileName)")
        
        // Also try to create a symbolic link or copy to the project recordings folder for easy access
        createProjectRecordingsCopy(audioFileURL: segmentURL, fileName: fileName)

        do {
            // Use native format for the audio file too - this ensures compatibility
            audioFile = try AVAudioFile(forWriting: segmentURL, settings: nativeFormat.settings)
            
            // Setup real-time transcription
            startRealTimeTranscription(format: nativeFormat)

            // Install tap with the native format - this is crucial!
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: nativeFormat) { [weak self] (buffer, when) in
                guard let self = self else { return }
                var processedBuffer = buffer
                if self.noiseReductionEnabled {
                    processedBuffer = self.applyNoiseReduction(to: buffer)
                }
                do {
                    try self.audioFile?.write(from: processedBuffer)
                    // Feed buffer to speech recognizer
                    self.recognitionRequest?.append(processedBuffer)
                    // Calculate audio level for visualization
                    self.updateAudioLevel(from: processedBuffer)
                } catch {
                    self.logger.logError("Error writing buffer to segment file", error: error)
                }
            }

            audioEngine.prepare()
            try audioEngine.start()

        } catch {
            logger.logError("Error starting segment recording", error: error)
            stopSegmentedRecording()
        }
    }
    
    private func startNewSegment() {
        logger.logInfo("🎬 Starting segment \(currentSegmentIndex + 1)")
        
        guard let audioEngine = audioEngine else {
            logger.logError("AudioEngine is nil - cannot start segment")
            return
        }
        
        // Stop any existing recording first
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        
        logger.logInfo("Getting input node")
        let inputNode = audioEngine.inputNode
        
        // ALWAYS use the input node's native format - this is the key fix!
        let nativeFormat = inputNode.outputFormat(forBus: 0)
        logger.logInfo("📊 Using native input format: \(nativeFormat.description)")

        // Connect the input to the main mixer using the native format
        audioEngine.connect(inputNode, to: audioEngine.mainMixerNode, format: nativeFormat)

        // Get documents directory
        let documentPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        // Create segment filename with timestamp and segment number
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: recordingStartTime!)
        // Use .caf extension for native format compatibility
        let fileName = "AudioTranscriber_Recording_\(timestamp)_segment_\(String(format: "%03d", currentSegmentIndex + 1)).caf"
        
        let segmentURL = documentPath.appendingPathComponent(fileName)
        currentRecordingURL = segmentURL
        
        logger.logInfo("📁 Recording segment to: \(segmentURL.path)")
        logger.logInfo("📂 Documents directory: \(documentPath.path)")
        logger.logInfo("🎵 Segment file name: \(fileName)")
        
        // Also try to create a symbolic link or copy to the project recordings folder for easy access
        createProjectRecordingsCopy(audioFileURL: segmentURL, fileName: fileName)

        do {
            // Use native format for the audio file too - this ensures compatibility
            audioFile = try AVAudioFile(forWriting: segmentURL, settings: nativeFormat.settings)
            
            // Setup real-time transcription
            startRealTimeTranscription(format: nativeFormat)

            // Install tap with the native format - this is crucial!
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: nativeFormat) { [weak self] (buffer, when) in
                guard let self = self else { return }
                var processedBuffer = buffer
                if self.noiseReductionEnabled {
                    processedBuffer = self.applyNoiseReduction(to: buffer)
                }
                do {
                    try self.audioFile?.write(from: processedBuffer)
                    // Feed buffer to speech recognizer
                    self.recognitionRequest?.append(processedBuffer)
                    // Calculate audio level for visualization
                    self.updateAudioLevel(from: processedBuffer)
                } catch {
                    self.logger.logError("Error writing buffer to segment file", error: error)
                }
            }
            
            audioEngine.prepare()
            try audioEngine.start()
            
        } catch {
            logger.logError("Error starting segment recording", error: error)
            stopSegmentedRecording()
        }
    }
    
    private func stopCurrentSegment() {
        logger.logInfo("⏹️ Stopping segment \(currentSegmentIndex + 1)...")
        
        guard let audioEngine = audioEngine else { return }
        if audioEngine.isRunning {
            logger.logInfo("Stopping audio engine")
            audioEngine.stop()
            logger.logInfo("Removing tap from input node")
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        
        // Stop transcription for this segment
        logger.logInfo("Stopping real-time transcription")
        stopRealTimeTranscription()
        
        audioFile = nil
        
        // Save the segment using the same method as legacy recording
        if let segmentURL = currentRecordingURL {
            let startTime = Double(currentSegmentIndex) * segmentDuration
            let actualDuration = min(segmentDuration, recordingProgress - startTime)
            
            // Save to legacy recording
            let segment = AudioSegment(
                url: segmentURL,
                startTime: startTime,
                duration: actualDuration
            )
            currentSegmentedRecording?.addSegment(segment)
            
            // Save to SwiftData
            if let session = currentRecordingSession {
                _ = swiftDataManager.addSegment(
                    to: session,
                    segmentIndex: currentSegmentIndex,
                    startTime: startTime,
                    duration: actualDuration,
                    fileURL: segmentURL
                )
            }
            
            // Encrypt the segment file - same as legacy recording
            do {
                try AudioEncryptionService.shared.encryptFile(at: segmentURL)
                logger.logSuccess("🔒 Segment encrypted at: \(segmentURL.lastPathComponent)")
            } catch {
                logger.logError("Failed to encrypt segment file", error: error)
            }
            
            // Use the exact same method as legacy recording
            convertAndCopyRecording(cafURL: segmentURL)
            
            logger.logSuccess("Segment \(currentSegmentIndex + 1) stopped successfully")
        }
        
        // Note: currentSegmentIndex is incremented in the timer, not here
    }
    

    
    private func processSegmentsForTranscriptionOnly(_ recording: SegmentedRecording) {
        logger.logInfo("🔄 Processing \(recording.segments.count) segments for transcription...")
        
        let dispatchGroup = DispatchGroup()
        
        for (index, segment) in recording.segments.enumerated() {
            dispatchGroup.enter()
            
            DispatchQueue.main.async {
                recording.segments[index].isTranscribing = true
            }
            
            // Use the unified transcription service
            TranscriptionService.shared.transcribeAudio(fileURL: segment.url) { [weak self] result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let transcription, let method):
                        recording.segments[index].transcription = transcription
                        // Update SwiftData segment
                        if let session = self?.currentRecordingSession,
                           index < session.segments.count {
                            let swiftDataSegment = session.segments[index]
                            let transcriptionMethod = method
                            self?.swiftDataManager.updateSegmentTranscription(swiftDataSegment, transcription: transcription, method: transcriptionMethod)
                        }
                        self?.logger.logInfo("✅ Transcribed segment \(index + 1)/\(recording.segments.count) using \(method.rawValue)")
                    case .failure(let error, let method):
                        // Fallback to local if OpenAI failed and not already local
                        if method == .openAI || method == .openAIWithFallback {
                            TranscriptionService.shared.transcribeAudio(fileURL: segment.url, method: .local) { fallbackResult in
                                DispatchQueue.main.async {
                                    switch fallbackResult {
                                    case .success(let transcription, let fallbackMethod):
                                        recording.segments[index].transcription = transcription
                                        if let session = self?.currentRecordingSession,
                                           index < session.segments.count {
                                            let swiftDataSegment = session.segments[index]
                                            self?.swiftDataManager.updateSegmentTranscription(swiftDataSegment, transcription: transcription, method: fallbackMethod)
                                        }
                                        self?.logger.logInfo("✅ Local fallback succeeded for segment \(index + 1)")
                                    case .failure(let fallbackError, _):
                                        // Store error, but do not leak error text into transcript
                                        recording.segments[index].transcription = ""
                                        if let session = self?.currentRecordingSession,
                                           index < session.segments.count {
                                            let swiftDataSegment = session.segments[index]
                                            self?.swiftDataManager.markSegmentTranscriptionFailed(swiftDataSegment, error: fallbackError)
                                        }
                                        self?.logger.logWarning("⚠️ Both OpenAI and local transcription failed for segment \(index + 1): \(fallbackError)")
                                    }
                                    recording.segments[index].isTranscribing = false
                                    recording.segments[index].transcriptionCompleted = true
                                    recording.updateCombinedTranscription()
                                    dispatchGroup.leave()
                                }
                            }
                            return // Don't call leave yet, will be called in fallback
                        } else {
                            // Already tried local, just mark as failed
                            recording.segments[index].transcription = ""
                            if let session = self?.currentRecordingSession,
                               index < session.segments.count {
                                let swiftDataSegment = session.segments[index]
                                self?.swiftDataManager.markSegmentTranscriptionFailed(swiftDataSegment, error: error)
                            }
                            self?.logger.logWarning("⚠️ Failed to transcribe segment \(index + 1) with \(method?.rawValue ?? "unknown"): \(error)")
                        }
                    }
                    recording.segments[index].isTranscribing = false
                    recording.segments[index].transcriptionCompleted = true
                    recording.updateCombinedTranscription()
                    dispatchGroup.leave()
                }
            }
        }
        
        // When all segments are processed - NO COMBINED FILE CREATION
        dispatchGroup.notify(queue: .main) {
            self.logger.logSuccess("🎉 All segments transcribed successfully")
            self.transcribedText = "" // Do not leak errors or combined text to main screen
        }
    }
    

    
    // MARK: - Legacy Single Recording (kept for compatibility)
    
    func startRecording() {
        guard hasSufficientStorage() else {
            interruptionStatus = "❌ Not enough storage to start recording."
            clearInterruptionStatusAfterDelay()
            return
        }
        // Prevent starting a new recording if already recording
        guard !isRecording else {
            logger.logWarning("Attempted to start a new recording while already recording.")
                    return
                }
        if UserDefaults.standard.bool(forKey: "useSegmentedRecording") {
            startSegmentedRecording()
        } else {
            startLegacyRecording()
        }
        self.transcribedText = "" // Clear only when starting a new recording
    }
    
    func stopRecording() {
        isPaused = false
        if UserDefaults.standard.bool(forKey: "useSegmentedRecording") {
            stopSegmentedRecording()
        } else {
            stopLegacyRecording()
        }
    }
    
    func startLegacyRecording() {
        logger.logInfo("🎙️ Starting legacy single-file recording...")
        
        guard permissionStatus == .authorized else {
            logger.logWarning("Speech recognition not authorized")
            return
        }
        
        guard microphonePermissionGranted else {
            logger.logWarning("Microphone permission not granted")
            return
        }
        
        // Start background task for recording
        #if os(iOS)
        startBackgroundTask()
        resetAudioSessionForRecording()
        #endif
        resetAudioEngine()
        
        guard let audioEngine = audioEngine else {
            logger.logError("AudioEngine is nil - cannot start recording")
            return
        }
        
        // Stop any existing recording first
        if audioEngine.isRunning {
            logger.logInfo("Stopping existing recording")
            stopLegacyRecording()
        }
        
        logger.logInfo("Getting input node")
        let inputNode = audioEngine.inputNode
        
        // ALWAYS use the input node's native format - this is the key fix!
        let nativeFormat = inputNode.outputFormat(forBus: 0)
        logger.logInfo("📊 Using native input format: \(nativeFormat.description)")

        // Connect the input to the main mixer using the native format
        audioEngine.connect(inputNode, to: audioEngine.mainMixerNode, format: nativeFormat)

        // Get documents directory
        let documentPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        // Create a more readable filename with date and time
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: Date())
        // Use .caf extension for native format compatibility
        let fileName = "AudioTranscriber_Recording_\(timestamp).caf"
        
        let audioFileURL = documentPath.appendingPathComponent(fileName)
        currentRecordingURL = audioFileURL
        
        logger.logInfo("📁 Recording to: \(audioFileURL.path)")
        logger.logInfo("📂 Documents directory: \(documentPath.path)")
        logger.logInfo("🎵 File name: \(fileName)")
        
        // Also try to create a symbolic link or copy to the project recordings folder for easy access
        createProjectRecordingsCopy(audioFileURL: audioFileURL, fileName: fileName)

        do {
            // Use native format for the audio file too - this ensures compatibility
            audioFile = try AVAudioFile(forWriting: audioFileURL, settings: nativeFormat.settings)
            
            // Setup real-time transcription
            startRealTimeTranscription(format: nativeFormat)

            // Install tap with the native format - this is crucial!
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: nativeFormat) { [weak self] (buffer, when) in
                guard let self = self else { return }
                var processedBuffer = buffer
                if self.noiseReductionEnabled {
                    processedBuffer = self.applyNoiseReduction(to: buffer)
                }
                do {
                    try self.audioFile?.write(from: processedBuffer)
                    // Feed buffer to speech recognizer
                    self.recognitionRequest?.append(processedBuffer)
                    // Calculate audio level for visualization
                    self.updateAudioLevel(from: processedBuffer)
                } catch {
                    self.logger.logError("Error writing buffer to file", error: error)
                }
            }

            audioEngine.prepare()
            try audioEngine.start()

            DispatchQueue.main.async {
                self.isRecording = true
            }

        } catch {
            logger.logError("Error starting recording", error: error)
            stopLegacyRecording()
        }
    }

    func stopLegacyRecording() {
        logger.logInfo("⏹️ Stopping legacy recording...")
        
        // End background task
        #if os(iOS)
        endBackgroundTask()
        #endif
        
        guard let audioEngine = audioEngine else {
            logger.logWarning("AudioEngine is nil during stop")
            DispatchQueue.main.async {
                self.isRecording = false
                self.audioLevel = 0.0
            }
            return
        }
        
        if audioEngine.isRunning {
            logger.logInfo("Stopping audio engine")
            audioEngine.stop()
            logger.logInfo("Removing tap from input node")
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        
        // Stop transcription
        logger.logInfo("Stopping real-time transcription")
        stopRealTimeTranscription()
        
        audioFile = nil

        DispatchQueue.main.async {
            self.isRecording = false
            self.audioLevel = 0.0
        }
        
        // Auto-convert and copy the recording
        if let recordingURL = currentRecordingURL {
            // Encrypt the file after recording
            do {
                try AudioEncryptionService.shared.encryptFile(at: recordingURL)
                logger.logSuccess("🔒 Recording encrypted at: \(recordingURL.lastPathComponent)")
            } catch {
                logger.logError("Failed to encrypt recording", error: error)
            }
            convertAndCopyRecording(cafURL: recordingURL)
        }
        
        logger.logSuccess("Legacy recording stopped successfully")
    }
    
    private func startRealTimeTranscription(format: AVAudioFormat) {
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            logger.logWarning("Speech recognizer not available")
            return
        }
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            logger.logWarning("Could not create recognition request")
            return
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        DispatchQueue.main.async {
            self.isTranscribing = true
            self.transcribedText = ""
        }
        
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            DispatchQueue.main.async {
                if let result = result {
                    self?.transcribedText = result.bestTranscription.formattedString
                }
                
                // Handle speech recognition errors gracefully
                if let error = error {
                    // Only log non-critical errors and restart if needed
                    if !error.localizedDescription.contains("Connection invalidated") {
                        self?.logger.logWarning("Speech recognition error: \(error.localizedDescription)")
                        // Restart for errors that might be recoverable
                        self?.restartSpeechRecognitionIfNeeded()
                    }
                }
                
                if error != nil || result?.isFinal == true {
                    self?.isTranscribing = false
                }
            }
        }
    }
    
    private func stopRealTimeTranscription() {
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        
        DispatchQueue.main.async {
            self.isTranscribing = false
        }
    }
    
    private func restartSpeechRecognitionIfNeeded() {
        // Only restart if we're still recording and speech recognition failed
        guard isRecording, let audioEngine = audioEngine, audioEngine.isRunning else { return }
        
        // Wait a moment before restarting to avoid rapid reconnection attempts
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self, self.isRecording else { return }
            
            // Get the current audio format from the engine
            let inputNode = audioEngine.inputNode
            let nativeFormat = inputNode.outputFormat(forBus: 0)
            
            self.logger.logInfo("🔄 Restarting speech recognition...")
            self.startRealTimeTranscription(format: nativeFormat)
        }
    }
    
    func transcribeAudioFile(url: URL, completion: @escaping (String?) -> Void) {
        // Use the unified transcription service
        TranscriptionService.shared.transcribeAudio(fileURL: url) { result in
            switch result {
            case .success(let transcription, let method):
                self.logger.logInfo("✅ Transcription completed using \(method.rawValue) for: \(url.lastPathComponent)")
                completion(transcription)
            case .failure(let error, let method):
                self.logger.logWarning("⚠️ Transcription failed with \(method?.rawValue ?? "unknown"): \(error)")
                completion("[Transcription failed: \(error)]")
            }
        }
    }
    
    func getRecordedFiles() -> [URL] {
        let documentPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        do {
            let files = try FileManager.default.contentsOfDirectory(at: documentPath, includingPropertiesForKeys: [.creationDateKey])
            
            // Filter audio files - include both combined and individual segment files
            let audioFiles = files.filter { file in
                let isAudioFile = file.pathExtension == "caf" || file.pathExtension == "m4a"
                return isAudioFile
            }
            
            // Sort by creation date, newest first
            return audioFiles.sorted { file1, file2 in
                do {
                    let date1 = try file1.resourceValues(forKeys: [.creationDateKey]).creationDate ?? Date.distantPast
                    let date2 = try file2.resourceValues(forKeys: [.creationDateKey]).creationDate ?? Date.distantPast
                    return date1 > date2
                } catch {
                    return false
                }
            }
        } catch {
            logger.logError("Error getting recorded files", error: error)
            return []
        }
    }
    
    func deleteRecording(url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
            logger.logInfo("🗑️ Deleted recording: \(url.lastPathComponent)")
        } catch {
            logger.logError("Error deleting recording", error: error)
        }
    }
    
    private func createProjectRecordingsCopy(audioFileURL: URL, fileName: String) {
        // Try to create a copy in a more accessible location for development
        guard let projectPath = findProjectPath() else {
            logger.logWarning("Could not find project path for recordings copy")
            return
        }
        
        let recordingsDir = projectPath.appendingPathComponent("Recordings")
        
        do {
            // Create recordings directory if it doesn't exist
            try FileManager.default.createDirectory(at: recordingsDir, withIntermediateDirectories: true, attributes: nil)
            
            let copyURL = recordingsDir.appendingPathComponent(fileName)
            
            // We'll copy the file after recording is complete
            // For now, just log the intended location
            logger.logInfo("📁 Recording will be copied to: \(copyURL.path)")
            
        } catch {
            logger.logError("Error creating recordings directory", error: error)
        }
    }
    
    private func findProjectPath() -> URL? {
        // Try to find the project directory by looking for the .xcodeproj file
        let currentPath = FileManager.default.currentDirectoryPath
        var searchPath = URL(fileURLWithPath: currentPath)
        
        // Search up the directory tree for AudioTranscriber.xcodeproj
        for _ in 0..<10 { // Limit search depth
            let projectFile = searchPath.appendingPathComponent("AudioTranscriber.xcodeproj")
            if FileManager.default.fileExists(atPath: projectFile.path) {
                return searchPath
            }
            searchPath = searchPath.deletingLastPathComponent()
        }
        
        // Fallback: try common development paths
        let possiblePaths = [
            "/Users/yash/Documents/Twinminds-project",
            "~/Documents/Twinminds-project".expandingTildeInPath
        ]
        
        for path in possiblePaths {
            let url = URL(fileURLWithPath: path)
            let projectFile = url.appendingPathComponent("AudioTranscriber.xcodeproj")
            if FileManager.default.fileExists(atPath: projectFile.path) {
                return url
            }
        }
        
        return nil
    }
    
    func copyRecordingToProject() {
        guard let currentRecordingURL = currentRecordingURL,
              let projectPath = findProjectPath() else {
            logger.logWarning("Cannot copy recording - missing URL or project path")
            return
        }
        
        let recordingsDir = projectPath.appendingPathComponent("Recordings")
        
        do {
            // Create recordings directory if it doesn't exist
            try FileManager.default.createDirectory(at: recordingsDir, withIntermediateDirectories: true, attributes: nil)
            
            let copyURL = recordingsDir.appendingPathComponent(currentRecordingURL.lastPathComponent)
            
            // Remove existing file if it exists
            if FileManager.default.fileExists(atPath: copyURL.path) {
                try FileManager.default.removeItem(at: copyURL)
            }
            
            // Copy the file
            try FileManager.default.copyItem(at: currentRecordingURL, to: copyURL)
            logger.logSuccess("📋 Recording copied to project folder: \(copyURL.path)")
            
        } catch {
            logger.logError("Error copying recording to project folder", error: error)
        }
    }
    
    func getRecordingsInfo() -> String {
        let documentPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let files = getRecordedFiles()
        
        var info = "📁 Recordings Information:\n"
        info += "Documents Directory: \(documentPath.path)\n"
        info += "Total recordings: \(files.count)\n\n"
        
        if files.isEmpty {
            info += "No recordings found.\n"
        } else {
            info += "Recent recordings:\n"
            for (index, file) in files.enumerated() {
                if index < 5 { // Show only recent 5
                    let size = getFileSize(url: file)
                    info += "• \(file.lastPathComponent) (\(size))\n"
                }
            }
        }
        
        return info
    }
    
    private func getFileSize(url: URL) -> String {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            if let size = attributes[.size] as? NSNumber {
                let formatter = ByteCountFormatter()
                formatter.allowedUnits = [.useKB, .useMB]
                formatter.countStyle = .file
                return formatter.string(fromByteCount: size.int64Value)
            }
        } catch {
            logger.logError("Error getting file size", error: error)
        }
        return "Unknown size"
    }
    
    private func updateAudioLevel(from buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        
        let channelDataValue = channelData
        let channelDataValueArray = stride(from: 0, to: Int(buffer.frameLength), by: buffer.stride).map { channelDataValue[$0] }
        
        let rms = sqrt(channelDataValueArray.map { $0 * $0 }.reduce(0, +) / Float(channelDataValueArray.count))
        let avgPower = 20 * log10(rms)
        let normalizedPower = max(0, (avgPower + 80) / 80) // Normalize -80dB to 0dB to 0-1 range
        
        DispatchQueue.main.async {
            self.audioLevel = min(1.0, max(0.0, normalizedPower))
        }
    }
    
    private func copySegmentToProjectFolder(segmentURL: URL) {
        guard let projectPath = findProjectPath() else {
            logger.logWarning("Could not find project path for segment copy")
            return
        }
        
        let recordingsDir = projectPath.appendingPathComponent("Recordings")
        
        do {
            // Create recordings directory if it doesn't exist
            try FileManager.default.createDirectory(at: recordingsDir, withIntermediateDirectories: true, attributes: nil)
            
            let copyURL = recordingsDir.appendingPathComponent(segmentURL.lastPathComponent)
            
            // Remove existing file if it exists
            if FileManager.default.fileExists(atPath: copyURL.path) {
                try FileManager.default.removeItem(at: copyURL)
            }
            
            // Copy the segment file
            try FileManager.default.copyItem(at: segmentURL, to: copyURL)
            logger.logSuccess("📋 Segment copied to project folder: \(copyURL.lastPathComponent)")
            
        } catch {
            logger.logError("Error copying segment to project folder", error: error)
        }
    }
    

    
    private func convertAndCopyRecording(cafURL: URL) {
        guard let projectPath = findProjectPath() else {
            logger.logWarning("Could not find project path for recording conversion")
            return
        }
        
        let recordingsDir = projectPath.appendingPathComponent("Recordings")
        
        // Create recordings directory if it doesn't exist
        do {
            try FileManager.default.createDirectory(at: recordingsDir, withIntermediateDirectories: true, attributes: nil)
        } catch {
            logger.logError("Error creating recordings directory", error: error)
            return
        }
        
        // Create MP3 filename
        let cafFileName = cafURL.deletingPathExtension().lastPathComponent
        let mp3FileName = "\(cafFileName).mp3"
        let mp3URL = recordingsDir.appendingPathComponent(mp3FileName)
        
        // Also copy the original CAF file
        let cafCopyURL = recordingsDir.appendingPathComponent(cafURL.lastPathComponent)
        
        DispatchQueue.global(qos: .background).async {
            do {
                // Copy original CAF file
                if FileManager.default.fileExists(atPath: cafCopyURL.path) {
                    try FileManager.default.removeItem(at: cafCopyURL)
                }
                try FileManager.default.copyItem(at: cafURL, to: cafCopyURL)
                
                // Convert to MP3 using ffmpeg (if available) or use AVAudioConverter
                self.convertToMP3(inputURL: cafURL, outputURL: mp3URL)
                
                DispatchQueue.main.async {
                    self.logger.logSuccess("📋 Recording saved: \(mp3FileName)")
                }
                
            } catch {
                self.logger.logError("Error copying recording", error: error)
            }
        }
    }
    
    private func convertToMP3(inputURL: URL, outputURL: URL) {
        // Try using ffmpeg first (if available)
        if convertWithFFmpeg(inputURL: inputURL, outputURL: outputURL) {
            return
        }
        
        // Fallback to AVAudioConverter (converts to M4A since iOS doesn't support MP3 encoding natively)
        convertWithAVFoundation(inputURL: inputURL, outputURL: outputURL)
    }
    
    private func convertWithFFmpeg(inputURL: URL, outputURL: URL) -> Bool {
        #if os(macOS)
        // Check if ffmpeg is available (only on macOS)
        let task = Process()
        task.launchPath = "/usr/bin/which"
        task.arguments = ["ffmpeg"]
        task.launch()
        task.waitUntilExit()
        
        guard task.terminationStatus == 0 else {
            logger.logInfo("ffmpeg not available, using native conversion")
            return false
        }
        
        // Convert using ffmpeg
        let ffmpegTask = Process()
        ffmpegTask.launchPath = "/usr/local/bin/ffmpeg"
        ffmpegTask.arguments = [
            "-i", inputURL.path,
            "-codec:a", "libmp3lame",
            "-b:a", "128k",
            "-y", // Overwrite output file
            outputURL.path
        ]
        
        do {
            try ffmpegTask.run()
            ffmpegTask.waitUntilExit()
            
            if ffmpegTask.terminationStatus == 0 {
                logger.logSuccess("🎵 Converted to MP3: \(outputURL.lastPathComponent)")
                return true
            } else {
                logger.logWarning("ffmpeg conversion failed")
                return false
            }
        } catch {
            logger.logError("Error running ffmpeg", error: error)
            return false
        }
        #else
        // Process is not available on iOS
        logger.logInfo("ffmpeg not available on iOS, using native conversion")
        return false
        #endif
    }
    
    private func convertWithAVFoundation(inputURL: URL, outputURL: URL) {
        // Create M4A file instead of MP3 (iOS native support)
        let m4aURL = outputURL.deletingPathExtension().appendingPathExtension("m4a")
        
        do {
            let asset = AVAsset(url: inputURL)
            guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
                logger.logError("Could not create export session")
                return
            }
            
            exportSession.outputURL = m4aURL
            exportSession.outputFileType = .m4a
            
            exportSession.exportAsynchronously {
                switch exportSession.status {
                case .completed:
                    self.logger.logSuccess("🎵 Converted to M4A: \(m4aURL.lastPathComponent)")
                case .failed:
                    self.logger.logError("Export failed", error: exportSession.error)
                case .cancelled:
                    self.logger.logWarning("Export was cancelled")
                default:
                    break
                }
            }
        } catch {
            logger.logError("Error during AVFoundation conversion", error: error)
        }
    }
    
    func syncAllRecordingsToProject() {
        let files = getRecordedFiles()
        for file in files {
            convertAndCopyRecording(cafURL: file)
        }
        logger.logSuccess("📂 Synced \(files.count) recordings to project folder")
    }
    
    private func resetAudioEngine() {
        guard let audioEngine = audioEngine else { return }
        if audioEngine.isRunning { audioEngine.stop() }
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.reset()
        logger.logInfo("🔄 Audio engine reset")
    }
    
    private func updateWidgetData() {
        // Get recent sessions from SwiftData
        let recentSessions = swiftDataManager.fetchRecentSessions(limit: 10)
        
        // Calculate recording duration if currently recording
        let recordingDuration: TimeInterval? = isRecording ? recordingProgress : nil
        
        // Update widget data
        WidgetDataService.shared.updateWidgetData(
            sessions: recentSessions,
            isRecording: isRecording,
            currentSessionTitle: currentRecordingSession?.baseFileName,
            recordingDuration: recordingDuration
        )
    }
    
    // MARK: - Widget Action Handling
    func checkAndHandleWidgetActions() {
        guard let action = WidgetDataService.shared.getPendingAction() else {
            return
        }
        
        print("🎯 AudioService received widget action: \(action.rawValue)")
        logger.logInfo("📱 Handling widget action: \(action.rawValue)")
        
        switch action {
        case .startRecording:
            if !isRecording {
                startRecording()
            }
        case .stopRecording:
            if isRecording {
                stopRecording()
            }
        case .toggleRecording:
            if isRecording {
                stopRecording()
            } else {
                startRecording()
            }
        }
        
        // Clear the action after handling
        WidgetDataService.shared.clearPendingAction()
    }
    
    // MARK: - Background Task Management
    private func setupBackgroundTask() {
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "AudioRecording") { [weak self] in
            self?.endBackgroundTask()
        }
    }
    
    func pauseRecording() {
        guard isRecording, !isPaused else { return }
        if let audioEngine = audioEngine, audioEngine.isRunning {
            audioEngine.pause()
            isPaused = true
            logger.logInfo("⏸️ Recording paused by user")
            interruptionStatus = "⏸️ Recording paused"
            clearInterruptionStatusAfterDelay()
        }
    }

    func resumeRecording() {
        guard isRecording, isPaused else { return }
        if let audioEngine = audioEngine, !audioEngine.isRunning {
            do {
                try audioEngine.start()
                isPaused = false
                logger.logInfo("▶️ Recording resumed by user")
                interruptionStatus = "▶️ Recording resumed"
                clearInterruptionStatusAfterDelay()
            } catch {
                logger.logError("Failed to resume audio engine", error: error)
                stopRecording()
            }
        }
    }

    // MARK: - Storage Check
    private func hasSufficientStorage(minimumRequiredMB: Int = 20) -> Bool {
        let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        if let values = try? fileURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]),
           let available = values.volumeAvailableCapacityForImportantUsage {
            return available > Int64(minimumRequiredMB) * 1024 * 1024
        }
        return true // Assume true if cannot check
    }

    // During recording, periodically check storage
    private func monitorStorageDuringRecording() {
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] timer in
            guard let self = self, self.isRecording else { timer.invalidate(); return }
            if !self.hasSufficientStorage() {
                self.stopRecording()
                self.interruptionStatus = "❌ Recording stopped: storage full."
                self.clearInterruptionStatusAfterDelay()
                timer.invalidate()
            }
        }
    }

    // Call monitorStorageDuringRecording() after starting recording
    // ... existing code ...
    // App termination handling
    func applicationWillTerminate() {
        if isRecording {
            stopRecording()
        }
    }
    // ... existing code ...

    // Scan for partial recordings and offer recovery
    @MainActor
    func checkForPartialRecordingsAndRecover() {
        let recordingsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        do {
            let files = try FileManager.default.contentsOfDirectory(at: recordingsURL, includingPropertiesForKeys: nil)
            let partials = files.filter { $0.lastPathComponent.contains("partial") }
            if !partials.isEmpty {
                interruptionStatus = "⚠️ Found partial recordings. Please review or delete."
                clearInterruptionStatusAfterDelay()
                // In a real app, you might show a UI prompt here
                print("Found partial recordings: \(partials.map { $0.lastPathComponent })")
            }
        } catch {
            print("Error scanning for partial recordings: \(error)")
        }
    }

    // When reading a file for playback or transcription, decrypt it first
    func getDecryptedAudioData(for url: URL) -> Data? {
        do {
            return try AudioEncryptionService.shared.decryptFile(at: url)
        } catch {
            logger.logError("Failed to decrypt audio file", error: error)
            return nil
        }
    }

    // MARK: - Custom Audio Processing (Noise Reduction)
    private func applyNoiseReduction(to buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer {
        guard let floatChannelData = buffer.floatChannelData else { return buffer }
        let frameLength = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        let sampleRate = buffer.format.sampleRate
        let highPassCutoff: Float = 120.0 // Hz
        let noiseGateThreshold: Float = 0.005 // Much more subtle noise reduction
        let alpha = exp(-2 * .pi * highPassCutoff / Float(sampleRate))
        let oneMinusAlpha = 1 - alpha
        let processedBuffer = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: buffer.frameCapacity)!
        processedBuffer.frameLength = buffer.frameLength
        for channel in 0..<channelCount {
            let input = floatChannelData[channel]
            let output = processedBuffer.floatChannelData![channel]
            var prevY: Float = 0
            for i in 0..<frameLength {
                // High-pass filter (simple one-pole)
                let x = input[i]
                let y = alpha * prevY + oneMinusAlpha * x
                prevY = y
                // Noise gate
                output[i] = abs(y) < noiseGateThreshold ? 0 : y
            }
        }
        return processedBuffer
    }
}

extension String {
    var expandingTildeInPath: String {
        return NSString(string: self).expandingTildeInPath
    }
}
