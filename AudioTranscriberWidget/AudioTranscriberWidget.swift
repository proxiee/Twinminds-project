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
    
    var body: some View {
        LargeCreativeWidgetView(entry: entry)
    }
}

// MARK: - Large Creative Widget View
struct LargeCreativeWidgetView: View {
    let entry: WidgetTimelineEntry
    
    var body: some View {
        ZStack {
            Color.white
            VStack(spacing: 24) {
                Spacer(minLength: 16)
                // Stylized waveform (SF Symbol or custom)
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.black.opacity(0.08))
                        .frame(height: 120)
                        .shadow(radius: 8)
                    HStack(spacing: 0) {
                        ForEach(0..<12) { i in
                            Capsule()
                                .fill(entry.isRecording ? Color.red : Color.blue)
                                .frame(width: 10, height: CGFloat.random(in: 40...100))
                                .opacity(0.7)
                        }
                    }
                }
                .padding(.horizontal, 24)
                // Live status
                if entry.isRecording {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 14, height: 14)
                        Text("Recording…")
                            .font(.headline)
                            .foregroundColor(.red)
                            .fontWeight(.semibold)
                        if let duration = entry.recordingDuration {
                            Text(formatDuration(duration))
                                .font(.headline)
                                .foregroundColor(.black)
                        }
                    }
                }
                Spacer()
                // Recent recordings as chips
                if !entry.sessions.isEmpty {
                    HStack(spacing: 10) {
                        ForEach(entry.sessions.prefix(3), id: \.id) { session in
                            HStack(spacing: 4) {
                                Image(systemName: "music.note")
                                    .font(.caption)
                                    .foregroundColor(.black.opacity(0.8))
                                Text(session.title)
                                    .font(.caption)
                                    .foregroundColor(.black)
                                    .lineLimit(1)
                                Text(formatDuration(session.duration))
                                    .font(.caption2)
                                    .foregroundColor(.black.opacity(0.7))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.black.opacity(0.08))
                            .cornerRadius(16)
                        }
                    }
                } else {
                    Text("No recordings yet")
                        .font(.caption2)
                        .foregroundColor(.black.opacity(0.5))
                }
                Spacer(minLength: 16)
            }
            .padding()
        }
        .cornerRadius(32)
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
@main
struct AudioTranscriberWidget: Widget {
    let kind: String = "AudioTranscriberWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AudioTranscriberWidgetProvider()) { entry in
            MediumRowWidgetView(entry: entry)
        }
        .configurationDisplayName("AudioTranscriber")
        .description("View live status and recent recordings.")
        .supportedFamilies([.systemMedium]) // Only medium widget
    }
}

// MARK: - Medium Row Widget View
struct MediumRowWidgetView: View {
    let entry: WidgetTimelineEntry
    
    var body: some View {
        ZStack {
            Color.white
            VStack(alignment: .leading, spacing: 16) {
                // Live status
                HStack(spacing: 8) {
                    if entry.isRecording {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 12, height: 12)
                        Text("Recording…")
                            .font(.headline)
                            .foregroundColor(.red)
                            .fontWeight(.semibold)
                        if let duration = entry.recordingDuration {
                            Text(formatDuration(duration))
                                .font(.headline)
                                .foregroundColor(.black)
                        }
                    }
                }
                // Buttons
                HStack(spacing: 16) {
                    Link(destination: URL(string: "audiotranscriber://start-recording")!) {
                        HStack {
                            Image(systemName: "record.circle.fill")
                                .font(.title2)
                            Text("Start Recording")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.red)
                        .cornerRadius(12)
                    }
                    Link(destination: URL(string: "audiotranscriber://open-app")!) {
                        HStack {
                            Image(systemName: "list.bullet.rectangle")
                                .font(.title2)
                            Text("View Recordings")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
        }
        .cornerRadius(20)
    }
}

