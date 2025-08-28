import Foundation
import RRFoundation

// MARK: - Storage Protocols

/// Protocol defining the basic storage operations
public protocol StorageProtocol {
    /// The type of key used for storage
    associatedtype Key: Hashable
    
    /// The type of value that can be stored
    associatedtype Value
    
    /// Stores a value for a given key
    /// - Parameters:
    ///   - value: The value to store
    ///   - key: The key to associate with the value
    /// - Returns: Success status of the operation
    @discardableResult
    func store(_ value: Value, for key: Key) -> Bool
    
    /// Retrieves a value for a given key
    /// - Parameter key: The key to retrieve the value for
    /// - Returns: The stored value, if any
    func retrieve(for key: Key) -> Value?
    
    /// Removes a value for a given key
    /// - Parameter key: The key to remove the value for
    /// - Returns: Success status of the operation
    @discardableResult
    func remove(for key: Key) -> Bool
    
    /// Removes all stored values
    /// - Returns: Success status of the operation
    @discardableResult
    func clear() -> Bool
    
    /// Checks if a value exists for a given key
    /// - Parameter key: The key to check
    /// - Returns: True if a value exists, false otherwise
    func exists(for key: Key) -> Bool
}

/// Protocol for storage that supports batch operations
public protocol BatchStorageProtocol: StorageProtocol {
    /// Stores multiple key-value pairs
    /// - Parameter items: Dictionary of key-value pairs to store
    /// - Returns: Success status of the operation
    @discardableResult
    func storeBatch(_ items: [Key: Value]) -> Bool
    
    /// Retrieves multiple values for given keys
    /// - Parameter keys: Array of keys to retrieve values for
    /// - Returns: Dictionary of key-value pairs
    func retrieveBatch(for keys: [Key]) -> [Key: Value]
    
    /// Removes multiple values for given keys
    /// - Parameter keys: Array of keys to remove values for
    /// - Returns: Success status of the operation
    @discardableResult
    func removeBatch(for keys: [Key]) -> Bool
}

/// Protocol for storage that supports expiration
public protocol ExpirableStorageProtocol: StorageProtocol {
    /// Stores a value with an expiration date
    /// - Parameters:
    ///   - value: The value to store
    ///   - key: The key to associate with the value
    ///   - expirationDate: When the value should expire
    /// - Returns: Success status of the operation
    @discardableResult
    func store(_ value: Value, for key: Key, expirationDate: Date) -> Bool
    
    /// Retrieves a value if it hasn't expired
    /// - Parameter key: The key to retrieve the value for
    /// - Returns: The stored value if not expired, nil otherwise
    func retrieveValid(for key: Key) -> Value?
    
    /// Removes all expired values
    /// - Returns: Number of expired values removed
    @discardableResult
    func removeExpired() -> Int
}

/// Protocol for storage that supports encryption
public protocol EncryptedStorageProtocol: StorageProtocol {
    /// Stores an encrypted value for a given key
    /// - Parameters:
    ///   - value: The value to encrypt and store
    ///   - key: The key to associate with the value
    ///   - encryptionKey: The key used for encryption
    /// - Returns: Success status of the operation
    @discardableResult
    func storeEncrypted(_ value: Value, for key: Key, encryptionKey: Data) -> Bool
    
    /// Retrieves and decrypts a value for a given key
    /// - Parameters:
    ///   - key: The key to retrieve the value for
    ///   - encryptionKey: The key used for decryption
    /// - Returns: The decrypted value, if any
    func retrieveDecrypted(for key: Key, encryptionKey: Data) -> Value?
}
