import SwiftUI

struct OnboardingHelpView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Welcome to AudioTranscriber!")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.top)
                    
                    Text("**Main Features:**")
                        .font(.headline)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("• High-quality audio recording (single file or 30s segments)")
                        Text("• Configurable audio quality (sample rate, bit depth, format)")
                        Text("• Real-time audio level visualization and waveform")
                        Text("• Background recording with automatic interruption recovery")
                        Text("• Handles audio route changes (headphones, Bluetooth, etc.)")
                        Text("• Noise reduction (high-pass filter & noise gate)")
                        Text("• End-to-end encryption: audio files are encrypted at rest")
                        Text("• Timed backend transcription (OpenAI Whisper) with retry & fallback")
                        Text("• Offline queuing and local transcription fallback")
                        Text("• SwiftData-powered session & segment management (scales to 10,000+ segments)")
                        Text("• Search, filter, and group sessions by date")
                        Text("• Pull-to-refresh and infinite scroll pagination")
                        Text("• Transcription progress indicators and status badges")
                        Text("• Offline/online network status indicators")
                        Text("• Export/share audio and transcripts in multiple formats")
                        Text("• iOS widget for quick recording and session access")
                        Text("• Full VoiceOver accessibility and dynamic type support")
                        Text("• Robust error handling for permissions, storage, network, and more")
                    }
                    
                    Text("**How to Use:**")
                        .font(.headline)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("1. Tap the **Record** button to start recording.")
                        Text("2. Use the **Pause/Resume** button to temporarily halt/resume.")
                        Text("3. Tap **Stop** to finish and save.")
                        Text("4. Toggle **30s Segments** or **Noise Reduction** as needed before recording.")
                        Text("5. View, play, transcribe, or share recordings from the session list.")
                        Text("6. Use **Settings** to configure transcription, quality, and API keys.")
                        Text("7. Use **Sessions** to manage grouped recordings and transcriptions.")
                        Text("8. Use the **Widget** for quick actions from your Home Screen.")
                        Text("9. Tap **Help** anytime for tips and support.")
                    }
                    
                    Text("**Tips & Accessibility:**")
                        .font(.headline)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("• All controls are VoiceOver accessible and support dynamic type.")
                        Text("• Use the widget for instant recording or session access.")
                        Text("• If interrupted (call, Siri, unplug), recording will auto-resume or recover.")
                        Text("• Export or share audio/transcripts via the share sheet.")
                        Text("• For best results, set up your OpenAI API key in Settings.")
                        Text("• Check network status badge for offline/online state.")
                        Text("• Use pull-to-refresh and scroll to load more sessions.")
                        Text("• All audio files are encrypted for your privacy and security.")
                        Text("• Noise reduction can help in noisy environments—toggle as needed.")
                        Text("• If you lose a recording due to interruption, check for recovery prompts on next launch.")
                    }
                    
                    // Text("**Need Help?")
                    //     .font(.headline)
                    // Text("Contact support or visit the project README for more info. Documented limitations and known issues are listed in the README.")
                }
                .padding()
            }
            .navigationTitle("App Help & Onboarding")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
} 