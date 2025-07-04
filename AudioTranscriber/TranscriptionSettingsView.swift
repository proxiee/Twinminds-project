import SwiftUI

struct TranscriptionSettingsView: View {
    @StateObject private var transcriptionService = TranscriptionService.shared
    @State private var showingAPIKeyInput = false
    @State private var tempAPIKey = ""
    @State private var statusMessage = ""
    @State private var statusIsError = false
    
    private let logger = DebugLogger.shared
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "text.bubble")
                        .font(.system(size: 50))
                        .foregroundColor(.blue)
                    
                    Text("Transcription Settings")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Choose how audio should be transcribed")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    // Network status for transcription services
                    HStack {
                        NetworkStatusBadge()
                        Text("• Transcription services require internet connection")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top)
                
                Divider()
                
                // Current status
                if !statusMessage.isEmpty {
                    HStack {
                        Image(systemName: statusIsError ? "exclamationmark.triangle" : "checkmark.circle")
                            .foregroundColor(statusIsError ? .red : .green)
                        Text(statusMessage)
                            .font(.caption)
                            .foregroundColor(statusIsError ? .red : .green)
                        Spacer()
                    }
                    .padding(.horizontal)
                }
                
                // API Key Status
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "key")
                            .foregroundColor(.orange)
                        Text("OpenAI API Key")
                            .font(.headline)
                        Spacer()
                        
                        if OpenAIWhisperService.shared.hasValidAPIKey() {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        } else {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                        }
                    }
                    
                    Text(OpenAIWhisperService.shared.hasValidAPIKey() ? 
                         "API key is configured and ready to use" : 
                         "API key is required for OpenAI Whisper transcription")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    HStack {
                        Button(action: {
                            showingAPIKeyInput = true
                        }) {
                            Text(OpenAIWhisperService.shared.hasValidAPIKey() ? "Update Key" : "Add Key")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        
                        if OpenAIWhisperService.shared.hasValidAPIKey() {
                            Button(action: {
                                removeAPIKey()
                            }) {
                                Text("Remove")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                
                // Transcription Method Selection
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "waveform")
                            .foregroundColor(.blue)
                        Text("Transcription Method")
                            .font(.headline)
                        Spacer()
                    }
                    
                    ForEach(TranscriptionMethod.allCases, id: \.rawValue) { method in
                        TranscriptionMethodRow(
                            method: method,
                            isSelected: transcriptionService.preferredMethod == method,
                            isAvailable: transcriptionService.canUseMethod(method).0,
                            unavailableReason: transcriptionService.canUseMethod(method).1
                        ) {
                            selectMethod(method)
                        }
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                
                Spacer()
                
                // Test transcription button
                if transcriptionService.canUseMethod(transcriptionService.preferredMethod).0 {
                    VStack(spacing: 8) {
                        Text("Ready to transcribe with: \(transcriptionService.preferredMethod.rawValue)")
                            .font(.caption)
                            .foregroundColor(.green)
                        
                        Text("Record audio in the main app to test transcription")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .padding()
            .navigationTitle("Settings")
            // .navigationBarTitleDisplayMode(.inline) // iOS only
            .onAppear {
                transcriptionService.loadPreferredMethod()
                refreshStatus()
            }
        }
        .sheet(isPresented: $showingAPIKeyInput) {
            APIKeyInputView(tempAPIKey: $tempAPIKey, onSave: { key in
                saveAPIKey(key)
            })
        }
    }
    
    // MARK: - Actions
    private func selectMethod(_ method: TranscriptionMethod) {
        let (canUse, reason) = transcriptionService.canUseMethod(method)
        
        if canUse {
            transcriptionService.setPreferredMethod(method)
            statusMessage = "Transcription method set to: \(method.rawValue)"
            statusIsError = false
            logger.logInfo("User selected transcription method: \(method.rawValue)")
        } else {
            statusMessage = reason ?? "Cannot use this transcription method"
            statusIsError = true
        }
        
        // Clear status after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            statusMessage = ""
        }
    }
    
    private func saveAPIKey(_ key: String) {
        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedKey.isEmpty else {
            statusMessage = "API key cannot be empty"
            statusIsError = true
            return
        }
        
        guard trimmedKey.hasPrefix("sk-") else {
            statusMessage = "Invalid API key format. OpenAI keys start with 'sk-'"
            statusIsError = true
            return
        }
        
        if OpenAIWhisperService.shared.configureAPIKey(trimmedKey) {
            statusMessage = "API key saved successfully"
            statusIsError = false
            logger.logInfo("OpenAI API key configured successfully")
            
            // If no method is selected or current method can't be used, auto-select OpenAI with fallback
            let (canUseCurrent, _) = transcriptionService.canUseMethod(transcriptionService.preferredMethod)
            if !canUseCurrent {
                transcriptionService.setPreferredMethod(.openAIWithFallback)
            }
        } else {
            statusMessage = "Failed to save API key"
            statusIsError = true
            logger.logError("Failed to save OpenAI API key")
        }
        
        // Clear status after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            statusMessage = ""
        }
    }
    
    private func removeAPIKey() {
        if OpenAIWhisperService.shared.removeAPIKey() {
            statusMessage = "API key removed"
            statusIsError = false
            logger.logInfo("OpenAI API key removed")
            
            // Switch to local method if current method requires API key
            if transcriptionService.preferredMethod.requiresAPIKey {
                transcriptionService.setPreferredMethod(.local)
            }
        } else {
            statusMessage = "Failed to remove API key"
            statusIsError = true
        }
        
        // Clear status after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            statusMessage = ""
        }
    }
    
    private func refreshStatus() {
        transcriptionService.loadPreferredMethod()
    }
}

// MARK: - Transcription Method Row
struct TranscriptionMethodRow: View {
    let method: TranscriptionMethod
    let isSelected: Bool
    let isAvailable: Bool
    let unavailableReason: String?
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(method.rawValue)
                            .font(.body)
                            .fontWeight(isSelected ? .semibold : .regular)
                        
                        if method.requiresAPIKey {
                            Image(systemName: "key")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        
                        Spacer()
                        
                        if !isAvailable {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }
                    
                    Text(method.description)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.leading)
                    
                    if !isAvailable, let reason = unavailableReason {
                        Text(reason)
                            .font(.caption2)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.leading)
                    }
                }
                
                Spacer()
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .disabled(!isAvailable)
        .opacity(isAvailable ? 1.0 : 0.6)
    }
}

// MARK: - API Key Input View
struct APIKeyInputView: View {
    @Binding var tempAPIKey: String
    let onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Image(systemName: "key")
                        .font(.system(size: 40))
                        .foregroundColor(.orange)
                    
                    Text("OpenAI API Key")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Enter your OpenAI API key to enable Whisper transcription")
                        .font(.body)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .padding(.top)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("API Key")
                        .font(.headline)
                    
                    SecureField("sk-proj-...", text: $tempAPIKey)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                    
                    Text("Your API key is stored securely in the system Keychain")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("How to get an API key:")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text("1. Visit platform.openai.com\n2. Sign in to your account\n3. Go to API Keys section\n4. Create a new secret key\n5. Copy and paste it here")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                
                Spacer()
                
                HStack {
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button("Save") {
                        onSave(tempAPIKey)
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(tempAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding()
            .navigationTitle("API Key")
            // .navigationBarTitleDisplayMode(.inline) // iOS only
        }
    }
}

#Preview {
    TranscriptionSettingsView()
}
