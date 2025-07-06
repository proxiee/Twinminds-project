import SwiftUI

struct TranscriptionDebugView: View {
    @StateObject private var transcriptionService = TranscriptionService.shared
    @State private var statusText = ""
    @State private var testResults: [(TranscriptionMethod, Bool, String)] = []
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Status Section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Transcription Service Status")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(statusText)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.secondary)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }
                    
                    // Test Results Section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Method Availability Test")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        ForEach(testResults, id: \.0) { method, canUse, reason in
                            HStack {
                                Image(systemName: canUse ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(canUse ? .green : .red)
                                
                                VStack(alignment: .leading) {
                                    Text(method.displayName)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    
                                    if !canUse {
                                        Text(reason)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    
                    // Action Buttons
                    VStack(spacing: 10) {
                        Button("Refresh Status") {
                            updateStatus()
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button("Test All Methods") {
                            testAllMethods()
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Check API Key") {
                            checkAPIKey()
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding()
            }
            .navigationTitle("Transcription Debug")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                updateStatus()
                testAllMethods()
            }
        }
    }
    
    private func updateStatus() {
        statusText = transcriptionService.getTranscriptionStatus()
    }
    
    private func testAllMethods() {
        testResults = transcriptionService.testTranscriptionMethods()
    }
    
    private func checkAPIKey() {
        let hasKey = transcriptionService.canUseMethod(.openAI).0
        let status = hasKey ? "✅ API Key is configured" : "❌ API Key is missing or invalid"
        statusText += "\n\nAPI Key Check:\n\(status)"
    }
}

#Preview {
    TranscriptionDebugView()
} 