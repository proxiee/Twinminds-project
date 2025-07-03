import Foundation

// MARK: - OpenAI API Response Models
struct WhisperResponse: Codable {
    let text: String
}

struct WhisperError: Codable {
    let error: WhisperErrorDetail
}

struct WhisperErrorDetail: Codable {
    let message: String
    let type: String?
    let code: String?
}

// MARK: - Transcription Result
enum TranscriptionResult {
    case success(String)
    case failure(TranscriptionError)
}

enum TranscriptionError: Error, LocalizedError {
    case noAPIKey
    case networkError(Error)
    case apiError(String)
    case invalidResponse
    case fileError(String)
    case rateLimited
    case quotaExceeded
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "OpenAI API key not found. Please configure your API key."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .apiError(let message):
            return "API error: \(message)"
        case .invalidResponse:
            return "Invalid response from OpenAI API"
        case .fileError(let message):
            return "File error: \(message)"
        case .rateLimited:
            return "Rate limited by OpenAI API. Please try again later."
        case .quotaExceeded:
            return "OpenAI API quota exceeded. Please check your billing."
        case .unknown(let message):
            return "Unknown error: \(message)"
        }
    }
}

// MARK: - OpenAI Whisper Service
class OpenAIWhisperService {
    static let shared = OpenAIWhisperService()
    
    private let baseURL = "https://api.openai.com/v1/audio/transcriptions"
    private let maxRetries = 5
    private let logger = DebugLogger.shared
    
    private init() {}
    
    // MARK: - Main Transcription Method
    func transcribeAudio(fileURL: URL, completion: @escaping (TranscriptionResult) -> Void) {
        logger.logInfo("🤖 Starting OpenAI Whisper transcription for: \(fileURL.lastPathComponent)")
        
        guard let apiKey = KeychainService.shared.getOpenAIKey() else {
            logger.logError("No OpenAI API key found")
            completion(.failure(.noAPIKey))
            return
        }
        
        // Retry with exponential backoff
        transcribeWithRetry(fileURL: fileURL, apiKey: apiKey, attempt: 1, completion: completion)
    }
    
    // MARK: - Retry Logic with Exponential Backoff
    private func transcribeWithRetry(fileURL: URL, apiKey: String, attempt: Int, completion: @escaping (TranscriptionResult) -> Void) {
        logger.logInfo("🔄 Transcription attempt \(attempt)/\(maxRetries) for: \(fileURL.lastPathComponent)")
        
        performTranscription(fileURL: fileURL, apiKey: apiKey) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let transcription):
                self.logger.logSuccess("✅ OpenAI transcription successful (attempt \(attempt))")
                completion(.success(transcription))
                
            case .failure(let error):
                // Check if we should retry
                if attempt < self.maxRetries && self.shouldRetry(error: error) {
                    let delay = self.calculateBackoffDelay(attempt: attempt)
                    self.logger.logWarning("⚠️ Transcription failed (attempt \(attempt)), retrying in \(delay)s: \(error.localizedDescription)")
                    
                    DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                        self.transcribeWithRetry(fileURL: fileURL, apiKey: apiKey, attempt: attempt + 1, completion: completion)
                    }
                } else {
                    self.logger.logError("❌ OpenAI transcription failed after \(attempt) attempts: \(error.localizedDescription)")
                    completion(.failure(error))
                }
            }
        }
    }
    
    // MARK: - Core Transcription Request
    private func performTranscription(fileURL: URL, apiKey: String, completion: @escaping (TranscriptionResult) -> Void) {
        // Verify file exists and is readable
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            completion(.failure(.fileError("File does not exist: \(fileURL.path)")))
            return
        }
        
        guard let audioData = try? Data(contentsOf: fileURL) else {
            completion(.failure(.fileError("Could not read audio file: \(fileURL.path)")))
            return
        }
        
        // Create multipart form data
        let boundary = "Boundary-\(UUID().uuidString)"
        let httpBody = createMultipartBody(audioData: audioData, fileName: fileURL.lastPathComponent, boundary: boundary)
        
        // Create request
        guard let url = URL(string: baseURL) else {
            completion(.failure(.invalidResponse))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = httpBody
        request.timeoutInterval = 60.0 // 1 minute timeout
        
        // Perform request
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(.networkError(error)))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(.invalidResponse))
                return
            }
            
            guard let data = data else {
                completion(.failure(.invalidResponse))
                return
            }
            
            // Handle HTTP status codes
            switch httpResponse.statusCode {
            case 200:
                // Success - parse transcription
                self.parseSuccessResponse(data: data, completion: completion)
                
            case 429:
                // Rate limited
                completion(.failure(.rateLimited))
                
            case 402:
                // Quota exceeded
                completion(.failure(.quotaExceeded))
                
            case 400...499:
                // Client error - parse error message
                self.parseErrorResponse(data: data, statusCode: httpResponse.statusCode, completion: completion)
                
            case 500...599:
                // Server error - retry
                completion(.failure(.apiError("Server error (HTTP \(httpResponse.statusCode))")))
                
            default:
                completion(.failure(.unknown("Unexpected HTTP status: \(httpResponse.statusCode)")))
            }
        }.resume()
    }
    
    // MARK: - Response Parsing
    private func parseSuccessResponse(data: Data, completion: @escaping (TranscriptionResult) -> Void) {
        do {
            let response = try JSONDecoder().decode(WhisperResponse.self, from: data)
            let transcription = response.text.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if transcription.isEmpty {
                completion(.success("[No speech detected]"))
            } else {
                completion(.success(transcription))
            }
        } catch {
            logger.logError("Failed to parse OpenAI response", error: error)
            completion(.failure(.invalidResponse))
        }
    }
    
    private func parseErrorResponse(data: Data, statusCode: Int, completion: @escaping (TranscriptionResult) -> Void) {
        do {
            let errorResponse = try JSONDecoder().decode(WhisperError.self, from: data)
            completion(.failure(.apiError(errorResponse.error.message)))
        } catch {
            // If we can't parse the error, provide a generic message
            completion(.failure(.apiError("HTTP \(statusCode) error")))
        }
    }
    
    // MARK: - Retry Logic Helpers
    private func shouldRetry(error: TranscriptionError) -> Bool {
        switch error {
        case .networkError, .apiError, .rateLimited:
            return true
        case .noAPIKey, .invalidResponse, .fileError, .quotaExceeded, .unknown:
            return false
        }
    }
    
    private func calculateBackoffDelay(attempt: Int) -> TimeInterval {
        // Exponential backoff: 1s, 2s, 4s, 8s, 16s
        return pow(2.0, Double(attempt - 1))
    }
    
    // MARK: - Multipart Form Data Creation
    private func createMultipartBody(audioData: Data, fileName: String, boundary: String) -> Data {
        var body = Data()
        
        // Add file field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/x-caf\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add model field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("whisper-1\r\n".data(using: .utf8)!)
        
        // Add language field (optional - let Whisper auto-detect)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"language\"\r\n\r\n".data(using: .utf8)!)
        body.append("en\r\n".data(using: .utf8)!)
        
        // Close boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        return body
    }
}

// MARK: - API Key Management Helper
extension OpenAIWhisperService {
    func configureAPIKey(_ key: String) -> Bool {
        return KeychainService.shared.saveOpenAIKey(key)
    }
    
    func hasValidAPIKey() -> Bool {
        return KeychainService.shared.hasOpenAIKey()
    }
    
    func removeAPIKey() -> Bool {
        return KeychainService.shared.deleteOpenAIKey()
    }
}
