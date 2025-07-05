import Foundation
import AVFoundation

enum AudioQuality: String, CaseIterable, Codable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case custom = "Custom"

    var defaultSettings: AudioQualitySettings {
        switch self {
        case .low: return AudioQualitySettings(sampleRate: 8000, bitDepth: 16, channels: 1, format: .m4a, quality: self)
        case .medium: return AudioQualitySettings(sampleRate: 16000, bitDepth: 16, channels: 1, format: .m4a, quality: self)
        case .high: return AudioQualitySettings(sampleRate: 44100, bitDepth: 16, channels: 1, format: .m4a, quality: self)
        case .custom: return AudioQualitySettings(sampleRate: 16000, bitDepth: 16, channels: 1, format: .m4a, quality: self)
        }
    }
}

enum AudioFormat: String, CaseIterable, Codable {
    case m4a = "M4A"
    case caf = "CAF"

    var fileExtension: String {
        switch self {
        case .m4a: return "m4a"
        case .caf: return "caf"
        }
    }

    var avAudioFormat: AVAudioCommonFormat {
        switch self {
        case .m4a, .caf: return .pcmFormatFloat32
        }
    }
}

struct AudioQualitySettings: Codable {
    var sampleRate: Double
    var bitDepth: Int
    var channels: Int
    var format: AudioFormat
    var quality: AudioQuality
    
    // Validate settings to ensure they're supported by iOS
    var isValid: Bool {
        // iOS supports these sample rates
        let supportedSampleRates: [Double] = [8000, 16000, 22050, 44100, 48000]
        
        // iOS supports these bit depths
        let supportedBitDepths: [Int] = [16, 24, 32]
        
        // iOS supports these channel counts
        let supportedChannels: [Int] = [1, 2]
        
        return supportedSampleRates.contains(sampleRate) &&
               supportedBitDepths.contains(bitDepth) &&
               supportedChannels.contains(channels)
    }
    
    // Get a safe fallback if current settings are invalid
    var safeSettings: AudioQualitySettings {
        if isValid {
            return self
        } else {
            return AudioQualitySettings(
                sampleRate: 16000,
                bitDepth: 16,
                channels: 1,
                format: .m4a,
                quality: .medium
            )
        }
    }
}

class AudioQualityManager: ObservableObject {
    static let shared = AudioQualityManager()
    @Published var currentSettings: AudioQualitySettings
    
    private init() {
        self.currentSettings = AudioQuality.medium.defaultSettings
    }
    
    // Update settings with validation
    func updateSettings(_ newSettings: AudioQualitySettings) {
        if newSettings.isValid {
            currentSettings = newSettings
        } else {
            currentSettings = newSettings.safeSettings
        }
    }
    
    // Get current settings with safety check
    var safeCurrentSettings: AudioQualitySettings {
        return currentSettings.safeSettings
    }
} 