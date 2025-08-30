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
    /// - Returns: Result indicating success or failure with error details
    func store(_ value: Value, for key: Key) -> Result<Void, StorageError>
    
    /// Retrieves a value for a given key
    /// - Parameter key: The key to retrieve the value for
    /// - Returns: Result containing the stored value or error
    func retrieve(for key: Key) -> Result<Value?, StorageError>
    
    /// Removes a value for a given key
    /// - Parameter key: The key to remove the value for
    /// - Returns: Result indicating success or failure with error details
    func remove(for key: Key) -> Result<Void, StorageError>
    
    /// Removes all stored values
    /// - Returns: Result indicating success or failure with error details
    func clear() -> Result<Void, StorageError>
    
    /// Checks if a value exists for a given key
    /// - Parameter key: The key to check
    /// - Returns: Result containing existence status or error
    func exists(for key: Key) -> Result<Bool, StorageError>
}

/// Protocol for storage that supports batch operations
public protocol BatchStorageProtocol: StorageProtocol {
    /// Stores multiple key-value pairs
    /// - Parameter items: Dictionary of key-value pairs to store
    /// - Returns: Result indicating success or failure with error details
    func storeBatch(_ items: [Key: Value]) -> Result<Void, StorageError>
    
    /// Retrieves multiple values for given keys
    /// - Parameter keys: Array of keys to retrieve values for
    /// - Returns: Result containing dictionary of key-value pairs or error
    func retrieveBatch(for keys: [Key]) -> Result<[Key: Value], StorageError>
    
    /// Removes multiple values for given keys
    /// - Parameter keys: Array of keys to remove values for
    /// - Returns: Result indicating success or failure with error details
    func removeBatch(for keys: [Key]) -> Result<Void, StorageError>
}

/// Protocol for storage that supports expiration
public protocol ExpirableStorageProtocol: StorageProtocol {
    /// Stores a value with an expiration date
    /// - Parameters:
    ///   - value: The value to store
    ///   - key: The key to associate with the value
    ///   - expirationDate: When the value should expire
    /// - Returns: Result indicating success or failure with error details
    func store(_ value: Value, for key: Key, expirationDate: Date) -> Result<Void, StorageError>
    
    /// Retrieves a value if it hasn't expired
    /// - Parameter key: The key to retrieve the value for
    /// - Returns: Result containing the stored value if not expired, nil otherwise, or error
    func retrieveValid(for key: Key) -> Result<Value?, StorageError>
    
    /// Removes all expired values
    /// - Returns: Result containing the number of expired values removed or error
    func removeExpired() -> Result<Int, StorageError>
}

/// Protocol for storage that supports encryption
public protocol EncryptedStorageProtocol: StorageProtocol {
    /// Stores an encrypted value for a given key
    /// - Parameters:
    ///   - value: The value to encrypt and store
    ///   - key: The key to associate with the value
    ///   - encryptionKey: The key used for encryption
    /// - Returns: Result indicating success or failure with error details
    func storeEncrypted(_ value: Value, for key: Key, encryptionKey: Data) -> Result<Void, StorageError>
    
    /// Retrieves and decrypts a value for a given key
    /// - Parameters:
    ///   - key: The key to retrieve the value for
    ///   - encryptionKey: The key used for decryption
    /// - Returns: Result containing the decrypted value or error
    func retrieveDecrypted(for key: Key, encryptionKey: Data) -> Result<Value?, StorageError>
}

