//
//  WidgetDataService.swift
//  AudioTranscriber
//
//  Created by Trinayana Kumar Varakala on 7/4/25.
//

import Foundation
import WidgetKit

// MARK: - Widget Data Service
class WidgetDataService {
    static let shared = WidgetDataService()
    
    private let userDefaults = UserDefaults(suiteName: "group.com.audiotranscriber.widget")
    private let logger = DebugLogger.shared
    
    private init() {}
    
    // MARK: - Widget Data Keys
    private enum Keys {
        static let recentSessions = "recent_sessions"
        static let isRecording = "is_recording"
        static let currentSessionTitle = "current_session_title"
        static let recordingDuration = "recording_duration"
        static let lastUpdate = "last_update"
        static let pendingAction = "pending_action"
        static let actionTimestamp = "action_timestamp"
    }
    
    // MARK: - Widget Actions
    enum WidgetAction: String, Codable {
        case startRecording = "start_recording"
        case stopRecording = "stop_recording"
        case toggleRecording = "toggle_recording"
    }
    
    // MARK: - Handle Widget Actions
    func setPendingAction(_ action: WidgetAction) {
        userDefaults?.set(action.rawValue, forKey: Keys.pendingAction)
        userDefaults?.set(Date().timeIntervalSince1970, forKey: Keys.actionTimestamp)
        userDefaults?.synchronize()
        
        // Trigger widget refresh
        WidgetCenter.shared.reloadAllTimelines()
        
        logger.logInfo("📱 Widget action set: \(action.rawValue)")
    }
    
    func getPendingAction() -> WidgetAction? {
        guard let actionString = userDefaults?.string(forKey: Keys.pendingAction),
              let action = WidgetAction(rawValue: actionString) else {
            return nil
        }
        
        // Check if action is recent (within last 5 seconds)
        let timestamp = userDefaults?.double(forKey: Keys.actionTimestamp) ?? 0
        let timeSinceAction = Date().timeIntervalSince1970 - timestamp
        
        if timeSinceAction > 5.0 {
            // Action is too old, clear it
            clearPendingAction()
            return nil
        }
        
        return action
    }
    
    func clearPendingAction() {
        userDefaults?.removeObject(forKey: Keys.pendingAction)
        userDefaults?.removeObject(forKey: Keys.actionTimestamp)
        userDefaults?.synchronize()
    }
    
    // MARK: - Update Widget Data
    func updateWidgetData(sessions: [RecordingSession], isRecording: Bool = false, currentSessionTitle: String? = nil, recordingDuration: TimeInterval? = nil) {
        // Convert sessions to widget format
        let widgetSessions = sessions.map { session in
            WidgetRecordingSession(from: session)
        }
        
        // Encode sessions
        if let encodedSessions = try? JSONEncoder().encode(widgetSessions) {
            userDefaults?.set(encodedSessions, forKey: Keys.recentSessions)
        }
        
        // Update other data
        userDefaults?.set(isRecording, forKey: Keys.isRecording)
        userDefaults?.set(currentSessionTitle, forKey: Keys.currentSessionTitle)
        userDefaults?.set(recordingDuration, forKey: Keys.recordingDuration)
        userDefaults?.set(Date().timeIntervalSince1970, forKey: Keys.lastUpdate)
        userDefaults?.synchronize()
        
        // Reload widget timeline
        WidgetCenter.shared.reloadAllTimelines()
        
        logger.logInfo("📱 Widget data updated - Recording: \(isRecording), Sessions: \(sessions.count)")
    }
    
    // MARK: - Get Widget Data
    func getWidgetData() -> (sessions: [WidgetRecordingSession], isRecording: Bool, currentSessionTitle: String?, recordingDuration: TimeInterval?) {
        // Get sessions
        var sessions: [WidgetRecordingSession] = []
        if let data = userDefaults?.data(forKey: Keys.recentSessions),
           let decodedSessions = try? JSONDecoder().decode([WidgetRecordingSession].self, from: data) {
            sessions = decodedSessions
        }
        
        // Get other data
        let isRecording = userDefaults?.bool(forKey: Keys.isRecording) ?? false
        let currentSessionTitle = userDefaults?.string(forKey: Keys.currentSessionTitle)
        let recordingDuration = userDefaults?.double(forKey: Keys.recordingDuration)
        
        return (sessions, isRecording, currentSessionTitle, recordingDuration)
    }
    
    // MARK: - Get Widget Data
    func getRecentSessions() -> [WidgetRecordingSession] {
        guard let sessionsData = userDefaults?.data(forKey: Keys.recentSessions) else {
            return []
        }
        
        do {
            let sessions = try JSONDecoder().decode([WidgetRecordingSession].self, from: sessionsData)
            return sessions
        } catch {
            logger.logError("Failed to decode widget sessions", error: error)
            return []
        }
    }
    
    func isCurrentlyRecording() -> Bool {
        return userDefaults?.bool(forKey: Keys.isRecording) ?? false
    }
    
    func getCurrentSessionTitle() -> String? {
        return userDefaults?.string(forKey: Keys.currentSessionTitle)
    }
    
    func getRecordingDuration() -> TimeInterval? {
        return userDefaults?.object(forKey: Keys.recordingDuration) as? TimeInterval
    }
    
    func getLastUpdate() -> Date? {
        return userDefaults?.object(forKey: Keys.lastUpdate) as? Date
    }
    
    // MARK: - Clear Widget Data
    func clearWidgetData() {
        userDefaults?.removeObject(forKey: Keys.recentSessions)
        userDefaults?.removeObject(forKey: Keys.isRecording)
        userDefaults?.removeObject(forKey: Keys.currentSessionTitle)
        userDefaults?.removeObject(forKey: Keys.recordingDuration)
        userDefaults?.removeObject(forKey: Keys.lastUpdate)
        
        logger.logInfo("📱 Widget data cleared")
        WidgetCenter.shared.reloadAllTimelines()
    }
}

// MARK: - Widget Recording Session (Shared Model)
struct WidgetRecordingSession: Codable {
    let id: String
    let title: String
    let duration: TimeInterval
    let segmentCount: Int
    let transcriptionStatus: String
    let createdAt: Date
    
    init(from session: RecordingSession) {
        self.id = session.id.uuidString
        self.title = session.baseFileName
        self.duration = session.totalDuration
        self.segmentCount = session.segmentCount
        self.transcriptionStatus = session.transcriptionStatus
        self.createdAt = session.createdAt
    }
}

// MARK: - Widget Center Import
#if canImport(WidgetKit)
import WidgetKit
#endif 