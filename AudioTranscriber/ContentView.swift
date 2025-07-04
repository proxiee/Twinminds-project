import SwiftUI
import Speech

struct ContentView: View {
    @StateObject private var audioService = AudioService()
    @State private var recordedFiles: [URL] = []
    @State private var showingRecordings = false
    @State private var showingSettings = false
    @State private var showingSessions = false
    
    private let logger = DebugLogger.shared

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if let status = audioService.interruptionStatus {
                    Text(status)
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(Color.orange.opacity(0.9))
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(2)
                }
                VStack(spacing: 20) {
                    // Permission status
                    if audioService.permissionStatus != .authorized || !audioService.microphonePermissionGranted {
                        VStack {
                            Text("Permissions Required")
                                .font(.headline)
                                .foregroundColor(.red)
                            
                            Text(permissionStatusText)
                                .font(.caption)
                                .multilineTextAlignment(.center)
                                .padding()
                            
                            if !audioService.microphonePermissionGranted {
                                Text("Microphone access is also required for recording.")
                                    .font(.caption)
                                    .multilineTextAlignment(.center)
                                    .padding(.top, 4)
                            }
                        }
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    Spacer()
                    
                    // Recording mode toggle
                    SegmentationModeToggle(audioService: audioService)
                    
                    // Segmentation progress (shown during recording)
                    SegmentationProgressView(audioService: audioService)
                    
                    // Recording button and audio visualization
                    VStack(spacing: 15) {
                        HStack(spacing: 30) {
                            Button(action: {
                                if audioService.isRecording {
                                    if audioService.isPaused {
                                        audioService.resumeRecording()
                                    } else {
                                        audioService.pauseRecording()
                                    }
                                }
                            }) {
                                Image(systemName: audioService.isPaused ? "play.circle.fill" : "pause.circle.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(audioService.isPaused ? .green : .orange)
                            }
                            .disabled(!audioService.isRecording)
                            
                            Button(action: {
                                if audioService.isRecording {
                                    audioService.stopRecording()
                                } else {
                                    audioService.startRecording()
                                }
                            }) {
                                Image(systemName: audioService.isRecording ? "stop.circle.fill" : "record.circle")
                                    .font(.system(size: 80))
                                    .foregroundColor(audioService.isRecording ? .red : .blue)
                            }
                            .disabled(audioService.permissionStatus != .authorized || !audioService.microphonePermissionGranted || audioService.isPaused)
                        }
                        Text(recordingStatusText)
                            .font(.headline)
                            .padding(.top, 5)
                        
                        // Background recording indicator
                        if audioService.isBackgroundRecording {
                            HStack(spacing: 6) {
                                Image(systemName: "waveform.and.mic")
                                    .foregroundColor(.orange)
                                Text("Background recording active")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                            .padding(.top, 2)
                        }
                        
                        // Audio level visualization
                        if audioService.isRecording || audioService.audioLevel > 0 {
                            VStack(spacing: 8) {
                                Text("Audio Level")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                
                                AudioLevelView(audioService: audioService)
                                
                                Text(String(format: "%.1f%%", audioService.audioLevel * 100))
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    // Real-time transcription
                    if audioService.isRecording || !audioService.transcribedText.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Transcription:")
                                    .font(.headline)
                                if audioService.isTranscribing {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                }
                                Spacer()
                            }
                            
                            ScrollView {
                                Text(audioService.transcribedText.isEmpty ? "Say something..." : audioService.transcribedText)
                                    .font(.body)
                                    .foregroundColor(audioService.transcribedText.isEmpty ? .gray : .primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding()
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(8)
                            }
                            .frame(maxHeight: 150)
                        }
                        .padding(.horizontal)
                    }
                    
                    Spacer()
                    
                    // Debug and error info
                    if let error = audioService.initializationError {
                        VStack {
                            Text("Initialization Error")
                                .font(.headline)
                                .foregroundColor(.red)
                            Text(error)
                                .font(.caption)
                                .multilineTextAlignment(.center)
                                .padding()
                        }
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    VStack(spacing: 12) {
                        // Main actions row
                        HStack(spacing: 12) {
                            Button(action: {
                                loadRecordings()
                                showingRecordings = true
                            }) {
                                VStack {
                                    Image(systemName: "list.bullet")
                                        .font(.title2)
                                    Text("Recordings")
                                        .font(.caption)
                                }
                                .foregroundColor(.white)
                                .frame(width: 75, height: 60)
                                .background(Color.green)
                                .cornerRadius(12)
                            }
                            
                            Button(action: {
                                showingSessions = true
                            }) {
                                VStack {
                                    Image(systemName: "waveform.path")
                                        .font(.title2)
                                    Text("Sessions")
                                        .font(.caption)
                                }
                                .foregroundColor(.white)
                                .frame(width: 75, height: 60)
                                .background(Color.indigo)
                                .cornerRadius(12)
                            }
                            
                            Button(action: {
                                showingSettings = true
                            }) {
                                VStack {
                                    Image(systemName: "gearshape")
                                        .font(.title2)
                                    Text("Settings")
                                        .font(.caption)
                                }
                                .foregroundColor(.white)
                                .frame(width: 75, height: 60)
                                .background(Color.orange)
                                .cornerRadius(12)
                            }
                        }
                        
                        Text("Files: AudioTranscriber_Recording_[date].caf + .mp3/.m4a")
                            .font(.caption2)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
            }
            .padding()
            .navigationTitle("Audio Transcriber")
            .onAppear {
                AudioTranscriberApp.registerTerminationObserver(audioService: audioService)
                audioService.checkForPartialRecordingsAndRecover()
                loadRecordings()
            }
        }
        .sheet(isPresented: $showingRecordings) {
            #if os(iOS)
            if UIDevice.current.userInterfaceIdiom == .phone {
                // iPhone - use full screen navigation
                RecordingsListView(audioService: audioService, recordedFiles: $recordedFiles)
            } else {
                // iPad - use navigation view with size constraints
                NavigationView {
                    RecordingsListView(audioService: audioService, recordedFiles: $recordedFiles)
                }
                .frame(minWidth: 800, minHeight: 600)
            }
            #else
            // macOS - use navigation view with larger size
            NavigationView {
                RecordingsListView(audioService: audioService, recordedFiles: $recordedFiles)
            }
            .frame(minWidth: 1000, minHeight: 700)
            #endif
        }
        .sheet(isPresented: $showingSessions) {
            SessionListView()
        }
        .sheet(isPresented: $showingSettings) {
            TranscriptionSettingsView()
        }
    }
    
    private var recordingStatusText: String {
        if audioService.isRecording {
            return "Recording..."
        } else if audioService.permissionStatus != .authorized {
            return "Permission Required"
        } else {
            return "Tap to Record"
        }
    }
    
    private var permissionStatusText: String {
        switch audioService.permissionStatus {
        case .notDetermined:
            return "Please allow speech recognition access in Settings"
        case .denied:
            return "Speech recognition access denied. Please enable in Settings."
        case .restricted:
            return "Speech recognition access restricted"
        case .authorized:
            return "Speech recognition authorized"
        @unknown default:
            return "Unknown permission status"
        }
    }
    
    private func loadRecordings() {
        recordedFiles = audioService.getRecordedFiles()
    }
    
    private func copyDebugLogs() {
        let logs = logger.getLogFileContents()
        #if os(iOS)
        UIPasteboard.general.string = logs
        #elseif os(macOS)
        NSPasteboard.general.setString(logs, forType: .string)
        #endif
        logger.logInfo("Debug logs copied to clipboard")
    }
    
    private func copyRecordingsInfo() {
        let info = audioService.getRecordingsInfo()
        #if os(iOS)
        UIPasteboard.general.string = info
        #elseif os(macOS)
        NSPasteboard.general.setString(info, forType: .string)
        #endif
        logger.logInfo("Recordings info copied to clipboard")
    }
}


#Preview {
    ContentView()
}
