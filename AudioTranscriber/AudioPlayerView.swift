import SwiftUI
import AVFoundation

// audio player with controls - play, pause, seek, skip
struct AudioPlayerView: View {
    @Binding var isPlaying: Bool
    @Binding var currentTime: Double
    @Binding var duration: Double
    let audioPlayer: AVAudioPlayer?
    let onSeek: (Double) -> Void
    
    @State private var isDragging = false
    @State private var dragValue: Double = 0
    @State private var progressTimer: Timer?
    
    var body: some View {
        VStack(spacing: 16) {
            // Main playback controls
            HStack(spacing: 20) {
                // Skip backward 15s
                Button(action: {
                    let newTime = max(0, currentTime - 15)
                    onSeek(newTime)
                }) {
                    Image(systemName: "gobackward.15")
                        .font(.title2)
                        .foregroundColor(.primary)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Play/Pause button
                Button(action: {
                    togglePlayback()
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 56, height: 56)
                        
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .scaleEffect(isPlaying ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: isPlaying)
                
                // Skip forward 15s
                Button(action: {
                    let newTime = min(duration, currentTime + 15)
                    onSeek(newTime)
                }) {
                    Image(systemName: "goforward.15")
                        .font(.title2)
                        .foregroundColor(.primary)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // Progress bar and time labels
            VStack(spacing: 8) {
                // Progress slider
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background track
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 4)
                        
                        // Progress track
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.accentColor)
                            .frame(width: progressWidth(geometry.size.width), height: 4)
                        
                        // Thumb
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 16, height: 16)
                            .offset(x: progressWidth(geometry.size.width) - 8)
                            .scaleEffect(isDragging ? 1.2 : 1.0)
                            .animation(.easeInOut(duration: 0.1), value: isDragging)
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                isDragging = true
                                let progress = max(0, min(1, value.location.x / geometry.size.width))
                                dragValue = progress * duration
                            }
                            .onEnded { value in
                                isDragging = false
                                let progress = max(0, min(1, value.location.x / geometry.size.width))
                                let newTime = progress * duration
                                onSeek(newTime)
                            }
                    )
                }
                .frame(height: 20)
                
                // Time labels
                HStack {
                    Text(formatTime(isDragging ? dragValue : currentTime))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                    
                    Spacer()
                    
                    Text(formatTime(duration))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }
            }
        }
        .padding(.vertical, 8)
        .onAppear {
            startProgressTimer()
        }
        .onDisappear {
            stopProgressTimer()
        }
        .onChange(of: isPlaying) { _ in
            if isPlaying {
                startProgressTimer()
            } else {
                stopProgressTimer()
            }
        }
    }
    
    // calculate progress bar width
    private func progressWidth(_ totalWidth: CGFloat) -> CGFloat {
        guard duration > 0 else { return 0 }
        let progress = (isDragging ? dragValue : currentTime) / duration
        return max(0, min(totalWidth, totalWidth * progress))
    }
    
    // format time as mm:ss
    private func formatTime(_ time: Double) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    // toggle play/pause
    private func togglePlayback() {
        if isPlaying {
            audioPlayer?.pause()
            isPlaying = false
        } else {
            audioPlayer?.play()
            isPlaying = true
        }
    }
    
    // start timer to update progress
    private func startProgressTimer() {
        stopProgressTimer()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            if let player = audioPlayer, isPlaying {
                currentTime = player.currentTime
            }
        }
    }
    
    // stop the progress timer
    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }
}

#Preview {
    AudioPlayerView(
        isPlaying: .constant(false),
        currentTime: .constant(45),
        duration: .constant(180),
        audioPlayer: nil,
        onSeek: { _ in }
    )
    .padding()
    .background(Color(.systemBackground))
}
