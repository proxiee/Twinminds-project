import Foundation
import AVFoundation
import Speech
import SwiftUI
#if os(iOS)
import UIKit
#endif

// MARK: - Audio Segment Data Structures
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

@MainActor
class AudioService: ObservableObject {
    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
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
                stopRecording()
            }
        case .ended:
            print("Audio interruption ended.")
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else { return }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            if options.contains(.shouldResume) {
                print("Resuming audio session.")
                do {
                    try audioSession.setActive(true)
                } catch {
                    print("Could not reactivate audio session: \(error.localizedDescription)")
                }
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
        case .newDeviceAvailable:
            print("New audio device available.")
        case .oldDeviceUnavailable:
            print("Old audio device unavailable.")
            if isRecording {
                stopRecording()
            }
        default:
            break
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
        #endif
        
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
        
        // Start the first segment
        startNewSegment()
        
        // Start the segment timer
        startSegmentTimer()
        
        DispatchQueue.main.async {
            self.isRecording = true
            self.currentSegmentedRecording?.isRecording = true
            
            // Update widget with recording status
            self.updateWidgetData()
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
        
        // Process all segments for transcription
        if let recording = currentSegmentedRecording {
            processSegmentsForTranscription(recording)
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
    
    private func startNewSegment() {
        logger.logInfo("🎬 Starting segment \(currentSegmentIndex + 1)")
        
        guard let audioEngine = audioEngine else {
            logger.logError("AudioEngine is nil - cannot start segment")
            return
        }
        
        // Reset audio session and engine for recording
        #if os(iOS)
        resetAudioSessionForRecording()
        #endif
        resetAudioEngine()
        
        // Stop any existing recording first
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        
        let inputNode = audioEngine.inputNode
        
        // Get the input node's native format to avoid format mismatches
        let inputFormat = inputNode.outputFormat(forBus: 0)
        logger.logInfo("📊 Segment input format: \(inputFormat.description)")
        
        // Use the input format for recording to avoid format mismatches
        let recordingFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                           sampleRate: inputFormat.sampleRate,
                                           channels: 1,
                                           interleaved: false) ?? inputFormat
        
        logger.logInfo("📊 Segment recording format: \(recordingFormat.description)")
        
        // Connect input to mixer using the input format
        audioEngine.connect(inputNode, to: audioEngine.mainMixerNode, format: inputFormat)
        
        // Create segment file
        guard let segmentURL = createSegmentFileURL() else {
            logger.logError("Could not create segment file URL")
            return
        }
        
        currentRecordingURL = segmentURL
        
        do {
            audioFile = try AVAudioFile(forWriting: segmentURL, settings: recordingFormat.settings)
            
            // Setup real-time transcription for this segment
            startRealTimeTranscription(format: recordingFormat)
            
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] (buffer, when) in
                do {
                    try self?.audioFile?.write(from: buffer)
                    self?.recognitionRequest?.append(buffer)
                    self?.updateAudioLevel(from: buffer)
                } catch {
                    self?.logger.logError("Error writing buffer to segment file", error: error)
                }
            }
            
            audioEngine.prepare()
            try audioEngine.start()
            
        } catch {
            logger.logError("Error starting segment recording", error: error)
        }
    }
    
    private func stopCurrentSegment() {
        guard let audioEngine = audioEngine else { return }
        
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        
        // Stop transcription for this segment
        stopRealTimeTranscription()
        
        // Save the segment
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
            
            logger.logInfo("💾 Saved segment \(currentSegmentIndex + 1): \(segmentURL.lastPathComponent)")
        }
        
        audioFile = nil
        // Note: currentSegmentIndex is incremented in the timer, not here
    }
    
    private func createSegmentFileURL() -> URL? {
        guard let recording = currentSegmentedRecording else { return nil }
        
        let documentPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let segmentFileName = "\(recording.baseFileName)_segment_\(String(format: "%03d", currentSegmentIndex + 1)).caf"
        return documentPath.appendingPathComponent(segmentFileName)
    }
    
    private func processSegmentsForTranscription(_ recording: SegmentedRecording) {
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
                        recording.segments[index].transcription = "[Transcription failed: \(error)]"
                        
                        // Update SwiftData segment with failure
                        if let session = self?.currentRecordingSession,
                           index < session.segments.count {
                            let swiftDataSegment = session.segments[index]
                            self?.swiftDataManager.markSegmentTranscriptionFailed(swiftDataSegment, error: error)
                        }
                        
                        self?.logger.logWarning("⚠️ Failed to transcribe segment \(index + 1) with \(method?.rawValue ?? "unknown"): \(error)")
                    }
                    
                    recording.segments[index].isTranscribing = false
                    recording.segments[index].transcriptionCompleted = true
                    
                    recording.updateCombinedTranscription()
                }
                dispatchGroup.leave()
            }
        }
        
        // When all segments are processed
        dispatchGroup.notify(queue: .main) {
            self.logger.logSuccess("🎉 All segments transcribed successfully")
            self.transcribedText = recording.combinedTranscription
            
            // Create a combined audio file
            self.createCombinedAudioFile(from: recording)
        }
    }
    
    private func createCombinedAudioFile(from recording: SegmentedRecording) {
        logger.logInfo("🔗 Creating combined audio file...")
        
        // If only one segment, just copy it directly
        if recording.segments.count == 1 {
            guard let segment = recording.segments.first else { return }
            
            let documentPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let combinedFileName = "\(recording.baseFileName)_combined.caf"
            let combinedURL = documentPath.appendingPathComponent(combinedFileName)
            
            DispatchQueue.global(qos: .background).async {
                do {
                    // Remove existing file if it exists
                    if FileManager.default.fileExists(atPath: combinedURL.path) {
                        try FileManager.default.removeItem(at: combinedURL)
                    }
                    
                    // Copy the single segment as the combined file
                    try FileManager.default.copyItem(at: segment.url, to: combinedURL)
                    
                    DispatchQueue.main.async {
                        self.logger.logSuccess("🎵 Combined audio file created: \(combinedFileName)")
                        self.currentRecordingURL = combinedURL
                        self.convertAndCopyRecording(cafURL: combinedURL)
                    }
                } catch {
                    self.logger.logError("Error creating combined audio file", error: error)
                }
            }
            return
        }
        
        // Multiple segments - create composition
        let documentPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let combinedFileName = "\(recording.baseFileName)_combined.caf"
        let combinedURL = documentPath.appendingPathComponent(combinedFileName)
        
        DispatchQueue.global(qos: .background).async {
            do {
                // Create composition
                let composition = AVMutableComposition()
                guard let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
                    self.logger.logError("Could not create audio track for combined file")
                    return
                }
                
                var currentTime = CMTime.zero
                
                // Add each segment to the composition
                for segment in recording.segments.sorted(by: { $0.startTime < $1.startTime }) {
                    let asset = AVAsset(url: segment.url)
                    guard let assetTrack = asset.tracks(withMediaType: .audio).first else { continue }
                    
                    let duration = CMTime(seconds: segment.duration, preferredTimescale: 600)
                    let timeRange = CMTimeRange(start: .zero, duration: duration)
                    
                    try audioTrack.insertTimeRange(timeRange, of: assetTrack, at: currentTime)
                    currentTime = CMTimeAdd(currentTime, duration)
                }
                
                // Export the combined file using compatible preset
                guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetAppleM4A) else {
                    self.logger.logError("Could not create export session for combined file")
                    return
                }
                
                // Use .m4a extension for the combined file instead of .caf
                let m4aCombinedFileName = "\(recording.baseFileName)_combined.m4a"
                let m4aCombinedURL = documentPath.appendingPathComponent(m4aCombinedFileName)
                
                exportSession.outputURL = m4aCombinedURL
                exportSession.outputFileType = .m4a
                
                // Add timeout for export session
                var hasCompleted = false
                let exportTimeoutSeconds = 60.0 // 1 minute timeout
                
                let exportTimer = Timer.scheduledTimer(withTimeInterval: exportTimeoutSeconds, repeats: false) { _ in
                    if !hasCompleted {
                        hasCompleted = true
                        exportSession.cancelExport()
                        self.logger.logWarning("Combined audio file export timed out")
                    }
                }
                
                exportSession.exportAsynchronously {
                    DispatchQueue.main.async {
                        guard !hasCompleted else { return }
                        hasCompleted = true
                        exportTimer.invalidate()
                        
                        switch exportSession.status {
                        case .completed:
                            self.logger.logSuccess("🎵 Combined audio file created: \(m4aCombinedFileName)")
                            self.currentRecordingURL = m4aCombinedURL
                            self.convertAndCopyRecording(cafURL: m4aCombinedURL)
                        case .failed:
                            self.logger.logError("Failed to create combined audio file", error: exportSession.error)
                            // Try fallback: just use the first segment as the combined file
                            if let firstSegment = recording.segments.first {
                                self.logger.logInfo("Using first segment as fallback combined file")
                                self.currentRecordingURL = firstSegment.url
                                self.convertAndCopyRecording(cafURL: firstSegment.url)
                            }
                        case .cancelled:
                            self.logger.logWarning("Combined audio file creation was cancelled")
                        default:
                            break
                        }
                    }
                }
                
            } catch {
                self.logger.logError("Error creating combined audio file", error: error)
            }
        }
    }
    
    // MARK: - Legacy Single Recording (kept for compatibility)
    
    func startRecording() {
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
    }

    func stopRecording() {
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
        
        // Get the input node's native format to avoid format mismatches
        let inputFormat = inputNode.outputFormat(forBus: 0)
        logger.logInfo("📊 Input format: \(inputFormat.description)")
        
        // Use the input format for recording to avoid format mismatches
        let recordingFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                           sampleRate: inputFormat.sampleRate,
                                           channels: 1,
                                           interleaved: false) ?? inputFormat
        
        logger.logInfo("📊 Recording format: \(recordingFormat.description)")

        // Explicitly connect the input to the main mixer using the input format
        audioEngine.connect(inputNode, to: audioEngine.mainMixerNode, format: inputFormat)

        // Get documents directory
        let documentPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        // Create a more readable filename with date and time
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: Date())
        let fileName = "AudioTranscriber_Recording_\(timestamp).caf"
        
        let audioFileURL = documentPath.appendingPathComponent(fileName)
        currentRecordingURL = audioFileURL
        
        logger.logInfo("📁 Recording to: \(audioFileURL.path)")
        logger.logInfo("📂 Documents directory: \(documentPath.path)")
        logger.logInfo("🎵 File name: \(fileName)")
        
        // Also try to create a symbolic link or copy to the project recordings folder for easy access
        createProjectRecordingsCopy(audioFileURL: audioFileURL, fileName: fileName)

        do {
            audioFile = try AVAudioFile(forWriting: audioFileURL, settings: recordingFormat.settings)
            
            // Setup real-time transcription
            startRealTimeTranscription(format: recordingFormat)

            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] (buffer, when) in
                do {
                    try self?.audioFile?.write(from: buffer)
                    // Feed buffer to speech recognizer
                    self?.recognitionRequest?.append(buffer)
                    
                    // Calculate audio level for visualization
                    self?.updateAudioLevel(from: buffer)
                } catch {
                    print("Error writing buffer to file: \(error.localizedDescription)")
                }
            }

            audioEngine.prepare()
            try audioEngine.start()

            DispatchQueue.main.async {
                self.isRecording = true
            }

        } catch {
            print("Error starting recording: \(error.localizedDescription)")
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
            convertAndCopyRecording(cafURL: recordingURL)
        }
        
        logger.logSuccess("Legacy recording stopped successfully")
    }
    
    private func startRealTimeTranscription(format: AVAudioFormat) {
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            print("Speech recognizer not available")
            return
        }
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            print("Could not create recognition request")
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
            let audioFiles = files.filter { $0.pathExtension == "caf" || $0.pathExtension == "m4a" }
            
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
}

extension String {
    var expandingTildeInPath: String {
        return NSString(string: self).expandingTildeInPath
    }
}
