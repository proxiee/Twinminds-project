import SwiftUI
import AVFoundation
#if os(macOS)
import AppKit
#endif

struct RecordingsListView: View {
    @ObservedObject var audioService: AudioService
    @Binding var recordedFiles: [URL]
    @State private var selectedFileTranscription = ""
    @State private var isTranscribingFile = false
    @State private var selectedFile: URL?
    @State private var isPlaying = false
    @State private var audioPlayer: AVAudioPlayer?
    @State private var showingTranscription = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                if recordedFiles.isEmpty {
                    Text("No recordings yet")
                        .foregroundColor(.gray)
                        .italic()
                } else {
                    ForEach(recordedFiles, id: \.self) { file in
                        RecordingRowView(
                            file: file,
                            audioService: audioService,
                            selectedFile: $selectedFile,
                            selectedFileTranscription: $selectedFileTranscription,
                            isTranscribingFile: $isTranscribingFile,
                            isPlaying: $isPlaying,
                            audioPlayer: $audioPlayer,
                            recordedFiles: $recordedFiles
                        )
                    }
                    .onDelete(perform: deleteRecordings)
                }
            }
            .navigationTitle("Recordings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: toolbarPlacement) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var toolbarPlacement: ToolbarItemPlacement {
        #if os(iOS)
        return .navigationBarLeading
        #else
        return .navigation
        #endif
    }
    
    private func deleteRecordings(offsets: IndexSet) {
        for index in offsets {
            let file = recordedFiles[index]
            audioService.deleteRecording(url: file)
        }
        recordedFiles = audioService.getRecordedFiles()
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
