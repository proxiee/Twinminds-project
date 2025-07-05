import Foundation
import os.log

// logging utility - writes to both console and file for debugging
class DebugLogger {
    static let shared = DebugLogger()
    private let logger = OSLog(subsystem: "com.audiotranscriber", category: "debug")
    private let logFileURL: URL
    
    private init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        logFileURL = documentsPath.appendingPathComponent("AudioTranscriber_Debug.log")
        
        // Create initial log entry
        log("🚀 DebugLogger initialized")
        log("📁 Log file path: \(logFileURL.path)")
    }
    
    // main logging function - writes everywhere
    func log(_ message: String, level: OSLogType = .default, function: String = #function, file: String = #file, line: Int = #line) {
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let timestamp = DateFormatter.logFormatter.string(from: Date())
        let logMessage = "[\(timestamp)] [\(levelString(level))] \(fileName):\(line) \(function) - \(message)"
        
        // Log to system log
        os_log("%{public}@", log: logger, type: level, logMessage)
        
        // Write to file
        writeToFile(logMessage)
        
        // Also print to console for immediate visibility
        print(logMessage)
    }
    
    // log errors with full details
    func logError(_ message: String, error: Error? = nil, function: String = #function, file: String = #file, line: Int = #line) {
        var fullMessage = "❌ ERROR: \(message)"
        if let error = error {
            fullMessage += " | Error: \(error.localizedDescription)"
            if let nsError = error as NSError? {
                fullMessage += " | Domain: \(nsError.domain) | Code: \(nsError.code)"
                if let userInfo = nsError.userInfo as? [String: Any], !userInfo.isEmpty {
                    fullMessage += " | UserInfo: \(userInfo)"
                }
            }
        }
        log(fullMessage, level: .error, function: function, file: file, line: line)
    }
    
    // log warnings
    func logWarning(_ message: String, function: String = #function, file: String = #file, line: Int = #line) {
        log("⚠️ WARNING: \(message)", level: .info, function: function, file: file, line: line)
    }
    
    // log info messages
    func logInfo(_ message: String, function: String = #function, file: String = #file, line: Int = #line) {
        log("ℹ️ INFO: \(message)", level: .info, function: function, file: file, line: line)
    }
    
    // log success messages
    func logSuccess(_ message: String, function: String = #function, file: String = #file, line: Int = #line) {
        log("✅ SUCCESS: \(message)", level: .default, function: function, file: file, line: line)
    }
    
    // convert log level to string
    private func levelString(_ level: OSLogType) -> String {
        switch level {
        case .error: return "ERROR"
        case .fault: return "FAULT"
        case .info: return "INFO"
        case .debug: return "DEBUG"
        default: return "DEFAULT"
        }
    }
    
    // write log message to file
    private func writeToFile(_ message: String) {
        let messageWithNewline = message + "\n"
        
        if let data = messageWithNewline.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logFileURL.path) {
                // Append to existing file
                if let fileHandle = try? FileHandle(forWritingTo: logFileURL) {
                    defer { fileHandle.closeFile() }
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                }
            } else {
                // Create new file
                try? data.write(to: logFileURL)
            }
        }
    }
    
    // get all log contents for debugging
    func getLogFileContents() -> String {
        guard let data = try? Data(contentsOf: logFileURL),
              let contents = String(data: data, encoding: .utf8) else {
            return "Unable to read log file"
        }
        return contents
    }
    
    // clear the log file
    func clearLog() {
        try? FileManager.default.removeItem(at: logFileURL)
        log("🧹 Log file cleared")
    }
    
    // get log file path
    func getLogFilePath() -> String {
        return logFileURL.path
    }
}

extension DateFormatter {
    static let logFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()
}
