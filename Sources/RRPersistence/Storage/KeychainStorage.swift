import Foundation
import Security
import RRFoundation

// MARK: - Keychain Storage

/// Wrapper for Keychain that implements StorageProtocol and EncryptedStorageProtocol
public final class KeychainStorage: StorageProtocol, EncryptedStorageProtocol {
    public typealias Key = String
    public typealias Value = Data
    
    private let service: String
    private let accessControl: SecAccessControl?
    private let accessibility: CFString
    
    /// Initializes KeychainStorage with a service name
    /// - Parameters:
    ///   - service: The service name for the keychain items
    ///   - accessibility: The accessibility level (defaults to kSecAttrAccessibleWhenUnlocked)
    ///   - accessControl: Optional access control for additional security
    public init(
        service: String,
        accessibility: CFString = kSecAttrAccessibleWhenUnlocked,
        accessControl: SecAccessControl? = nil
    ) {
        self.service = service
        self.accessibility = accessibility
        self.accessControl = accessControl
    }
    
    // MARK: - StorageProtocol Implementation
    
    @discardableResult
    public func store(_ value: Value, for key: Key) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: value,
            kSecAttrAccessible as String: accessibility
        ]
        
        // Check if item already exists
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status == errSecDuplicateItem {
            // Item exists, update it
            let updateQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: key
            ]
            
            let updateAttributes: [String: Any] = [
                kSecValueData as String: value,
                kSecAttrAccessible as String: accessibility
            ]
            
            return SecItemUpdate(updateQuery as CFDictionary, updateAttributes as CFDictionary) == errSecSuccess
        }
        
        return status == errSecSuccess
    }
    
    public func retrieve(for key: Key) -> Value? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data else {
            return nil
        }
        
        return data
    }
    
    @discardableResult
    public func remove(for key: Key) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        return SecItemDelete(query as CFDictionary) == errSecSuccess
    }
    
    @discardableResult
    public func clear() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        
        return SecItemDelete(query as CFDictionary) == errSecSuccess
    }
    
    public func exists(for key: Key) -> Bool {
        return retrieve(for: key) != nil
    }
    
    // MARK: - EncryptedStorageProtocol Implementation
    
    @discardableResult
    public func storeEncrypted(_ value: Value, for key: Key, encryptionKey: Data) -> Bool {
        // For keychain, we rely on the system's encryption
        // The encryptionKey parameter is kept for protocol compliance
        // but the actual encryption is handled by the keychain
        return store(value, for: key)
    }
    
    public func retrieveDecrypted(for key: Key, encryptionKey: Data) -> Value? {
        // For keychain, decryption is handled automatically by the system
        // The encryptionKey parameter is kept for protocol compliance
        return retrieve(for: key)
    }
}

// MARK: - Type-Safe Keychain Extensions

extension KeychainStorage {
    /// Stores a Codable value for a given key
    /// - Parameters:
    ///   - value: The Codable value to store
    ///   - key: The key to associate with the value
    /// - Returns: Success status of the operation
    @discardableResult
    public func store<T: Codable>(_ value: T, for key: Key) -> Bool {
        do {
            let data = try JSONEncoder().encode(value)
            return store(data, for: key)
        } catch {
            Logger.error("Failed to encode value for key '\(key)': \(error)")
            return false
        }
    }
    
    /// Retrieves a Codable value for a given key
    /// - Parameter key: The key to retrieve the value for
    /// - Returns: The decoded value, if any
    public func retrieve<T: Codable>(_ type: T.Type, for key: Key) -> T? {
        guard let data = retrieve(for: key) else {
            return nil
        }
        
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            Logger.error("Failed to decode value for key '\(key)': \(error)")
            return nil
        }
    }
    
    /// Stores a string value for a given key
    /// - Parameters:
    ///   - value: The string value to store
    ///   - key: The key to associate with the value
    /// - Returns: Success status of the operation
    @discardableResult
    public func store(_ value: String, for key: Key) -> Bool {
        guard let data = value.data(using: .utf8) else {
            Logger.error("Failed to convert string to data for key '\(key)'")
            return false
        }
        return store(data, for: key)
    }
    
    /// Retrieves a string value for a given key
    /// - Parameter key: The key to retrieve the value for
    /// - Returns: The string value, if any
    public func retrieveString(for key: Key) -> String? {
        guard let data = retrieve(for: key) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
}

// MARK: - Keychain Error Handling

extension KeychainStorage {
    /// Returns a human-readable description of the keychain status
    /// - Parameter status: The keychain status code
    /// - Returns: A string description of the status
    public static func statusDescription(_ status: OSStatus) -> String {
        switch status {
        case errSecSuccess:
            return "Success"
        case errSecDuplicateItem:
            return "Item already exists"
        case errSecItemNotFound:
            return "Item not found"
        case errSecParam:
            return "Invalid parameter"
        case errSecAllocate:
            return "Failed to allocate memory"
        case errSecAuthFailed:
            return "Authentication failed"
        case errSecNotAvailable:
            return "Keychain not available"
        case errSecReadOnly:
            return "Keychain is read-only"
        case errSecDecode:
            return "Failed to decode data"
        case errSecUnimplemented:
            return "Operation not implemented"
        default:
            return "Unknown error: \(status)"
        }
    }
}
