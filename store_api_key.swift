#!/usr/bin/env swift

import Foundation
import Security

class KeychainService {
    static let shared = KeychainService()
    
    private let service = "AudioTranscriber"
    private let openAIKeyAccount = "OpenAI_API_Key"
    
    private init() {}
    
    func saveOpenAIKey(_ key: String) -> Bool {
        let data = key.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: openAIKeyAccount,
            kSecValueData as String: data
        ]
        
        // Delete existing item first
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    func getOpenAIKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: openAIKeyAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return key
    }
}

// Store the API key (replace with your actual API key)
// let apiKey = "your-openai-api-key-here"
// let success = KeychainService.shared.saveOpenAIKey(apiKey)

// Uncomment the code below after setting your API key
/*
if success {
    print("✅ OpenAI API Key stored successfully in Keychain")
    
    // Verify it was stored
    if let retrievedKey = KeychainService.shared.getOpenAIKey() {
        let maskedKey = String(retrievedKey.prefix(7)) + "..." + String(retrievedKey.suffix(4))
        print("✅ Verified: Key retrieved successfully: \(maskedKey)")
    } else {
        print("❌ Error: Could not retrieve stored key")
    }
} else {
    print("❌ Failed to store API Key in Keychain")
}
*/
