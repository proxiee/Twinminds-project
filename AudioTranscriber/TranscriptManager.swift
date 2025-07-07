import Foundation

// manages cached transcripts for audio files
enum TranscriptStatus {
    case notGenerated
    case generating
    case available
    case failed
}

class TranscriptManager: ObservableObject {
    static let shared = TranscriptManager()
    
    private let userDefaults = UserDefaults.standard
    private let transcriptsKey = "CachedTranscripts"
    
    @Published private var transcriptCache: [String: String] = [:]
    
    private init() {
        loadTranscripts()
    }
    
    // MARK: - Public Interface
    
    /// Get cached transcript for a file URL
    func getTranscript(for url: URL) -> String? {
        let key = generateKey(for: url)
        return transcriptCache[key]
    }
    
    /// Save transcript for a file URL
    func saveTranscript(_ transcript: String, for url: URL) {
        let key = generateKey(for: url)
        transcriptCache[key] = transcript
        saveTranscripts()
    }
    
    /// Check if transcript exists for a file URL
    func hasTranscript(for url: URL) -> Bool {
        let key = generateKey(for: url)
        return transcriptCache[key] != nil && !transcriptCache[key]!.isEmpty
    }
    
    /// Remove transcript for a file URL
    func removeTranscript(for url: URL) {
        let key = generateKey(for: url)
        transcriptCache.removeValue(forKey: key)
        saveTranscripts()
    }
    
    /// Clear all cached transcripts
    func clearAllTranscripts() {
        transcriptCache.removeAll()
        saveTranscripts()
    }
    
    /// Get all cached transcripts count
    var cachedTranscriptsCount: Int {
        return transcriptCache.count
    }
    
    // MARK: - Private Methods
    
    // make a unique key for each file
    private func generateKey(for url: URL) -> String {
        // Use filename and file size as key to uniquely identify files
        let fileName = url.lastPathComponent
        let fileSize = getFileSize(url: url)
        return "\(fileName)_\(fileSize)"
    }
    
    // get file size for key
    private func getFileSize(url: URL) -> String {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            if let size = attributes[.size] as? NSNumber {
                return String(size.int64Value)
            }
        } catch {
            print("Error getting file size for transcript key: \(error)")
        }
        return "0"
    }
    
    // load transcripts from user defaults
    private func loadTranscripts() {
        if let data = userDefaults.data(forKey: transcriptsKey),
           let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
            transcriptCache = decoded
        }
    }
    
    // save transcripts to user defaults
    private func saveTranscripts() {
        if let encoded = try? JSONEncoder().encode(transcriptCache) {
            userDefaults.set(encoded, forKey: transcriptsKey)
        }
    }
}

// MARK: - Transcript Status Extension

extension TranscriptManager {
    
    /// Get the status of transcription for a file
    func getTranscriptStatus(for url: URL) -> TranscriptStatus {
        if hasTranscript(for: url) {
            return .available
        } else {
            return .notGenerated
        }
    }
    
    /// Get transcript info for display
    func getTranscriptInfo(for url: URL) -> (hasTranscript: Bool, preview: String) {
        guard let transcript = getTranscript(for: url) else {
            return (false, "")
        }
        
        let preview = String(transcript.prefix(100))
        return (true, preview)
    }
}
