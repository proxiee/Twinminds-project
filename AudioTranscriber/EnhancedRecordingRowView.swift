import SwiftUI
import AVFoundation
#if os(macOS)
import AppKit
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
    @State private var isHovered = false
    
    private var isSelected: Bool {
        selectedFile == file
    }
    
    private var isCurrentlyPlaying: Bool {
        isPlaying && selectedFile == file
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                // Waveform icon
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.gray.opacity(0.1))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: isCurrentlyPlaying ? "waveform" : "waveform.circle")
                        .font(.title3)
                        .foregroundColor(isSelected ? .accentColor : .secondary)
                        .symbolEffect(.pulse, isActive: isCurrentlyPlaying)
                }
                
                // File info
                VStack(alignment: .leading, spacing: 4) {
                    Text(cleanFileName(file.lastPathComponent))
                        .font(.system(.body, design: .rounded, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    HStack(spacing: 8) {
                        Text(formatFileDate(file))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(fileDuration)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if !fileSize.isEmpty {
                            Text("•")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(fileSize)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                // Actions
                HStack(spacing: 12) {
                    // Play/Pause button
                    Button(action: {
                        togglePlayback()
                    }) {
                        Image(systemName: isCurrentlyPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.title2)
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .opacity(isHovered || isSelected ? 1.0 : 0.7)
                    
                    // More options menu
                    Menu {
                        Button(action: {
                            transcribeFile()
                        }) {
                            Label("Transcribe", systemImage: "text.bubble")
                        }
                        .disabled(isTranscribingFile && selectedFile == file)
                        
                        Divider()
                        
                        Button(action: {
                            showInFinder()
                        }) {
                            Label("Show in Finder", systemImage: "folder")
                        }
                        
                        Button(action: {
                            shareFile()
                        }) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                        
                        Divider()
                        
                        Button(role: .destructive, action: {
                            deleteFile()
                        }) {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .opacity(isHovered || isSelected ? 1.0 : 0.3)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.08) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
            )
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHovered = hovering
                }
            }
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
                
                Button("Show in Finder") {
                    showInFinder()
                }
                
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
        
        // Get audio duration
        do {
            let audioPlayer = try AVAudioPlayer(contentsOf: file)
            let duration = audioPlayer.duration
            fileDuration = formatDuration(duration)
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
        selectedFile = file
        onFileSelected(file)
    }
    
    private func loadTranscriptionIfExists() {
        // Check if we have a cached transcription
        // This could be expanded to save/load transcriptions from disk
        if selectedFile == file && !selectedFileTranscription.isEmpty {
            return
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
                // Stop any current playback
                audioPlayer?.stop()
                playbackTimer?.invalidate()
                
                audioPlayer = try AVAudioPlayer(contentsOf: file)
                audioPlayer?.play()
                isPlaying = true
                selectedFile = file
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
        #if os(macOS)
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
