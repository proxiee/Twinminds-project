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
                        Text("• High-quality audio recording (single or 30s segments)")
                        Text("• Real-time audio level visualization")
                        Text("• Background recording & interruption recovery")
                        Text("• Transcription with OpenAI Whisper or local fallback")
                        Text("• Session & segment management with SwiftData")
                        Text("• Export/share audio and transcripts")
                        Text("• Widget for quick access")
                    }
                    
                    Text("**How to Use:**")
                        .font(.headline)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("1. Tap the **Record** button to start recording.")
                        Text("2. Use the **Pause/Resume** button to temporarily halt/resume.")
                        Text("3. Tap **Stop** to finish and save.")
                        Text("4. View, play, transcribe, or share recordings from the list.")
                        Text("5. Use **Settings** to configure transcription and quality.")
                        Text("6. Use **Sessions** to manage grouped recordings.")
                        Text("7. Tap **Help** anytime for tips and support.")
                    }
                    
                    Text("**Tips & Accessibility:**")
                        .font(.headline)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("• All controls are VoiceOver accessible.")
                        Text("• Use the widget for quick actions from your Home Screen.")
                        Text("• If you lose a recording due to interruption, check for recovery prompts on next launch.")
                        Text("• Export or share audio/transcripts via the share sheet.")
                        Text("• For best results, set up your OpenAI API key in Settings.")
                    }
                    
                    Text("**Need Help?")
                        .font(.headline)
                    Text("Contact support or visit the project README for more info.")
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