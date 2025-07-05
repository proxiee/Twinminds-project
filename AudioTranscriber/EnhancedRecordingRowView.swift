import SwiftUI
import AVFoundation
#if os(macOS)
import AppKit
#endif
#if os(iOS)
import UIKit
#endif

struct EnhancedRecordingRowView: View {
    let file: URL
    @ObservedObject var audioService: AudioService
    @Binding var selectedFile: URL?
    @Binding var selectedFileTranscription: String
    @Binding var isTranscribingFile: Bool
    @Binding var isPlaying: Bool
    @Binding var audioPlayer: AVAudioPlayer?
    @Binding var currentTime: Double
    @Binding var duration: Double
    @Binding var playbackTimer: Timer?
    @Binding var recordedFiles: [URL]
    
    let onFileSelected: (URL) -> Void
    
    @State private var fileSize: String = ""
    @State private var fileDuration: String = ""
    @State private var isExpanded: Bool = false
    @State private var cachedTranscript: String = ""
    @State private var hasTranscript: Bool = false
    @State private var isHovered: Bool = false
    @StateObject private var transcriptManager = TranscriptManager.shared
    
    private var isSelected: Bool {
        selectedFile == file
    }
    
    private var isCurrentlyPlaying: Bool {
        isPlaying && selectedFile == file
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Waveform icon
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.gray.opacity(0.1))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: isCurrentlyPlaying ? "waveform" : "waveform.circle")
                        .font(.system(size: 18))
                        .foregroundColor(isSelected ? .accentColor : .secondary)
                        // .symbolEffect(.pulse, isActive: isCurrentlyPlaying) // iOS 17+ only
                }
                
                // File info
                VStack(alignment: .leading, spacing: 2) {
                    Text(cleanFileName(file.lastPathComponent))
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    HStack(spacing: 6) {
                        Text(formatFileDate(file))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text("•")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text(fileDuration)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        #if os(iOS)
                        // Hide file size on iPhone to save space
                        if UIDevice.current.userInterfaceIdiom != .phone && !fileSize.isEmpty {
                            Text("•")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            Text(fileSize)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        #else
                        if !fileSize.isEmpty {
                            Text("•")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            Text(fileSize)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        #endif
                    }
                }
                
                Spacer(minLength: 8)
                
                // Actions
                HStack(spacing: 8) {
                    // Play/Pause button
                    Button(action: {
                        togglePlayback()
                    }) {
                        Image(systemName: isCurrentlyPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.title3)
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityLabel(isCurrentlyPlaying ? "Pause Playback" : "Play Recording")
                    .accessibilityHint(isCurrentlyPlaying ? "Double tap to pause playback." : "Double tap to play this recording.")
                    .accessibilityValue(isCurrentlyPlaying ? "Playing" : "Paused")
                    
                    // More options menu
                    Menu {
                        Button(action: {
                            transcribeFile()
                        }) {
                            Label("Transcribe", systemImage: "text.bubble")
                        }
                        .disabled(isTranscribingFile && selectedFile == file)
                        .accessibilityLabel("Transcribe Recording")
                        .accessibilityHint("Double tap to transcribe this audio file.")
                        
                        Divider()
                        
                        #if os(macOS)
                        Button(action: {
                            showInFinder()
                        }) {
                            Label("Show in Finder", systemImage: "folder")
                        }
                        .accessibilityLabel("Show in Finder")
                        .accessibilityHint("Double tap to reveal this file in Finder.")
                        #endif
                        
                        Button(action: {
                            shareFile()
                        }) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                        .accessibilityLabel("Share Recording")
                        .accessibilityHint("Double tap to share this audio file.")
                        
                        Divider()
                        
                        Button(role: .destructive, action: {
                            deleteFile()
                        }) {
                            Label("Delete", systemImage: "trash")
                        }
                        .accessibilityLabel("Delete Recording")
                        .accessibilityHint("Double tap to delete this audio file.")
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 18))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityLabel("More Options")
                    .accessibilityHint("Double tap to show more actions for this recording.")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.08) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
            )
            #if os(macOS)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHovered = hovering
                }
            }
            #endif
            .onTapGesture {
                selectFile()
            }
            .contextMenu {
                Button("Play") {
                    togglePlayback()
                }
                
                Button("Transcribe") {
                    transcribeFile()
                }
                
                Divider()
                
                #if os(macOS)
                Button("Show in Finder") {
                    showInFinder()
                }
                #endif
                
                Button("Share") {
                    shareFile()
                }
                
                Divider()
                
                Button("Delete", role: .destructive) {
                    deleteFile()
                }
            }
        }
        .onAppear {
            loadFileInfo()
            loadCachedTranscript()
        }
    }
    
    private func cleanFileName(_ filename: String) -> String {
        return filename
            .replacingOccurrences(of: "AudioTranscriber_Recording_", with: "")
            .replacingOccurrences(of: ".caf", with: "")
            .replacingOccurrences(of: "_", with: " ")
    }
    
    private func formatFileDate(_ url: URL) -> String {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            if let creationDate = attributes[.creationDate] as? Date {
                let formatter = RelativeDateTimeFormatter()
                formatter.unitsStyle = .abbreviated
                return formatter.localizedString(for: creationDate, relativeTo: Date())
            }
        } catch {
            print("Error getting file attributes: \(error)")
        }
        return "Unknown"
    }
    
    private func loadFileInfo() {
        // Get file size
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
            if let size = attributes[.size] as? NSNumber {
                fileSize = ByteCountFormatter.string(fromByteCount: size.int64Value, countStyle: .file)
            }
        } catch {
            print("Error getting file size: \(error)")
        }
        
        // Get audio duration - decrypt file first
        do {
            // Decrypt the file data
            let decryptedData = try AudioEncryptionService.shared.decryptFile(at: file)
            
            // Create temporary file for AVAudioPlayer
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".caf")
            try decryptedData.write(to: tempURL)
            
            let audioPlayer = try AVAudioPlayer(contentsOf: tempURL)
            let duration = audioPlayer.duration
            fileDuration = formatDuration(duration)
            
            // Clean up temp file
            try? FileManager.default.removeItem(at: tempURL)
        } catch {
            fileDuration = "Unknown"
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func selectFile() {
        // If this file is already selected and playing, just pause
        if isCurrentlyPlaying {
            togglePlayback()
            return
        }
        
        // Stop any current playback first
        audioPlayer?.stop()
        playbackTimer?.invalidate()
        
        // Set selected file and start playback
        selectedFile = file
        onFileSelected(file)
        
        // Start playback automatically when selecting via row tap
        togglePlayback()
    }
    
    private func loadCachedTranscript() {
        // Load cached transcript using TranscriptManager
        if let transcript = transcriptManager.getTranscript(for: file) {
            cachedTranscript = transcript
            hasTranscript = true
            
            // If this file is selected, update the displayed transcription
            if selectedFile == file {
                selectedFileTranscription = transcript
            }
        } else {
            cachedTranscript = ""
            hasTranscript = false
        }
    }
    
    private func togglePlayback() {
        if isCurrentlyPlaying {
            // Pause current playback
            audioPlayer?.pause()
            isPlaying = false
            playbackTimer?.invalidate()
        } else {
            // Start new playback
            do {
                // Stop any current playback first
                audioPlayer?.stop()
                playbackTimer?.invalidate()
                
                // Set selected file first
                selectedFile = file
                
                // Decrypt the file data
                let decryptedData = try AudioEncryptionService.shared.decryptFile(at: file)
                
                // Create temporary file for AVAudioPlayer
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".caf")
                try decryptedData.write(to: tempURL)
                
                // Create and configure audio player
                let player = try AVAudioPlayer(contentsOf: tempURL)
                
                #if os(iOS)
                // Configure audio session for iOS
                do {
                    try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
                    try AVAudioSession.sharedInstance().setActive(true)
                } catch {
                    print("Failed to set audio session category: \(error)")
                }
                #endif
                
                audioPlayer = player
                audioPlayer?.prepareToPlay()
                audioPlayer?.play()
                
                isPlaying = true
                duration = audioPlayer?.duration ?? 0
                currentTime = 0
                
                // Start timer to update progress
                playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                    if let player = audioPlayer, player.isPlaying {
                        currentTime = player.currentTime
                    } else {
                        // Playback finished
                        isPlaying = false
                        playbackTimer?.invalidate()
                        currentTime = 0
                        
                        // Clean up temp file
                        try? FileManager.default.removeItem(at: tempURL)
                    }
                }
                
            } catch {
                print("Error playing audio: \(error)")
                // Reset state on error
                isPlaying = false
                selectedFile = nil
            }
        }
    }
    
    private func transcribeFile() {
        guard !isTranscribingFile else { return }
        
        selectedFile = file
        isTranscribingFile = true
        selectedFileTranscription = ""
        
        audioService.transcribeAudioFile(url: file) { transcription in
            DispatchQueue.main.async {
                isTranscribingFile = false
                if let transcription = transcription {
                    selectedFileTranscription = transcription
                } else {
                    selectedFileTranscription = "Transcription failed. Please try again."
                }
            }
        }
    }
    
    private func showInFinder() {
        #if os(macOS)
        NSWorkspace.shared.selectFile(file.path, inFileViewerRootedAtPath: file.deletingLastPathComponent().path)
        #endif
    }
    
    private func shareFile() {
        #if os(iOS)
        // Implement share functionality
        #elseif os(macOS)
        let sharingService = NSSharingService(named: .sendViaAirDrop)
        sharingService?.perform(withItems: [file])
        #endif
    }
    
    private func deleteFile() {
        audioService.deleteRecording(url: file)
        recordedFiles = audioService.getRecordedFiles()
        
        // If this was the selected file, clear selection
        if selectedFile == file {
            selectedFile = nil
            audioPlayer?.stop()
            isPlaying = false
            playbackTimer?.invalidate()
        }
    }
}

#Preview {
    EnhancedRecordingRowView(
        file: URL(fileURLWithPath: "/tmp/test.caf"),
        audioService: AudioService(),
        selectedFile: .constant(nil),
        selectedFileTranscription: .constant(""),
        isTranscribingFile: .constant(false),
        isPlaying: .constant(false),
        audioPlayer: .constant(nil),
        currentTime: .constant(0),
        duration: .constant(0),
        playbackTimer: .constant(nil),
        recordedFiles: .constant([]),
        onFileSelected: { _ in }
    )
    .padding()
}
