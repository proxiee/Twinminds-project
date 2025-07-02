import Foundation
import AVFoundation
import Speech

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
    
    private var currentRecordingURL: URL?
    private let logger = DebugLogger.shared
    
    #if os(iOS)
    private var audioSession: AVAudioSession = AVAudioSession.sharedInstance()
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
            AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
                DispatchQueue.main.async {
                    self?.logger.logInfo("Microphone permission granted: \(granted)")
                    self?.microphonePermissionGranted = granted
                }
            }
        }
    }

    #if os(iOS)
    private func configureAudioSession() {
        do {
            try audioSession.setPreferredSampleRate(44100.0)
            try audioSession.setCategory(.playAndRecord, mode: .default, options: .defaultToSpeaker)
            try audioSession.setActive(true)
            print("Audio session configured and activated.")
        } catch {
            print("Failed to configure audio session: \(error.localizedDescription)")
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

    func startRecording() {
        logger.logInfo("🎙️ Starting recording...")
        
        guard permissionStatus == .authorized else {
            logger.logWarning("Speech recognition not authorized")
            return
        }
        
        guard microphonePermissionGranted else {
            logger.logWarning("Microphone permission not granted")
            return
        }
        
        guard let audioEngine = audioEngine else {
            logger.logError("AudioEngine is nil - cannot start recording")
            return
        }
        
        // Stop any existing recording first
        if audioEngine.isRunning {
            logger.logInfo("Stopping existing recording")
            stopRecording()
        }
        
        logger.logInfo("Getting input node")
        let inputNode = audioEngine.inputNode
        
        // The format of the tap and the file
        guard let recordingFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                                  sampleRate: 44100.0,
                                                  channels: 1,
                                                  interleaved: false) else {
            print("Could not create a valid audio format.")
            self.stopRecording()
            return
        }
        
        // The format for the engine's connection
        let connectionFormat = inputNode.outputFormat(forBus: 0)

        // Explicitly connect the input to the main mixer.
        // This can sometimes resolve format inconsistencies inside the engine.
        audioEngine.connect(inputNode, to: audioEngine.mainMixerNode, format: connectionFormat)

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
            stopRecording()
        }
    }

    func stopRecording() {
        logger.logInfo("⏹️ Stopping recording...")
        
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
        
        logger.logSuccess("Recording stopped successfully")
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
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            completion(nil)
            return
        }
        
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false
        
        speechRecognizer.recognitionTask(with: request) { result, error in
            if let result = result, result.isFinal {
                completion(result.bestTranscription.formattedString)
            } else {
                completion(nil)
            }
        }
    }
    
    func getRecordedFiles() -> [URL] {
        let documentPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        do {
            let files = try FileManager.default.contentsOfDirectory(at: documentPath, includingPropertiesForKeys: [.creationDateKey])
            let cafFiles = files.filter { $0.pathExtension == "caf" }
            
            // Sort by creation date, newest first
            return cafFiles.sorted { file1, file2 in
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
}

extension String {
    var expandingTildeInPath: String {
        return NSString(string: self).expandingTildeInPath
    }
}
