import SwiftUI
import AVFoundation
#if os(macOS)
import AppKit
#endif

enum TranscriptStatus {
    case notGenerated
    case generating
    case available
    case failed
}

struct RecordingsListView: View {
    @ObservedObject var audioService: AudioService
    @Binding var recordedFiles: [URL]
    @State private var selectedFileTranscription = ""
    @State private var isTranscribingFile = false
    @State private var selectedFile: URL?
    @State private var isPlaying = false
    @State private var audioPlayer: AVAudioPlayer?
    @State private var showingTranscription = false
    @State private var currentTime: Double = 0
    @State private var duration: Double = 0
    @State private var playbackTimer: Timer?
    @State private var transcriptCache: [URL: String] = [:]
    @State private var transcriptStatus: [URL: TranscriptStatus] = [:]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        GeometryReader { geometry in
            #if os(iOS)
            // Mobile layout - use tabs or navigation for better UX
            if UIDevice.current.userInterfaceIdiom == .phone {
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("Recordings")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        Text("\(recordedFiles.count) files")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Button(action: {
                            stopPlayback()
                            dismiss()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(.secondarySystemBackground))
                    
                    if selectedFile == nil {
                        // Show recordings list when no file is selected
                        if recordedFiles.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "waveform.circle")
                                    .font(.system(size: 64))
                                    .foregroundColor(.gray.opacity(0.5))
                                
                                Text("No recordings yet")
                                    .font(.title3)
                                    .foregroundColor(.gray)
                                
                                Text("Start recording to see your audio files here")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            ScrollView {
                                LazyVStack(spacing: 8) {
                                    ForEach(recordedFiles, id: \.self) { file in
                                        EnhancedRecordingRowView(
                                            file: file,
                                            audioService: audioService,
                                            selectedFile: $selectedFile,
                                            selectedFileTranscription: $selectedFileTranscription,
                                            isTranscribingFile: $isTranscribingFile,
                                            isPlaying: $isPlaying,
                                            audioPlayer: $audioPlayer,
                                            currentTime: $currentTime,
                                            duration: $duration,
                                            playbackTimer: $playbackTimer,
                                            recordedFiles: $recordedFiles,
                                            onFileSelected: { selectedFile in
                                                loadTranscriptForFile(selectedFile)
                                            }
                                        )
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                            }
                        }
                    } else {
                        // Show player when file is selected
                        VStack(spacing: 0) {
                            // Back button and file info
                            HStack {
                                Button(action: {
                                    selectedFile = nil
                                    stopPlayback()
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "chevron.left")
                                        Text("Back")
                                    }
                                    .font(.body)
                                    .foregroundColor(.accentColor)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("Now Playing")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Text(selectedFile!.lastPathComponent.replacingOccurrences(of: ".caf", with: ""))
                                        .font(.caption)
                                        .lineLimit(1)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color(.secondarySystemBackground))
                            
                            Divider()
                            
                            // Audio player controls
                            AudioPlayerView(
                                isPlaying: $isPlaying,
                                currentTime: $currentTime,
                                duration: $duration,
                                audioPlayer: audioPlayer,
                                onSeek: { time in
                                    audioPlayer?.currentTime = time
                                    currentTime = time
                                }
                            )
                            .padding(.horizontal, 16)
                            .padding(.vertical, 16)
                            
                            Divider()
                            
                            // Transcript section
                            TranscriptView(
                                selectedFile: selectedFile!,
                                transcription: selectedFileTranscription,
                                isTranscribing: isTranscribingFile,
                                audioService: audioService,
                                onTranscribe: {
                                    transcribeSelectedFile()
                                }
                            )
                        }
                    }
                }
            } else {
                // iPad layout - use side-by-side
                tabletLayout(geometry: geometry)
            }
            #else
            // macOS layout
            tabletLayout(geometry: geometry)
            #endif
        }
        .onDisappear {
            stopPlayback()
        }
        .onAppear {
            // Refresh recordings when view appears
            recordedFiles = audioService.getRecordedFiles()
        }
        // .onKeyPress(.escape) - iOS 17+ only
    }
    
    // Tablet/Desktop layout function
    @ViewBuilder
    private func tabletLayout(geometry: GeometryProxy) -> some View {
        HStack(spacing: 0) {
            // Left side - Recordings list
            VStack(spacing: 0) {
                // Header with close button
                HStack {
                    Text("Recordings")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Text("\(recordedFiles.count) files")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer().frame(width: 16)
                    
                    Button(action: {
                        stopPlayback()
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Close (ESC)")
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color(.secondarySystemBackground))
                
                Divider()
                
                // Recordings list
                if recordedFiles.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "waveform.circle")
                            .font(.system(size: 64))
                            .foregroundColor(.gray.opacity(0.5))
                        
                        Text("No recordings yet")
                            .font(.title3)
                            .foregroundColor(.gray)
                        
                        Text("Start recording to see your audio files here")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 1) {
                            ForEach(recordedFiles, id: \.self) { file in
                                EnhancedRecordingRowView(
                                    file: file,
                                    audioService: audioService,
                                    selectedFile: $selectedFile,
                                    selectedFileTranscription: $selectedFileTranscription,
                                    isTranscribingFile: $isTranscribingFile,
                                    isPlaying: $isPlaying,
                                    audioPlayer: $audioPlayer,
                                    currentTime: $currentTime,
                                    duration: $duration,
                                    playbackTimer: $playbackTimer,
                                    recordedFiles: $recordedFiles,
                                    onFileSelected: { selectedFile in
                                        loadTranscriptForFile(selectedFile)
                                    }
                                )
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .frame(width: geometry.size.width * 0.45)
            .background(Color(.systemBackground))
            
            Divider()
            
            // Right side - Player and transcript
            VStack(spacing: 0) {
                if let selectedFile = selectedFile {
                    // Player header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Now Playing")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(selectedFile.lastPathComponent.replacingOccurrences(of: ".caf", with: ""))
                                .font(.headline)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        Button(action: { 
                            self.selectedFile = nil 
                            stopPlayback()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(Color(.secondarySystemBackground))
                    
                    Divider()
                    
                    // Audio player controls
                    AudioPlayerView(
                        isPlaying: $isPlaying,
                        currentTime: $currentTime,
                        duration: $duration,
                        audioPlayer: audioPlayer,
                        onSeek: { time in
                            audioPlayer?.currentTime = time
                            currentTime = time
                        }
                    )
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    
                    Divider()
                    
                    // Transcript section
                    TranscriptView(
                        selectedFile: selectedFile,
                        transcription: selectedFileTranscription,
                        isTranscribing: isTranscribingFile,
                        audioService: audioService,
                        onTranscribe: {
                            transcribeSelectedFile()
                        }
                    )
                } else {
                    // Empty state
                    VStack(spacing: 24) {
                        Image(systemName: "music.note")
                            .font(.system(size: 80))
                            .foregroundColor(.gray.opacity(0.3))
                        
                        VStack(spacing: 8) {
                            Text("Select a recording")
                                .font(.title2)
                                .foregroundColor(.primary)
                            
                            Text("Choose a recording from the list to play and view its transcript")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(width: geometry.size.width * 0.55)
            .background(Color(.systemBackground))
        }
    }
    
    private func transcribeSelectedFile() {
        guard let file = selectedFile else { return }
        
        // Check if we're already transcribing this file
        if transcriptStatus[file] == .generating {
            return
        }
        
        transcriptStatus[file] = .generating
        isTranscribingFile = true
        selectedFileTranscription = ""
        
        audioService.transcribeAudioFile(url: file) { transcription in
            DispatchQueue.main.async {
                self.isTranscribingFile = false
                
                if let transcription = transcription, !transcription.isEmpty {
                    self.transcriptCache[file] = transcription
                    self.transcriptStatus[file] = .available
                    self.selectedFileTranscription = transcription
                    self.saveTranscriptToDisk(file: file, transcript: transcription)
                } else {
                    self.transcriptStatus[file] = .failed
                    self.selectedFileTranscription = "Transcription failed. Please try again."
                }
            }
        }
    }
    
    private func loadTranscriptForFile(_ file: URL) {
        // First check cache
        if let cachedTranscript = transcriptCache[file] {
            selectedFileTranscription = cachedTranscript
            transcriptStatus[file] = .available
            return
        }
        
        // Try to load from disk
        if let savedTranscript = loadTranscriptFromDisk(file: file) {
            transcriptCache[file] = savedTranscript
            selectedFileTranscription = savedTranscript
            transcriptStatus[file] = .available
        } else {
            selectedFileTranscription = ""
            transcriptStatus[file] = .notGenerated
        }
    }
    
    private func saveTranscriptToDisk(file: URL, transcript: String) {
        let transcriptURL = getTranscriptURL(for: file)
        do {
            try transcript.write(to: transcriptURL, atomically: true, encoding: .utf8)
        } catch {
            print("Failed to save transcript: \(error)")
        }
    }
    
    private func loadTranscriptFromDisk(file: URL) -> String? {
        let transcriptURL = getTranscriptURL(for: file)
        return try? String(contentsOf: transcriptURL, encoding: .utf8)
    }
    
    private func getTranscriptURL(for audioFile: URL) -> URL {
        let transcriptFilename = audioFile.deletingPathExtension().appendingPathExtension("txt")
        return transcriptFilename
    }
    
    private func stopPlayback() {
        audioPlayer?.stop()
        playbackTimer?.invalidate()
        playbackTimer = nil
        isPlaying = false
        currentTime = 0
    }
    
    private func deleteRecordings(offsets: IndexSet) {
        for index in offsets {
            let file = recordedFiles[index]
            audioService.deleteRecording(url: file)
        }
        recordedFiles = audioService.getRecordedFiles()
        
        // If the deleted file was selected, clear selection
        if let selectedFile = selectedFile, !recordedFiles.contains(selectedFile) {
            self.selectedFile = nil
            stopPlayback()
        }
    }
}

struct RecordingRowView: View {
    let file: URL
    @ObservedObject var audioService: AudioService
    @Binding var selectedFile: URL?
    @Binding var selectedFileTranscription: String
    @Binding var isTranscribingFile: Bool
    @Binding var isPlaying: Bool
    @Binding var audioPlayer: AVAudioPlayer?
    @Binding var recordedFiles: [URL]
    
    @State private var showingTranscription = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text(file.lastPathComponent)
                        .font(.headline)
                    Text(formatDate(file))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // Play button
                Button(action: {
                    togglePlayback()
                }) {
                    Image(systemName: isPlaying && selectedFile == file ? "pause.circle.fill" : "play.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                
                // Transcribe button
                Button(action: {
                    transcribeFile()
                }) {
                    if isTranscribingFile && selectedFile == file {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "text.bubble")
                            .font(.title2)
                            .foregroundColor(.green)
                    }
                }
                .disabled(isTranscribingFile && selectedFile == file)
            }
            
            // Show transcription if available
            if showingTranscription && selectedFile == file && !selectedFileTranscription.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Transcription:")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text(selectedFileTranscription)
                        .font(.body)
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    
                    Button(action: {
                        #if os(iOS)
                        UIPasteboard.general.string = selectedFileTranscription
                        #elseif os(macOS)
                        NSPasteboard.general.setString(selectedFileTranscription, forType: .string)
                        #endif
                    }) {
                        HStack {
                            Image(systemName: "doc.on.doc")
                            Text("Copy")
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatDate(_ url: URL) -> String {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            if let creationDate = attributes[.creationDate] as? Date {
                let formatter = DateFormatter()
                formatter.dateStyle = .short
                formatter.timeStyle = .short
                return formatter.string(from: creationDate)
            }
        } catch {
            print("Error getting file attributes: \(error)")
        }
        return "Unknown"
    }
    
    private func togglePlayback() {
        if isPlaying && selectedFile == file {
            // Stop current playback
            audioPlayer?.stop()
            isPlaying = false
            selectedFile = nil
        } else {
            // Start new playback
            do {
                audioPlayer?.stop()
                audioPlayer = try AVAudioPlayer(contentsOf: file)
                audioPlayer?.play()
                isPlaying = true
                selectedFile = file
                
                // Stop playing when finished
                DispatchQueue.main.asyncAfter(deadline: .now() + (audioPlayer?.duration ?? 0)) {
                    if selectedFile == file {
                        isPlaying = false
                        selectedFile = nil
                    }
                }
            } catch {
                print("Error playing audio: \(error)")
            }
        }
    }
    
    private func transcribeFile() {
        guard !isTranscribingFile else { return }
        
        selectedFile = file
        isTranscribingFile = true
        showingTranscription = true
        selectedFileTranscription = ""
        
        audioService.transcribeAudioFile(url: file) { transcription in
            DispatchQueue.main.async {
                isTranscribingFile = false
                if let transcription = transcription {
                    selectedFileTranscription = transcription
                } else {
                    selectedFileTranscription = "Transcription failed"
                }
            }
        }
    }
}

#Preview {
    RecordingsListView(audioService: AudioService(), recordedFiles: .constant([]))
}
