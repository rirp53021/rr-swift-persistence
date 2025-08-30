import Foundation
import Security
import RRFoundation

// MARK: - Keychain Storage

/// Wrapper for Keychain that implements StorageProtocol and EncryptedStorageProtocol with enhanced error handling and logging
public final class KeychainStorage: StorageProtocol, EncryptedStorageProtocol {
    public typealias Key = String
    public typealias Value = Data
    
    private let service: String
    private let accessControl: SecAccessControl?
    private let accessibility: CFString
    private let logger: Logger
    
    /// Initializes KeychainStorage with a service name
    /// - Parameters:
    ///   - service: The service name for the keychain items
    ///   - accessibility: The accessibility level (defaults to kSecAttrAccessibleWhenUnlocked)
    ///   - accessControl: Optional access control for additional security
    ///   - logger: Custom logger instance (defaults to shared logger with "Keychain" category)
    public init(
        service: String,
        accessibility: CFString = kSecAttrAccessibleWhenUnlocked,
        accessControl: SecAccessControl? = nil,
        logger: Logger? = nil
    ) {
        self.service = service
        self.accessibility = accessibility
        self.accessControl = accessControl
        self.logger = logger ?? Logger.withCategory("Keychain")
    }
    
    // MARK: - StorageProtocol Implementation
    
    public func store(_ value: Value, for key: Key) -> Result<Void, StorageError> {
        let startTime = Date()
        
        let result = Result.catching {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: self.service,
                kSecAttrAccount as String: key,
                kSecValueData as String: value,
                kSecAttrAccessible as String: self.accessibility
            ]
            
            // Check if item already exists
            let status = SecItemAdd(query as CFDictionary, nil)
            
            if status == errSecDuplicateItem {
                // Item exists, update it
                let updateQuery: [String: Any] = [
                    kSecClass as String: kSecClassGenericPassword,
                    kSecAttrService as String: self.service,
                    kSecAttrAccount as String: key
                ]
                
                let updateAttributes: [String: Any] = [
                    kSecValueData as String: value,
                    kSecAttrAccessible as String: self.accessibility
                ]
                
                let updateStatus = SecItemUpdate(updateQuery as CFDictionary, updateAttributes as CFDictionary)
                guard updateStatus == errSecSuccess else {
                    throw StorageError.fromKeychainStatus(updateStatus)
                }
            } else if status != errSecSuccess {
                throw StorageError.fromKeychainStatus(status)
            }
        }
        .mapError { error in
            let storageError = StorageError.from(error)
            storageError.log(context: "Failed to store value for key: \(key)", operation: "store")
            return storageError
        }
        
        result.onSuccess { _ in
            let duration = Date().timeIntervalSince(startTime)
            self.logger.logPerformance(operation: "store", duration: duration)
            self.logger.debug("Successfully stored value for key: \(key)")
        }
        
        return result
    }
    
    public func retrieve(for key: Key) -> Result<Value?, StorageError> {
        let startTime = Date()
        
        let result = Result.catching {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: self.service,
                kSecAttrAccount as String: key,
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne
            ]
            
            var result: AnyObject?
            let status = SecItemCopyMatching(query as CFDictionary, &result)
            
            if status == errSecItemNotFound {
                return nil as Data?
            } else if status != errSecSuccess {
                throw StorageError.fromKeychainStatus(status)
            }
            
            guard let data = result as? Data else {
                throw StorageError.invalidData
            }
            
            return data
        }
        .mapError { error in
            let storageError = StorageError.from(error)
            storageError.log(context: "Failed to retrieve value for key: \(key)", operation: "retrieve")
            return storageError
        }
        
        result.onSuccess { value in
            let duration = Date().timeIntervalSince(startTime)
            self.logger.logPerformance(operation: "retrieve", duration: duration)
            if value != nil {
                self.logger.debug("Successfully retrieved value for key: \(key)")
            } else {
                self.logger.debug("No value found for key: \(key)")
            }
        }
        
        return result
    }
    
    public func remove(for key: Key) -> Result<Void, StorageError> {
        let startTime = Date()
        
        let result = Result.catching {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: self.service,
                kSecAttrAccount as String: key
            ]
            
            let status = SecItemDelete(query as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else {
                throw StorageError.fromKeychainStatus(status)
            }
        }
        .mapError { error in
            let storageError = StorageError.from(error)
            storageError.log(context: "Failed to remove value for key: \(key)", operation: "remove")
            return storageError
        }
        
        result.onSuccess { _ in
            let duration = Date().timeIntervalSince(startTime)
            self.logger.logPerformance(operation: "remove", duration: duration)
            self.logger.debug("Successfully removed value for key: \(key)")
        }
        
        return result
    }
    
    public func clear() -> Result<Void, StorageError> {
        let startTime = Date()
        
        let result = Result.catching {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: self.service
            ]
            
            let status = SecItemDelete(query as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else {
                throw StorageError.fromKeychainStatus(status)
            }
        }
        .mapError { error in
            let storageError = StorageError.from(error)
            storageError.log(context: "Failed to clear keychain", operation: "clear")
            return storageError
        }
        
        result.onSuccess { _ in
            let duration = Date().timeIntervalSince(startTime)
            self.logger.logPerformance(operation: "clear", duration: duration)
            self.logger.debug("Successfully cleared keychain for service: \(self.service)")
        }
        
        return result
    }
    
    public func exists(for key: Key) -> Result<Bool, StorageError> {
        let startTime = Date()
        
        let result = retrieve(for: key)
            .map { $0 != nil }
        
        result.onSuccess { exists in
            let duration = Date().timeIntervalSince(startTime)
            self.logger.logPerformance(operation: "exists", duration: duration)
            self.logger.debug("Key '\(key)' exists: \(exists)")
        }
        
        return result
    }
    
    // MARK: - EncryptedStorageProtocol Implementation
    
    public func storeEncrypted(_ value: Value, for key: Key, encryptionKey: Data) -> Result<Void, StorageError> {
        // For keychain, we rely on the system's encryption
        // The encryptionKey parameter is kept for protocol compliance
        // but the actual encryption is handled by the keychain
        return store(value, for: key)
    }
    
    public func retrieveDecrypted(for key: Key, encryptionKey: Data) -> Result<Value?, StorageError> {
        // For keychain, decryption is handled automatically by the system
        // The encryptionKey parameter is kept for protocol compliance
        return retrieve(for: key)
    }
}

// MARK: - Type-Safe Keychain Extensions

public extension KeychainStorage {
    
    /// Stores a Codable value for a given key
    /// - Parameters:
    ///   - value: The Codable value to store
    ///   - key: The key to associate with the value
    /// - Returns: Result indicating success or failure with error details
    func store<T: Codable>(_ value: T, for key: Key) -> Result<Void, StorageError> {
        let startTime = Date()
        
        let result = Result.catching {
            try JSONEncoder().encode(value)
        }
        .mapError { error in
            StorageError.encodingFailed(key)
        }
        .flatMap { data in
            self.store(data, for: key)
        }
        
        result.onSuccess { _ in
            let duration = Date().timeIntervalSince(startTime)
            self.logger.logPerformance(operation: "storeCodable", duration: duration)
            self.logger.debug("Successfully stored Codable value for key: \(key)")
        }
        
        return result
    }
    
    /// Retrieves a Codable value for a given key
    /// - Parameter key: The key to retrieve the value for
    /// - Returns: Result containing the decoded value or error
    func retrieve<T: Codable>(_ type: T.Type, for key: Key) -> Result<T?, StorageError> {
        let startTime = Date()
        
        let result = retrieve(for: key)
            .flatMap { value -> Result<T?, StorageError> in
                guard let data = value else {
                    return .success(nil)
                }
                
                return Result.catching {
                    try JSONDecoder().decode(type, from: data)
                }
                .mapError { error in
                    StorageError.decodingFailed(key)
                }
            }
        
        result.onSuccess { value in
            let duration = Date().timeIntervalSince(startTime)
            self.logger.logPerformance(operation: "retrieveCodable", duration: duration)
            if value != nil {
                self.logger.debug("Successfully retrieved Codable value for key: \(key)")
            } else {
                self.logger.debug("No Codable value found for key: \(key)")
            }
        }
        
        return result
    }
    
    /// Stores a string value for a given key
    /// - Parameters:
    ///   - value: The string value to store
    ///   - key: The key to associate with the value
    /// - Returns: Result indicating success or failure with error details
    func store(_ value: String, for key: Key) -> Result<Void, StorageError> {
        guard let data = value.data(using: .utf8) else {
            let error = StorageError.encodingFailed(key)
            error.log(context: "Failed to convert string to UTF-8 data", operation: "storeString")
            return .failure(error)
        }
        return store(data, for: key)
    }
    
    /// Retrieves a string value for a given key
    /// - Parameter key: The key to retrieve the value for
    /// - Returns: Result containing the string value or error
    func retrieveString(for key: Key) -> Result<String?, StorageError> {
        return retrieve(for: key)
            .map { data in
                guard let data = data else { return nil }
                return String(data: data, encoding: .utf8)
            }
            .mapError { error in
                StorageError.decodingFailed(key)
            }
    }
}

// MARK: - Keychain Error Handling

public extension KeychainStorage {
    
    /// Returns a human-readable description of the keychain status
    /// - Parameter status: The keychain status code
    /// - Returns: A string description of the status
    static func statusDescription(_ status: OSStatus) -> String {
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

// MARK: - Convenience Extensions

public extension KeychainStorage {
    
    /// Creates a KeychainStorage instance with a specific category for logging
    /// - Parameters:
    ///   - service: The service name
    ///   - category: The logging category
    /// - Returns: A new KeychainStorage instance
    static func withCategory(_ service: String, category: String) -> KeychainStorage {
        let logger = Logger.withCategory(category)
        return KeychainStorage(service: service, logger: logger)
    }
}