import SwiftUI

struct SegmentationProgressView: View {
    @ObservedObject var audioService: AudioService
    
    var body: some View {
        if let recording = audioService.currentSegmentedRecording {
            VStack(spacing: 12) {
                // Header
                HStack {
                    Image(systemName: "waveform.path")
                        .font(.title2)
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Segmented Recording")
                            .font(.headline)
                        Text("30-second segments")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if recording.isRecording {
                        Image(systemName: "stop.circle.fill")
                            .font(.title2)
                            .foregroundColor(.red)
                            // .symbolEffect(.pulse, isActive: true) // iOS 17+ only
                    }
                }
                
                // Current segment progress
                VStack(spacing: 8) {
                    HStack {
                        Text("Current Segment: \(audioService.currentSegmentIndex + 1)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Text(formatTime(audioService.recordingProgress))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                    }
                    
                    // Segment progress bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 8)
                            
                            // Current segment progress
                            RoundedRectangle(cornerRadius: 4)
                                .fill(LinearGradient(
                                    gradient: Gradient(colors: [.blue, .cyan]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ))
                                .frame(
                                    width: geometry.size.width * currentSegmentProgress,
                                    height: 8
                                )
                                .animation(.easeInOut(duration: 0.1), value: currentSegmentProgress)
                        }
                    }
                    .frame(height: 8)
                }
                
                // Segments overview
                if !recording.segments.isEmpty {
                    VStack(spacing: 8) {
                        HStack {
                            Text("Completed Segments")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            Text("\(recording.segments.count) segments")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        // Segments grid
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: min(recording.segments.count + (recording.isRecording ? 1 : 0), 10)), spacing: 4) {
                            ForEach(0..<recording.segments.count, id: \.self) { index in
                                SegmentIndicator(
                                    index: index + 1,
                                    isCompleted: true,
                                    isTranscribing: recording.segments[index].isTranscribing,
                                    hasTranscription: recording.segments[index].transcriptionCompleted
                                )
                            }
                            
                            // Current recording segment indicator
                            if recording.isRecording {
                                SegmentIndicator(
                                    index: audioService.currentSegmentIndex + 1,
                                    isCompleted: false,
                                    isTranscribing: false,
                                    hasTranscription: false
                                )
                            }
                        }
                    }
                }
                
                // Combined transcription preview
                if !recording.combinedTranscription.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Combined Transcription")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        ScrollView {
                            Text(recording.combinedTranscription)
                                .font(.body)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                        }
                        .frame(maxHeight: 100)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var currentSegmentProgress: Double {
        let segmentDuration = 30.0
        let elapsed = audioService.recordingProgress
        let currentSegmentTime = elapsed - (Double(audioService.currentSegmentIndex) * segmentDuration)
        return min(1.0, max(0.0, currentSegmentTime / segmentDuration))
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct SegmentIndicator: View {
    let index: Int
    let isCompleted: Bool
    let isTranscribing: Bool
    let hasTranscription: Bool
    
    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                Circle()
                    .fill(backgroundColor)
                    .frame(width: 32, height: 32)
                
                if isTranscribing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.6)
                } else if hasTranscription {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .foregroundColor(.white)
                } else if isCompleted {
                    Image(systemName: "waveform")
                        .font(.caption)
                        .foregroundColor(.white)
                } else {
                    Image(systemName: "record.circle")
                        .font(.caption)
                        .foregroundColor(.white)
                        // .symbolEffect(.pulse, isActive: true) // iOS 17+ only
                }
            }
            
            Text("\(index)")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
    }
    
    private var backgroundColor: Color {
        if isTranscribing {
            return .orange
        } else if hasTranscription {
            return .green
        } else if isCompleted {
            return .blue
        } else {
            return .red
        }
    }
}

struct SegmentationModeToggle: View {
    @ObservedObject var audioService: AudioService
    @State private var useSegmentation = true
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Recording Mode")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                Spacer()
                
                Toggle("30s segments", isOn: $useSegmentation)
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                    .labelsHidden()
            }
            
            Text(useSegmentation ? "Records in 30s segments for better transcription" : "Records as a single continuous file")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.8))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.1))
        .cornerRadius(8)
        .disabled(audioService.isRecording)
        .onChange(of: useSegmentation) { _ in
            // Store the preference for future use
            UserDefaults.standard.set(useSegmentation, forKey: "useSegmentedRecording")
        }
        .onAppear {
            // Default to false (legacy recording) to avoid crashes until segmentation is fully stable
            useSegmentation = UserDefaults.standard.object(forKey: "useSegmentedRecording") as? Bool ?? false
        }
    }
}

#Preview {
    VStack {
        SegmentationProgressView(audioService: AudioService())
        SegmentationModeToggle(audioService: AudioService())
    }
    .padding()
}
