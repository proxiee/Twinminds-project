import SwiftUI
#if os(macOS)
import AppKit
#endif
#if os(iOS)
import UIKit
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
    @State private var shareSheetItem: ShareSheetItem? = nil
    
    private var hasTranscript: Bool {
        transcriptManager.hasTranscript(for: selectedFile)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                // Top row: Title and character count
                HStack {
                    Text("Transcript")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    // Character count (only show when not transcribing and has content)
                    if !isTranscribing && !transcription.isEmpty {
                        Text("\(transcription.count) chars")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
                
                // Status row
                if isTranscribing {
                    Text("Transcribing...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if transcription.isEmpty {
                    Text("No transcript available")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // Controls row
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
                                .accessibilityLabel("Search Transcript")
                                .accessibilityHint("Enter text to search within the transcript.")
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(6)
                        .frame(maxWidth: 150)
                        .onChange(of: searchText) { _ in
                            updateHighlights()
                        }
                    }
                    
                    Spacer()
                    
                    // Action buttons
                    if !transcription.isEmpty && !isTranscribing {
                        Menu {
                            Button(action: {
                                copyTranscript()
                            }) {
                                Label("Copy", systemImage: "doc.on.doc")
                            }
                            .accessibilityLabel("Copy Transcript")
                            .accessibilityHint("Double tap to copy the transcript to the clipboard.")
                            
                            Button(action: {
                                shareTranscript()
                            }) {
                                Label("Share", systemImage: "square.and.arrow.up")
                            }
                            .accessibilityLabel("Share Transcript")
                            .accessibilityHint("Double tap to share the transcript using other apps.")
                            
                            Divider()
                            
                            Button(action: {
                                exportTranscript()
                            }) {
                                Label("Export as Text", systemImage: "doc.text")
                            }
                            .accessibilityLabel("Export Transcript as Text File")
                            .accessibilityHint("Double tap to export the transcript as a text file.")
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.title3)
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .accessibilityLabel("Transcript Actions")
                        .accessibilityHint("Double tap to show transcript actions like copy, share, or export.")
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
                        .accessibilityLabel(transcription.isEmpty ? "Transcribe Audio" : "Re-transcribe Audio")
                        .accessibilityHint("Double tap to start or redo transcription for this audio file.")
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
                        .accessibilityLabel("Transcript Content")
                        .accessibilityValue(transcription)
                    }
                }
                .background(Color.clear)
            }
        }
        #if os(iOS)
        .sheet(item: $shareSheetItem) { item in
            ActivityViewController(activityItems: item.items)
        }
        #endif
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
        #if os(iOS)
        shareSheetItem = ShareSheetItem(items: [transcription])
        #elseif os(macOS)
        let sharingService = NSSharingService(named: .sendViaAirDrop)
        sharingService?.perform(withItems: [transcription])
        #endif
    }
    
    private func exportTranscript() {
        #if os(iOS)
        let fileName = selectedFile.deletingPathExtension().lastPathComponent.appending("_transcript.txt")
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try transcription.write(to: tempURL, atomically: true, encoding: .utf8)
            shareSheetItem = ShareSheetItem(items: [tempURL])
        } catch {
            print("Failed to save transcript: \(error)")
        }
        #elseif os(macOS)
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
