//
//  AudioTranscriberApp.swift
//  AudioTranscriber
//
//  Created by user281756 on 7/2/25.
//

import SwiftUI
import SwiftData

@main
struct AudioTranscriberApp: App {
    @StateObject private var audioService = AudioService()
    @StateObject private var swiftDataManager = SwiftDataManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(audioService)
                .environmentObject(swiftDataManager)
        }
        .modelContainer(for: [RecordingSession.self, TranscriptionSegment.self])
    }
    
    static func registerTerminationObserver(audioService: AudioService) {
        NotificationCenter.default.addObserver(forName: UIApplication.willTerminateNotification, object: nil, queue: .main) { [weak audioService] _ in
            Task { @MainActor in
                audioService?.applicationWillTerminate()
            }
        }
    }
}
