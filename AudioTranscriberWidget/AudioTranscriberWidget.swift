//
//  AudioTranscriberWidget.swift
//  AudioTranscriberWidget
//
//  Created by Trinayana Kumar Varakala on 7/4/25.
//

import WidgetKit
import SwiftUI

// WidgetRecordingSession is now defined in WidgetDataService.swift

// MARK: - Widget Timeline Entry
struct WidgetTimelineEntry: TimelineEntry {
    let date: Date
    let isRecording: Bool
    let currentSessionTitle: String?
    let recordingDuration: TimeInterval?
    let sessions: [WidgetRecordingSession]
    
    init(date: Date = Date(), isRecording: Bool = false, currentSessionTitle: String? = nil, recordingDuration: TimeInterval? = nil, sessions: [WidgetRecordingSession] = []) {
        self.date = date
        self.isRecording = isRecording
        self.currentSessionTitle = currentSessionTitle
        self.recordingDuration = recordingDuration
        self.sessions = sessions
    }
}

// MARK: - Widget Provider
struct AudioTranscriberWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> WidgetTimelineEntry {
        WidgetTimelineEntry(
            date: Date(),
            isRecording: false,
            currentSessionTitle: nil,
            recordingDuration: nil,
            sessions: [
                WidgetRecordingSession(
                    id: "1",
                    title: "Sample Recording",
                    duration: 120.0,
                    segmentCount: 4,
                    transcriptionStatus: "completed",
                    createdAt: Date()
                )
            ]
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (WidgetTimelineEntry) -> Void) {
        let entry = WidgetTimelineEntry(
            date: Date(),
            isRecording: isCurrentlyRecording(),
            currentSessionTitle: getCurrentSessionTitle(),
            recordingDuration: getRecordingDuration(),
            sessions: getRecentSessions()
        )
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetTimelineEntry>) -> Void) {
        let currentDate = Date()
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 5, to: currentDate)!
        
        let entry = WidgetTimelineEntry(
            date: currentDate,
            isRecording: isCurrentlyRecording(),
            currentSessionTitle: getCurrentSessionTitle(),
            recordingDuration: getRecordingDuration(),
            sessions: getRecentSessions()
        )
        
        let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
        completion(timeline)
    }
    
    // MARK: - Data Access Methods
    private func getRecentSessions() -> [WidgetRecordingSession] {
        let userDefaults = UserDefaults(suiteName: "group.com.audiotranscriber.widget")
        guard let sessionsData = userDefaults?.data(forKey: "recent_sessions") else {
            return []
        }
        
        do {
            let sessions = try JSONDecoder().decode([WidgetRecordingSession].self, from: sessionsData)
            return sessions
        } catch {
            return []
        }
    }
    
    private func isCurrentlyRecording() -> Bool {
        let userDefaults = UserDefaults(suiteName: "group.com.audiotranscriber.widget")
        return userDefaults?.bool(forKey: "is_recording") ?? false
    }
    
    private func getCurrentSessionTitle() -> String? {
        let userDefaults = UserDefaults(suiteName: "group.com.audiotranscriber.widget")
        return userDefaults?.string(forKey: "current_session_title")
    }
    
    private func getRecordingDuration() -> TimeInterval? {
        let userDefaults = UserDefaults(suiteName: "group.com.audiotranscriber.widget")
        return userDefaults?.object(forKey: "recording_duration") as? TimeInterval
    }
}

// MARK: - Widget View
struct AudioTranscriberWidgetView: View {
    let entry: WidgetTimelineEntry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge:
            LargeWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

// MARK: - Small Widget View
struct SmallWidgetView: View {
    let entry: WidgetTimelineEntry
    
    var body: some View {
        Button(action: {
            // Toggle recording state
            WidgetDataService.shared.setPendingAction(.toggleRecording)
        }) {
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "waveform")
                        .font(.title2)
                        .foregroundColor(.blue)
                    
                    Spacer()
                    
                    if entry.isRecording {
                        Image(systemName: "record.circle.fill")
                            .font(.title2)
                            .foregroundColor(.red)
                            .scaleEffect(1.2)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("AudioTranscriber")
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    if entry.isRecording {
                        if let duration = entry.recordingDuration {
                            Text(formatDuration(duration))
                                .font(.caption)
                                .foregroundColor(.red)
                                .fontWeight(.medium)
                        } else {
                            Text("Recording...")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    } else if let currentSession = entry.currentSessionTitle {
                        Text(currentSession)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    } else {
                        Text("\(entry.sessions.count) recordings")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
            .background(Color(.systemBackground))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Medium Widget View
struct MediumWidgetView: View {
    let entry: WidgetTimelineEntry
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "waveform")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Text("AudioTranscriber")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
                
                if entry.isRecording {
                    HStack(spacing: 4) {
                        Image(systemName: "record.circle.fill")
                            .font(.caption)
                            .foregroundColor(.red)
                            .scaleEffect(1.1)
                        Text("Recording")
                            .font(.caption)
                            .foregroundColor(.red)
                            .fontWeight(.medium)
                    }
                }
            }
            
            if entry.isRecording {
                // Recording controls
                VStack(spacing: 8) {
                    if let duration = entry.recordingDuration {
                        Text(formatDuration(duration))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                    }
                    
                    HStack(spacing: 16) {
                        Button(action: {
                            // Stop recording
                            WidgetDataService.shared.setPendingAction(.stopRecording)
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "stop.circle.fill")
                                    .font(.title3)
                                Text("Stop")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.red)
                            .cornerRadius(8)
                        }
                        
                        Link(destination: URL(string: "audiotranscriber://open-app")!) {
                            HStack(spacing: 4) {
                                Image(systemName: "ellipsis.circle")
                                    .font(.title3)
                                Text("More")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.blue)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Show recent sessions or start recording
                if entry.sessions.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "mic.slash")
                            .font(.title)
                            .foregroundColor(.gray)
                        
                        Text("No recordings yet")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Button(action: {
                            // Start recording
                            WidgetDataService.shared.setPendingAction(.startRecording)
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "record.circle")
                                    .font(.caption)
                                Text("Start Recording")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue)
                            .cornerRadius(8)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(entry.sessions.prefix(3), id: \.id) { session in
                            SessionRowView(session: session)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

// MARK: - Large Widget View
struct LargeWidgetView: View {
    let entry: WidgetTimelineEntry
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "waveform")
                    .font(.title)
                    .foregroundColor(.blue)
                
                Text("AudioTranscriber")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                if entry.isRecording {
                    HStack(spacing: 6) {
                        Image(systemName: "record.circle.fill")
                            .font(.body)
                            .foregroundColor(.red)
                            .scaleEffect(1.1)
                        Text("Recording")
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.red)
                    }
                }
            }
            
            if entry.isRecording {
                // Recording controls and status
                VStack(spacing: 12) {
                    if let duration = entry.recordingDuration {
                        Text(formatDuration(duration))
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                    }
                    
                    HStack(spacing: 16) {
                        Button(action: {
                            // Stop recording
                            WidgetDataService.shared.setPendingAction(.stopRecording)
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "stop.circle.fill")
                                    .font(.title2)
                                Text("Stop Recording")
                                    .font(.body)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.red)
                            .cornerRadius(10)
                        }
                        
                        Link(destination: URL(string: "audiotranscriber://open-app")!) {
                            HStack(spacing: 6) {
                                Image(systemName: "ellipsis.circle")
                                    .font(.title2)
                                Text("More Options")
                                    .font(.body)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.blue)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(10)
                        }
                    }
                    
                    if let currentSession = entry.currentSessionTitle {
                        Text(currentSession)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Show sessions or start recording
                if entry.sessions.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "mic.slash")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        
                        Text("No recordings yet")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("Start recording to see your sessions here")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button(action: {
                            // Start recording
                            WidgetDataService.shared.setPendingAction(.startRecording)
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "record.circle")
                                    .font(.body)
                                Text("Start Recording")
                                    .font(.body)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.blue)
                            .cornerRadius(10)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(entry.sessions.prefix(6), id: \.id) { session in
                                SessionDetailRowView(session: session)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

// MARK: - Session Row View
struct SessionRowView: View {
    let session: WidgetRecordingSession
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(session.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text("\(session.segmentCount) segments • \(formatDuration(session.duration))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            StatusBadge(status: session.transcriptionStatus)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.systemGray6))
        .cornerRadius(6)
    }
}

// MARK: - Session Detail Row View
struct SessionDetailRowView: View {
    let session: WidgetRecordingSession
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(session.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Spacer()
                
                StatusBadge(status: session.transcriptionStatus)
            }
            
            HStack {
                Label("\(session.segmentCount) segments", systemImage: "waveform")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(formatDuration(session.duration))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Text(formatDate(session.createdAt))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Status Badge
struct StatusBadge: View {
    let status: String
    
    var body: some View {
        Text(status.capitalized)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(backgroundColor)
            .foregroundColor(.white)
            .cornerRadius(4)
    }
    
    private var backgroundColor: Color {
        switch status.lowercased() {
        case "completed":
            return .green
        case "processing":
            return .orange
        case "failed":
            return .red
        default:
            return .gray
        }
    }
}

// MARK: - Helper Functions
func formatDuration(_ duration: TimeInterval) -> String {
    let minutes = Int(duration) / 60
    let seconds = Int(duration) % 60
    return String(format: "%d:%02d", minutes, seconds)
}

func formatDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .short
    return formatter.string(from: date)
}

// MARK: - Widget Configuration
struct AudioTranscriberWidget: Widget {
    let kind: String = "AudioTranscriberWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AudioTranscriberWidgetProvider()) { entry in
            AudioTranscriberWidgetView(entry: entry)
        }
        .configurationDisplayName("AudioTranscriber")
        .description("Quick access to your audio recordings and transcription status.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Widget Bundle
@main
struct AudioTranscriberWidgetBundle: WidgetBundle {
    var body: some Widget {
        AudioTranscriberWidget()
    }
}
