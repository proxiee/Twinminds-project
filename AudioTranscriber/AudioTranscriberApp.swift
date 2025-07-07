//
//  AudioTranscriberApp.swift
//  AudioTranscriber
//
//  Created by user281756 on 7/2/25.
//

import SwiftUI
import SwiftData

// main app entry point - sets up the whole thing
@main
struct AudioTranscriberApp: App {
    // core services that everything else needs
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
    
    // handle app termination - save whatever we can
    static func registerTerminationObserver(audioService: AudioService) {
        NotificationCenter.default.addObserver(forName: UIApplication.willTerminateNotification, object: nil, queue: .main) { [weak audioService] _ in
            Task { @MainActor in
                audioService?.applicationWillTerminate()
            }
        }
    }
}
