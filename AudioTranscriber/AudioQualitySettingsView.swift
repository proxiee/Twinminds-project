import SwiftUI

struct AudioQualitySettingsView: View {
    @StateObject private var qualityManager = AudioQualityManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Preset")) {
                    Picker("Preset", selection: $qualityManager.currentSettings.quality) {
                        ForEach(AudioQuality.allCases, id: \.self) { quality in
                            Text(quality.rawValue).tag(quality)
                        }
                    }
                }
                
                Section(header: Text("Current Settings")) {
                    HStack {
                        Text("Sample Rate")
                        Spacer()
                        Text("\(Int(qualityManager.safeCurrentSettings.sampleRate)) Hz")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Bit Depth")
                        Spacer()
                        Text("\(qualityManager.safeCurrentSettings.bitDepth)-bit")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Format")
                        Spacer()
                        Text(qualityManager.safeCurrentSettings.format.rawValue)
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Channels")
                        Spacer()
                        Text(qualityManager.safeCurrentSettings.channels == 1 ? "Mono" : "Stereo")
                            .foregroundColor(.secondary)
                    }
                }
                
                if qualityManager.currentSettings.quality == .custom {
                    Section(header: Text("Custom Settings")) {
                        Picker("Sample Rate", selection: $qualityManager.currentSettings.sampleRate) {
                            ForEach([8000, 16000, 22050, 44100, 48000], id: \.self) { rate in
                                Text("\(Int(rate)) Hz").tag(Double(rate))
                            }
                        }
                        Picker("Bit Depth", selection: $qualityManager.currentSettings.bitDepth) {
                            ForEach([16, 24, 32], id: \.self) { depth in
                                Text("\(depth)-bit").tag(depth)
                            }
                        }
                        Picker("Format", selection: $qualityManager.currentSettings.format) {
                            ForEach(AudioFormat.allCases, id: \.self) { format in
                                Text(format.rawValue).tag(format)
                            }
                        }
                        Picker("Channels", selection: $qualityManager.currentSettings.channels) {
                            Text("Mono (1)").tag(1)
                            Text("Stereo (2)").tag(2)
                        }
                    }
                }
            }
            .navigationTitle("Audio Quality")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
} 