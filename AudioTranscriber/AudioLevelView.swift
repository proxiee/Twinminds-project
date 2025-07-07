import SwiftUI

// shows audio level as animated bars - like a real audio meter
struct AudioLevelView: View {
    @ObservedObject var audioService: AudioService
    let barCount: Int = 20
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(barColor(for: index))
                    .frame(width: 3, height: barHeight(for: index))
                    .animation(.easeInOut(duration: 0.1), value: audioService.audioLevel)
            }
        }
        .frame(height: 40)
        .padding(.horizontal)
    }
    
    // calculate how tall each bar should be based on audio level
    private func barHeight(for index: Int) -> CGFloat {
        let baseHeight: CGFloat = 4
        let maxHeight: CGFloat = 40
        
        if !audioService.isRecording {
            return baseHeight
        }
        
        let threshold = Float(index) / Float(barCount)
        let level = audioService.audioLevel
        
        if level > threshold {
            let intensity = min(1.0, (level - threshold) * Float(barCount))
            return baseHeight + CGFloat(intensity) * (maxHeight - baseHeight)
        } else {
            return baseHeight
        }
    }
    
    // color code the bars - green for good levels, yellow for medium, red for too loud
    private func barColor(for index: Int) -> Color {
        let threshold = Float(index) / Float(barCount)
        let level = audioService.audioLevel
        
        if !audioService.isRecording {
            return Color.gray.opacity(0.3)
        }
        
        if level > threshold {
            if threshold < 0.6 {
                return Color.green
            } else if threshold < 0.8 {
                return Color.yellow
            } else {
                return Color.red
            }
        } else {
            return Color.gray.opacity(0.3)
        }
    }
}

#Preview {
    AudioLevelView(audioService: AudioService())
}
