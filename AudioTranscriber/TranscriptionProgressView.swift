import SwiftUI

struct TranscriptionProgressView: View {
    let session: RecordingSession
    @ObservedObject private var networkMonitor = NetworkMonitor.shared
    
    private var completedSegments: Int {
        session.segments.filter { $0.transcriptionStatus == "completed" }.count
    }
    
    private var failedSegments: Int {
        session.segments.filter { $0.transcriptionStatus == "failed" }.count
    }
    
    private var processingSegments: Int {
        session.segments.filter { $0.transcriptionStatus == "in_progress" }.count
    }
    
    private var queuedSegments: Int {
        session.segments.filter { $0.transcriptionStatus == "not_started" }.count
    }
    
    private var totalSegments: Int {
        session.segments.count
    }
    
    private var progressPercentage: Double {
        guard totalSegments > 0 else { return 0 }
        return Double(completedSegments) / Double(totalSegments)
    }
    
    private var estimatedTimeRemaining: String {
        // Rough estimate: 30 seconds per segment for transcription
        let remainingSegments = totalSegments - completedSegments - failedSegments
        let estimatedSeconds = remainingSegments * 30
        
        if estimatedSeconds < 60 {
            return "~\(estimatedSeconds)s remaining"
        } else if estimatedSeconds < 3600 {
            let minutes = estimatedSeconds / 60
            return "~\(minutes)m remaining"
        } else {
            let hours = estimatedSeconds / 3600
            let minutes = (estimatedSeconds % 3600) / 60
            return "~\(hours)h \(minutes)m remaining"
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Overall progress header
            VStack(spacing: 8) {
                HStack {
                    Text("Transcription Progress")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Text("\(completedSegments)/\(totalSegments)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Main progress bar
                ProgressView(value: progressPercentage)
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                    .scaleEffect(y: 1.5)
                
                // Status summary
                HStack(spacing: 16) {
                    StatusChip(
                        title: "Completed",
                        count: completedSegments,
                        color: .green,
                        icon: "checkmark.circle.fill"
                    )
                    
                    StatusChip(
                        title: "Processing",
                        count: processingSegments,
                        color: .blue,
                        icon: "arrow.clockwise"
                    )
                    
                    StatusChip(
                        title: "Queued",
                        count: queuedSegments,
                        color: .orange,
                        icon: "clock"
                    )
                    
                    if failedSegments > 0 {
                        StatusChip(
                            title: "Failed",
                            count: failedSegments,
                            color: .red,
                            icon: "exclamationmark.triangle.fill"
                        )
                    }
                }
                
                // Network status and time estimate
                HStack {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(networkMonitor.isConnected ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        Text(networkMonitor.isConnected ? "Online" : "Offline")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if totalSegments > completedSegments + failedSegments {
                        Text(estimatedTimeRemaining)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            // Individual segment progress
            if !session.segments.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Segment Details")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    LazyVStack(spacing: 8) {
                        ForEach(Array(session.segments.enumerated()), id: \.element.id) { index, segment in
                            SegmentProgressRow(
                                segment: segment,
                                segmentNumber: index + 1,
                                totalSegments: totalSegments
                            )
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
    }
}

// MARK: - Status Chip Component
struct StatusChip: View {
    let title: String
    let count: Int
    let color: Color
    let icon: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
            
            Text("\(count)")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Segment Progress Row Component
struct SegmentProgressRow: View {
    let segment: TranscriptionSegment
    let segmentNumber: Int
    let totalSegments: Int
    
    private var statusColor: Color {
        switch segment.transcriptionStatus {
        case "completed":
            return .green
        case "in_progress":
            return .blue
        case "failed":
            return .red
        case "not_started":
            return .orange
        default:
            return .gray
        }
    }
    
    private var statusIcon: String {
        switch segment.transcriptionStatus {
        case "completed":
            return "checkmark.circle.fill"
        case "in_progress":
            return "arrow.clockwise"
        case "failed":
            return "exclamationmark.triangle.fill"
        case "not_started":
            return "clock"
        default:
            return "questionmark.circle"
        }
    }
    
    private var statusText: String {
        switch segment.transcriptionStatus {
        case "completed":
            return "Completed"
        case "in_progress":
            return "Processing"
        case "failed":
            return "Failed"
        case "not_started":
            return "Queued"
        default:
            return "Unknown"
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Segment number
            Text("\(segmentNumber)")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .frame(width: 20)
            
            // Status icon
            Image(systemName: statusIcon)
                .font(.caption)
                .foregroundColor(statusColor)
                .frame(width: 16)
            
            // Segment info
            VStack(alignment: .leading, spacing: 2) {
                Text("Segment \(segmentNumber)")
                    .font(.caption)
                    .fontWeight(.medium)
                
                if segment.transcriptionStatus == "completed" && !(segment.transcription ?? "").isEmpty {
                    Text(segment.transcription ?? "")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                } else {
                    Text(statusText)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Duration
            Text(formatDuration(segment.duration))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(statusColor.opacity(0.05))
        .cornerRadius(8)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Compact Progress View for Session Lists
struct CompactTranscriptionProgressView: View {
    let session: RecordingSession
    
    private var completedSegments: Int {
        session.segments.filter { $0.transcriptionStatus == "completed" }.count
    }
    
    private var totalSegments: Int {
        session.segments.count
    }
    
    private var progressPercentage: Double {
        guard totalSegments > 0 else { return 0 }
        return Double(completedSegments) / Double(totalSegments)
    }
    
    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text("\(completedSegments)/\(totalSegments) segments")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(Int(progressPercentage * 100))%")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
            }
            
            ProgressView(value: progressPercentage)
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                .scaleEffect(y: 0.8)
        }
    }
}

#Preview {
    let sampleSession = RecordingSession(baseFileName: "Sample Recording")
    TranscriptionProgressView(session: sampleSession)
        .padding()
} 