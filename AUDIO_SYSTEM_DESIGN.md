# 🎵 AudioTranscriber Audio System Design

## 📋 Overview

This document details the comprehensive audio system design for the AudioTranscriber iOS application, focusing on robust handling of audio route changes, interruptions, and real-world audio challenges.

## 🎯 Audio System Architecture

### Core Audio Components
```
┌─────────────────────────────────────────────────────────────┐
│                    Audio System Architecture                │
├─────────────────────────────────────────────────────────────┤
│  AVAudioEngine  │  AVAudioSession  │  SFSpeechRecognizer   │
├─────────────────────────────────────────────────────────────┤
│  Input Node     │  Main Mixer      │  Output Node          │
├─────────────────────────────────────────────────────────────┤
│  Audio Buffer   │  Audio File      │  Audio Processing     │
└─────────────────────────────────────────────────────────────┘
```

### Audio Pipeline Flow
```
Microphone Input → Input Node → Audio Buffer → Processing → Audio File
                                    ↓
                            Speech Recognition → Real-time Transcription
```

## 🔧 Audio Session Management

### Session Configuration Strategy

#### **Primary Configuration**
```swift
private func configureAudioSession() {
    do {
        // Configure for background recording with proper options
        try audioSession.setCategory(.playAndRecord, 
                                   mode: .default, 
                                   options: [.defaultToSpeaker, .allowBluetoothA2DP, .allowBluetooth])
        
        // Enable background audio
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
    } catch {
        logger.logError("Failed to configure audio session", error: error)
    }
}
```

#### **Configuration Options Explained**
- **`.playAndRecord`**: Enables both recording and playback capabilities
- **`.defaultToSpeaker`**: Routes audio to speaker by default
- **`.allowBluetoothA2DP`**: Supports high-quality Bluetooth audio
- **`.allowBluetooth`**: Supports Bluetooth headset connections

### Session Reset Strategy
```swift
private func resetAudioSessionForRecording() {
    do {
        // Deactivate current session
        try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
        
        // Reconfigure with same settings
        try audioSession.setCategory(.playAndRecord, mode: .default, 
                                   options: [.defaultToSpeaker, .allowBluetoothA2DP, .allowBluetooth])
        
        // Reactivate session
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
    } catch {
        logger.logError("Failed to reset audio session for recording", error: error)
    }
}
```

## 🎧 Audio Route Change Handling

### Route Change Detection
```swift
@objc private func handleRouteChange(notification: Notification) {
    guard let userInfo = notification.userInfo,
          let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
          let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
        return
    }
    
    switch reason {
    case .oldDeviceUnavailable:
        handleDeviceRemoval()
    case .newDeviceAvailable:
        handleDeviceAddition()
    case .categoryChange:
        handleCategoryChange()
    case .override:
        handleOverride()
    case .wakeFromSleep:
        handleWakeFromSleep()
    case .noSuitableRouteForCategory:
        handleNoSuitableRoute()
    case .routeConfigurationChange:
        handleRouteConfigurationChange()
    @unknown default:
        handleUnknownRouteChange()
    }
}
```

### Device Removal Handling
```swift
private func handleDeviceRemoval() {
    if isRecording {
        // Check if we still have a valid input device
        if !isInputAvailable() {
            interruptionStatus = "🎧 Input device removed. Recording stopped."
            clearInterruptionStatusAfterDelay()
            stopRecording()
        } else {
            // Device was removed but we have another input available
            interruptionStatus = "🎧 Input device changed."
            clearInterruptionStatusAfterDelay()
        }
    }
}
```

### Device Addition Handling
```swift
private func handleDeviceAddition() {
    interruptionStatus = "🎧 New input device available."
    clearInterruptionStatusAfterDelay()
    
    // Optionally switch to new device if it's preferred
    if let preferredInput = getPreferredInputDevice() {
        switchToInputDevice(preferredInput)
    }
}
```

### Input Device Validation
```swift
private func isInputAvailable() -> Bool {
    #if os(iOS)
    return audioSession.availableInputs?.contains(where: { 
        $0.portType == .builtInMic || 
        $0.portType == .headsetMic || 
        $0.portType == .bluetoothHFP 
    }) ?? false
    #else
    return true
    #endif
}
```

## 📞 Audio Interruption Handling

### Interruption Detection
```swift
@objc private func handleInterruption(notification: Notification) {
    guard let userInfo = notification.userInfo,
          let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
          let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
        return
    }
    
    switch type {
    case .began:
        handleInterruptionBegan()
    case .ended:
        handleInterruptionEnded(userInfo: userInfo)
    @unknown default:
        handleUnknownInterruption()
    }
}
```

### Interruption Began Handling
```swift
private func handleInterruptionBegan() {
    print("Audio interruption began.")
    if isRecording {
        // Pause recording instead of stopping
        pauseRecordingForInterruption()
        interruptionStatus = "⏸️ Recording paused due to interruption."
        clearInterruptionStatusAfterDelay()
    }
}
```

### Interruption Ended Handling
```swift
private func handleInterruptionEnded(userInfo: [AnyHashable: Any]) {
    print("Audio interruption ended.")
    guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else { 
        return 
    }
    
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
}
```

### Pause/Resume Strategy
```swift
private func pauseRecordingForInterruption() {
    if let audioEngine = audioEngine, audioEngine.isRunning {
        audioEngine.pause()
        DispatchQueue.main.async {
            self.isRecording = false
            self.isPaused = true
        }
    }
}

private func resumeRecordingAfterInterruption() {
    if let audioEngine = audioEngine, !audioEngine.isRunning {
        do {
            try audioEngine.start()
            DispatchQueue.main.async {
                self.isRecording = true
                self.isPaused = false
            }
        } catch {
            print("Failed to resume audio engine: \(error)")
            stopRecording()
        }
    }
}
```

## 🎙️ Recording Architecture

### Dual Recording Modes

#### **Segmented Recording (30-second chunks)**
```swift
func startSegmentedRecording() {
    // Create new segmented recording session
    currentSegmentedRecording = SegmentedRecording(baseFileName: baseFileName)
    currentRecordingSession = swiftDataManager.createSession(baseFileName: baseFileName)
    
    // Start first segment
    startFirstSegment()
    
    // Start segment timer
    startSegmentTimer()
}
```

#### **Legacy Recording (single file)**
```swift
func startLegacyRecording() {
    // Single continuous recording
    let fileName = "AudioTranscriber_Recording_\(timestamp).caf"
    let audioFileURL = documentPath.appendingPathComponent(fileName)
    
    // Setup audio file and start recording
    audioFile = try AVAudioFile(forWriting: audioFileURL, settings: nativeFormat.settings)
    startRealTimeTranscription(format: nativeFormat)
}
```

### Audio Format Strategy

#### **Native Format Usage**
```swift
// ALWAYS use the input node's native format - this is the key fix!
let nativeFormat = inputNode.outputFormat(forBus: 0)
logger.logInfo("📊 Using native input format: \(nativeFormat.description)")

// Connect the input to the main mixer using the native format
audioEngine.connect(inputNode, to: audioEngine.mainMixerNode, format: nativeFormat)

// Use native format for the audio file too
audioFile = try AVAudioFile(forWriting: segmentURL, settings: nativeFormat.settings)
```

**Why Native Format?**
- **Compatibility**: Ensures compatibility with all input devices
- **Performance**: No format conversion overhead
- **Reliability**: Reduces audio glitches and dropouts
- **Quality**: Preserves original audio quality

### Audio Buffer Processing
```swift
inputNode.installTap(onBus: 0, bufferSize: 1024, format: nativeFormat) { [weak self] (buffer, when) in
    guard let self = self else { return }
    
    var processedBuffer = buffer
    
    // Apply noise reduction if enabled
    if self.noiseReductionEnabled {
        processedBuffer = self.applyNoiseReduction(to: buffer)
    }
    
    do {
        // Write to audio file
        try self.audioFile?.write(from: processedBuffer)
        
        // Feed buffer to speech recognizer
        self.recognitionRequest?.append(processedBuffer)
        
        // Calculate audio level for visualization
        self.updateAudioLevel(from: processedBuffer)
    } catch {
        self.logger.logError("Error writing buffer to file", error: error)
    }
}
```

## 🔄 Background Recording Support

### Background Task Management
```swift
private func startBackgroundTask() {
    guard backgroundTaskID == .invalid else { return }
    
    backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "AudioRecording") { [weak self] in
        self?.endBackgroundTask()
    }
    
    // Set up timer to extend background time
    backgroundTaskTimer = Timer.scheduledTimer(withTimeInterval: 25.0, repeats: true) { [weak self] _ in
        self?.extendBackgroundTask()
    }
}
```

### Background Time Extension
```swift
private func extendBackgroundTask() {
    guard backgroundTaskID != .invalid else { return }
    
    let remainingTime = UIApplication.shared.backgroundTimeRemaining
    logger.logInfo("⏰ Background time remaining: \(remainingTime) seconds")
    
    if remainingTime < 30.0 {
        logger.logWarning("⚠️ Low background time remaining, attempting to extend")
    }
}
```

## 🎛️ Audio Processing

### Noise Reduction Algorithm
```swift
private func applyNoiseReduction(to buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer {
    guard let floatChannelData = buffer.floatChannelData else { return buffer }
    
    let frameLength = Int(buffer.frameLength)
    let channelCount = Int(buffer.format.channelCount)
    let sampleRate = buffer.format.sampleRate
    
    // Processing parameters
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
```

### Audio Level Monitoring
```swift
private func updateAudioLevel(from buffer: AVAudioPCMBuffer) {
    guard let channelData = buffer.floatChannelData?[0] else { return }
    
    let channelDataValue = channelData
    let channelDataValueArray = stride(from: 0, to: Int(buffer.frameLength), by: buffer.stride)
        .map { channelDataValue[$0] }
    
    // Calculate RMS (Root Mean Square)
    let rms = sqrt(channelDataValueArray.map { $0 * $0 }.reduce(0, +) / Float(channelDataValueArray.count))
    
    // Convert to dB
    let avgPower = 20 * log10(rms)
    
    // Normalize -80dB to 0dB to 0-1 range
    let normalizedPower = max(0, (avgPower + 80) / 80)
    
    DispatchQueue.main.async {
        self.audioLevel = min(1.0, max(0.0, normalizedPower))
    }
}
```

## 🎤 Real-time Transcription Integration

### Speech Recognition Setup
```swift
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
    
    recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
        DispatchQueue.main.async {
            if let result = result {
                self?.transcribedText = result.bestTranscription.formattedString
            }
            
            if let error = error {
                self?.handleSpeechRecognitionError(error)
            }
            
            if error != nil || result?.isFinal == true {
                self?.isTranscribing = false
            }
        }
    }
}
```

### Speech Recognition Error Handling
```swift
private func handleSpeechRecognitionError(_ error: Error) {
    // Only log non-critical errors and restart if needed
    if !error.localizedDescription.contains("Connection invalidated") {
        logger.logWarning("Speech recognition error: \(error.localizedDescription)")
        restartSpeechRecognitionIfNeeded()
    }
}

private func restartSpeechRecognitionIfNeeded() {
    guard isRecording, let audioEngine = audioEngine, audioEngine.isRunning else { return }
    
    // Wait a moment before restarting to avoid rapid reconnection attempts
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
        guard let self = self, self.isRecording else { return }
        
        let inputNode = audioEngine.inputNode
        let nativeFormat = inputNode.outputFormat(forBus: 0)
        
        self.logger.logInfo("🔄 Restarting speech recognition...")
        self.startRealTimeTranscription(format: nativeFormat)
    }
}
```

## 🔒 Audio Security

### File Encryption
```swift
// Encrypt audio files after recording
do {
    try AudioEncryptionService.shared.encryptFile(at: recordingURL)
    logger.logSuccess("🔒 Recording encrypted at: \(recordingURL.lastPathComponent)")
} catch {
    logger.logError("Failed to encrypt recording", error: error)
}
```

### Decryption for Playback
```swift
func getDecryptedAudioData(for url: URL) -> Data? {
    do {
        return try AudioEncryptionService.shared.decryptFile(at: url)
    } catch {
        logger.logError("Failed to decrypt audio file", error: error)
        return nil
    }
}
```

## 📊 Performance Optimization

### Memory Management
- **Buffer Size**: 1024 samples for optimal performance
- **Temporary File Cleanup**: Automatic cleanup after processing
- **Background Processing**: Non-blocking UI operations

### Battery Optimization
- **Efficient DSP**: Optimized noise reduction algorithms
- **Background Task Limits**: Proper iOS background execution
- **Audio Session Management**: Minimal session changes

### Storage Optimization
- **Native Format**: No unnecessary format conversions
- **Compression**: Automatic file compression
- **Cleanup Policies**: Automatic old file removal

## 🧪 Testing Strategy

### Audio System Testing
1. **Route Change Testing**: Test all audio route change scenarios
2. **Interruption Testing**: Test phone calls, Siri, notifications
3. **Background Testing**: Test background recording functionality
4. **Format Testing**: Test with different audio formats and devices

### Performance Testing
1. **Memory Usage**: Monitor memory consumption during recording
2. **Battery Impact**: Measure battery usage during extended recording
3. **Audio Quality**: Verify audio quality across different devices
4. **Latency Testing**: Measure transcription latency

## 🔮 Future Enhancements

### Planned Audio Improvements
1. **Advanced Noise Reduction**: Machine learning-based noise reduction
2. **Audio Enhancement**: AI-powered audio enhancement
3. **Multi-channel Support**: Support for stereo recording
4. **Custom Audio Filters**: User-configurable audio filters

### Technical Improvements
1. **Audio Unit Integration**: Custom audio processing units
2. **Real-time Effects**: Real-time audio effects and processing
3. **Audio Analytics**: Advanced audio analysis and insights
4. **Cloud Audio Processing**: Server-side audio processing

---

**This audio system design document provides a comprehensive overview of the audio architecture and should be referenced when making changes to the audio system.** 