import Foundation
import CryptoKit
import Security

class AudioEncryptionService {
    static let shared = AudioEncryptionService()
    private let keychainKey = "AudioTranscriberEncryptionKey"

    private init() {}

    // Generate or retrieve the encryption key from Keychain
    private func getKey() throws -> SymmetricKey {
        if let keyData = loadKeyFromKeychain() {
            return SymmetricKey(data: keyData)
        } else {
            let key = SymmetricKey(size: .bits256)
            saveKeyToKeychain(key: key)
            return key
        }
    }

    private func saveKeyToKeychain(key: SymmetricKey) {
        let tag = keychainKey.data(using: .utf8)!
        let keyData = key.withUnsafeBytes { Data($0) }
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    private func loadKeyFromKeychain() -> Data? {
        let tag = keychainKey.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecSuccess {
            return result as? Data
        }
        return nil
    }

    // Encrypt a file at a given URL
    func encryptFile(at url: URL) throws {
        let key = try getKey()
        let data = try Data(contentsOf: url)
        let sealedBox = try AES.GCM.seal(data, using: key)
        let encryptedData = sealedBox.combined!
        try encryptedData.write(to: url)
    }

    // Decrypt a file at a given URL and return the data
    func decryptFile(at url: URL) throws -> Data {
        let key = try getKey()
        let encryptedData = try Data(contentsOf: url)
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
        return try AES.GCM.open(sealedBox, using: key)
    }
} 