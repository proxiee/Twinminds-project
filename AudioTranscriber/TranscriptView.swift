import SwiftUI
#if os(macOS)
import AppKit
#endif

struct TranscriptView: View {
    let selectedFile: URL
    let transcription: String
    let isTranscribing: Bool
    let audioService: AudioService
    let onTranscribe: () -> Void
    
    @State private var searchText = ""
    @State private var showingShareSheet = false
    @State private var highlightedRanges: [Range<String.Index>] = []
    @StateObject private var transcriptManager = TranscriptManager.shared
    
    private var hasTranscript: Bool {
        transcriptManager.hasTranscript(for: selectedFile)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Transcript")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if isTranscribing {
                        Text("Transcribing...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else if transcription.isEmpty {
                        Text("No transcript available")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("\(transcription.count) characters")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    // Search
                    if !transcription.isEmpty && !isTranscribing {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)
                                .font(.caption)
                            
                            TextField("Search transcript", text: $searchText)
                                .textFieldStyle(PlainTextFieldStyle())
                                .font(.caption)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(6)
                        .frame(width: 150)
                        .onChange(of: searchText) { _ in
                            updateHighlights()
                        }
                    }
                    
                    // Action buttons
                    if !transcription.isEmpty && !isTranscribing {
                        Menu {
                            Button(action: {
                                copyTranscript()
                            }) {
                                Label("Copy", systemImage: "doc.on.doc")
                            }
                            
                            Button(action: {
                                shareTranscript()
                            }) {
                                Label("Share", systemImage: "square.and.arrow.up")
                            }
                            
                            Divider()
                            
                            Button(action: {
                                exportTranscript()
                            }) {
                                Label("Export as Text", systemImage: "doc.text")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.title3)
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    // Transcribe button - always show when not transcribing
                    if !isTranscribing {
                        Button(action: onTranscribe) {
                            HStack(spacing: 4) {
                                Image(systemName: "text.bubble")
                                    .font(.caption)
                                Text(transcription.isEmpty ? "Transcribe" : "Re-transcribe")
                                    .font(.caption)
                                    .fixedSize()
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.accentColor)
                            .cornerRadius(4)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .fixedSize()
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color.clear)
            
            Divider()
            
            // Content
            if isTranscribing {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    
                    Text("Transcribing audio...")
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    Text("This may take a few moments")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
            } else if transcription.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "text.bubble.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.gray.opacity(0.4))
                    
                    Text("No transcript yet")
                        .font(.title3)
                        .foregroundColor(.primary)
                    
                    Text("Tap 'Transcribe' to generate a transcript for this recording")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Transcript text with highlighting
                        HighlightedText(
                            text: transcription,
                            searchText: searchText,
                            highlightColor: Color.yellow.opacity(0.3)
                        )
                        .textSelection(.enabled)
                        .font(.body)
                        .lineSpacing(4)
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .background(Color.clear)
            }
        }
    }
    
    private func updateHighlights() {
        guard !searchText.isEmpty && !transcription.isEmpty else {
            highlightedRanges = []
            return
        }
        
        let lowercasedTranscription = transcription.lowercased()
        let lowercasedSearch = searchText.lowercased()
        var ranges: [Range<String.Index>] = []
        
        var startIndex = lowercasedTranscription.startIndex
        while let range = lowercasedTranscription.range(of: lowercasedSearch, range: startIndex..<lowercasedTranscription.endIndex) {
            let originalRange = Range(uncheckedBounds: (range.lowerBound, range.upperBound))
            ranges.append(originalRange)
            startIndex = range.upperBound
        }
        
        highlightedRanges = ranges
    }
    
    private func copyTranscript() {
        #if os(macOS)
        NSPasteboard.general.setString(transcription, forType: .string)
        #endif
    }
    
    private func shareTranscript() {
        #if os(macOS)
        let sharingService = NSSharingService(named: .sendViaAirDrop)
        sharingService?.perform(withItems: [transcription])
        #endif
    }
    
    private func exportTranscript() {
        #if os(macOS)
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.plainText]
        savePanel.nameFieldStringValue = selectedFile.deletingPathExtension().lastPathComponent.appending("_transcript.txt")
        
        if savePanel.runModal() == .OK, let url = savePanel.url {
            do {
                try transcription.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                print("Failed to save transcript: \(error)")
            }
        }
        #endif
    }
}

struct HighlightedText: View {
    let text: String
    let searchText: String
    let highlightColor: Color
    
    var body: some View {
        if searchText.isEmpty {
            Text(text)
        } else {
            Text(attributedString)
        }
    }
    
    private var attributedString: AttributedString {
        var attributedString = AttributedString(text)
        
        if !searchText.isEmpty {
            let lowercasedText = text.lowercased()
            let lowercasedSearch = searchText.lowercased()
            
            var startIndex = lowercasedText.startIndex
            while let range = lowercasedText.range(of: lowercasedSearch, range: startIndex..<lowercasedText.endIndex) {
                let attributedRange = Range(range, in: attributedString)!
                attributedString[attributedRange].backgroundColor = highlightColor
                startIndex = range.upperBound
            }
        }
        
        return attributedString
    }
}

#Preview {
    TranscriptView(
        selectedFile: URL(fileURLWithPath: "/tmp/test.caf"),
        transcription: "This is a sample transcript with some text that demonstrates the highlighting feature when searching for specific words.",
        isTranscribing: false,
        audioService: AudioService(),
        onTranscribe: {}
    )
    .frame(height: 400)
}
