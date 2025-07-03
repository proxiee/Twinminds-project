import Foundation
import Security

class KeychainManager {
    static let shared = KeychainManager()
    
    private let service = "AudioTranscriber"
    private let openAIKeyAccount = "OpenAI_API_Key"
    
    private init() {}
    
    // MARK: - OpenAI API Key Management
    func saveOpenAIKey(_ key: String) -> Bool {
        let data = key.data(using: .utf8) ?? Data()
        
        // First try to update existing key
        let updateQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: openAIKeyAccount,
        ]
        
        let updateAttributes: [String: Any] = [
            kSecValueData as String: data
        ]
        
        let updateStatus = SecItemUpdate(updateQuery as CFDictionary, updateAttributes as CFDictionary)
        
        if updateStatus == errSecSuccess {
            print("✅ OpenAI API key updated in Keychain")
            return true
        } else if updateStatus == errSecItemNotFound {
            // Key doesn't exist, add it
            let addQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: openAIKeyAccount,
                kSecValueData as String: data,
                kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            ]
            
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            
            if addStatus == errSecSuccess {
                print("✅ OpenAI API key saved to Keychain")
                return true
            } else {
                print("❌ Failed to save OpenAI API key to Keychain: \(addStatus)")
                return false
            }
        } else {
            print("❌ Failed to update OpenAI API key in Keychain: \(updateStatus)")
            return false
        }
    }
    
    func getOpenAIKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: openAIKeyAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return key
    }
    
    func deleteOpenAIKey() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: openAIKeyAccount
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        if status == errSecSuccess || status == errSecItemNotFound {
            print("✅ OpenAI API key deleted from Keychain")
            return true
        } else {
            print("❌ Failed to delete OpenAI API key from Keychain: \(status)")
            return false
        }
    }
    
    // MARK: - Helper Methods
    func hasOpenAIKey() -> Bool {
        return getOpenAIKey() != nil
    }
    
    // For development/testing - set key from environment or hardcoded value
    func setupDevelopmentKey() {
        // In production, the API key should be entered by user through settings
        // For development, you can set this via environment variable or enter through app settings
        guard let developmentKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] else {
            print("⚠️ No OpenAI API key found in environment. Please set OPENAI_API_KEY or configure through app settings.")
            return
        }
        
        // Always update with the new key (to replace any old ones)
        let success = saveOpenAIKey(developmentKey)
        if success {
            print("🔑 OpenAI API key configured successfully from environment")
        } else {
            print("❌ Failed to configure API key")
        }
    }
}
