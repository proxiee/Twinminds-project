import SwiftUI
import SwiftData

struct SessionListView: View {
    @ObservedObject var swiftDataManager = SwiftDataManager.shared
    @State private var selectedSession: RecordingSession?
    @State private var showingSessionDetail = false
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            VStack {
                if swiftDataManager.sessions.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "waveform.path")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No Recording Sessions")
                            .font(.title2)
                            .fontWeight(.medium)
                        
                        Text("Start recording to see your sessions here")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    List {
                        ForEach(filteredSessions) { session in
                            SessionRowView(session: session) {
                                selectedSession = session
                                showingSessionDetail = true
                            }
                        }
                        .onDelete(perform: deleteSessions)
                    }
                    .searchable(text: $searchText, prompt: "Search sessions...")
                }
            }
            .navigationTitle("Recording Sessions")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Refresh") {
                        swiftDataManager.refreshSessions()
                    }
                }
            }
            .onAppear {
                swiftDataManager.refreshSessions()
            }
            .sheet(isPresented: $showingSessionDetail) {
                if let session = selectedSession {
                    SessionDetailView(session: session)
                }
            }
        }
    }
    
    private var filteredSessions: [RecordingSession] {
        if searchText.isEmpty {
            return swiftDataManager.sessions
        } else {
            return swiftDataManager.sessions.filter { session in
                session.baseFileName.localizedCaseInsensitiveContains(searchText) ||
                session.combinedTranscription.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    private func deleteSessions(offsets: IndexSet) {
        for index in offsets {
            let session = filteredSessions[index]
            swiftDataManager.deleteSession(session)
        }
        swiftDataManager.refreshSessions()
    }
}

struct SessionRowView: View {
    let session: RecordingSession
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.baseFileName)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(formatDate(session.startDate))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(session.segmentCount) segments")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(formatDuration(session.totalDuration))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Status indicators
                HStack(spacing: 12) {
                                            StatusBadge(
                            title: RecordingStatus(rawValue: session.recordingStatus)?.displayName ?? "Unknown",
                            color: statusColor(for: session.recordingStatus)
                        )
                    
                    StatusBadge(
                        title: "\(session.completedTranscriptionCount)/\(session.segmentCount) transcribed",
                        color: session.completedTranscriptionCount == session.segmentCount ? .green : .orange
                    )
                }
                
                // Preview of combined transcription
                if !session.combinedTranscription.isEmpty {
                    Text(session.combinedTranscription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func statusColor(for status: String) -> Color {
        switch status {
        case RecordingStatus.recording.rawValue: return .red
        case RecordingStatus.paused.rawValue: return .orange
        case RecordingStatus.completed.rawValue: return .green
        case RecordingStatus.failed.rawValue: return .red
        default: return .gray
        }
    }
}

struct StatusBadge: View {
    let title: String
    let color: Color
    
    var body: some View {
        Text(title)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color)
            .cornerRadius(8)
    }
}

struct SessionDetailView: View {
    let session: RecordingSession
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Session info
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Session Details")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        InfoRow(title: "File Name", value: session.baseFileName)
                        InfoRow(title: "Start Date", value: formatDate(session.startDate))
                        if let endDate = session.endDate {
                            InfoRow(title: "End Date", value: formatDate(endDate))
                        }
                        InfoRow(title: "Duration", value: formatDuration(session.totalDuration))
                        InfoRow(title: "Segments", value: "\(session.segmentCount)")
                        InfoRow(title: "Status", value: RecordingStatus(rawValue: session.recordingStatus)?.displayName ?? "Unknown")
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    
                    // Segments
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Segments")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        ForEach(session.segments.sorted(by: { $0.segmentIndex < $1.segmentIndex })) { segment in
                            SegmentDetailView(segment: segment)
                        }
                    }
                    
                    // Combined transcription
                    if !session.combinedTranscription.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Combined Transcription")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text(session.combinedTranscription)
                                .font(.body)
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(12)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Session Detail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct InfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .foregroundColor(.primary)
        }
    }
}

struct SegmentDetailView: View {
    let segment: TranscriptionSegment
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Segment \(segment.segmentIndex + 1)")
                    .font(.headline)
                
                Spacer()
                
                StatusBadge(
                    title: TranscriptionStatus(rawValue: segment.transcriptionStatus)?.displayName ?? "Unknown",
                    color: statusColor(for: segment.transcriptionStatus)
                )
            }
            
            HStack {
                Text("Duration: \(formatDuration(segment.duration))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if let methodString = segment.transcriptionMethod,
                   let method = TranscriptionMethod(rawValue: methodString) {
                    Text("Method: \(method.displayName)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if let transcription = segment.transcription {
                Text(transcription)
                    .font(.body)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            }
            
            if let errorMessage = segment.errorMessage {
                Text("Error: \(errorMessage)")
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func statusColor(for status: String) -> Color {
        switch status {
        case TranscriptionStatus.notStarted.rawValue: return .gray
        case TranscriptionStatus.inProgress.rawValue: return .blue
        case TranscriptionStatus.completed.rawValue: return .green
        case TranscriptionStatus.failed.rawValue: return .red
        case TranscriptionStatus.skipped.rawValue: return .orange
        default: return .gray
        }
    }
}

#Preview {
    SessionListView()
} 