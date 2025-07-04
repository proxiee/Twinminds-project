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
                .onAppear {
                    setupAppLifecycle()
                }
                .onOpenURL { url in
                    handleWidgetURL(url)
                }
        }
        .modelContainer(for: [RecordingSession.self, TranscriptionSegment.self])
    }
    
    private func setupAppLifecycle() {
        // Check for widget actions when app becomes active
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                self.audioService.checkAndHandleWidgetActions()
            }
        }
        
        // Set up timer to check for widget actions periodically
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                self.audioService.checkAndHandleWidgetActions()
            }
        }
        
        #if os(iOS)
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            handleAppDidEnterBackground()
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            handleAppWillEnterForeground()
        }
        #endif
    }
    
    // MARK: - Widget URL Handling
    private func handleWidgetURL(_ url: URL) {
        print("📱 Handling widget URL: \(url)")
        
        // Handle different URL schemes
        switch url.host {
        case "start-recording":
            audioService.startRecording()
        case "stop-recording":
            audioService.stopRecording()
        case "open-app":
            // App is already open, just bring to foreground
            break
        case "widget-tap":
            // Toggle recording state
            if audioService.isRecording {
                audioService.stopRecording()
            } else {
                audioService.startRecording()
            }
        default:
            print("⚠️ Unknown widget URL: \(url)")
        }
    }
    
    #if os(iOS)
    private func handleAppDidEnterBackground() {
        print("📱 App entered background")
        if audioService.isRecording {
            print("🎙️ Recording continues in background")
            // Audio session should continue recording
        }
    }
    
    private func handleAppWillEnterForeground() {
        print("📱 App will enter foreground")
        // Audio session should resume normally
    }
    #endif
}
