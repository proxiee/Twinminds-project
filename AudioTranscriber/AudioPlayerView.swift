import SwiftUI
import AVFoundation

struct AudioPlayerView: View {
    @Binding var isPlaying: Bool
    @Binding var currentTime: Double
    @Binding var duration: Double
    let audioPlayer: AVAudioPlayer?
    let onSeek: (Double) -> Void
    
    @State private var isDragging = false
    @State private var dragValue: Double = 0
    
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
            
            // Additional controls
            HStack(spacing: 24) {
                // Speed control
                Menu {
                    Button("0.5x") { setPlaybackRate(0.5) }
                    Button("0.75x") { setPlaybackRate(0.75) }
                    Button("1.0x") { setPlaybackRate(1.0) }
                    Button("1.25x") { setPlaybackRate(1.25) }
                    Button("1.5x") { setPlaybackRate(1.5) }
                    Button("2.0x") { setPlaybackRate(2.0) }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "speedometer")
                        Text("\(String(format: "%.1f", audioPlayer?.rate ?? 1.0))x")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                // Volume control (placeholder)
                HStack(spacing: 8) {
                    Image(systemName: "speaker.wave.2")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Slider(value: .constant(0.8), in: 0...1)
                        .frame(width: 80)
                        .disabled(true) // Audio level control can be added later
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private func progressWidth(_ totalWidth: CGFloat) -> CGFloat {
        guard duration > 0 else { return 0 }
        let progress = (isDragging ? dragValue : currentTime) / duration
        return max(0, min(totalWidth, totalWidth * progress))
    }
    
    private func formatTime(_ time: Double) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func togglePlayback() {
        if isPlaying {
            audioPlayer?.pause()
            isPlaying = false
        } else {
            audioPlayer?.play()
            isPlaying = true
        }
    }
    
    private func setPlaybackRate(_ rate: Float) {
        audioPlayer?.rate = rate
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
