import Foundation
import RRFoundation

// MARK: - UserDefaults Storage

/// Wrapper for UserDefaults that implements StorageProtocol
public final class UserDefaultsStorage: StorageProtocol, BatchStorageProtocol {
    public typealias Key = String
    public typealias Value = Any
    
    private let userDefaults: UserDefaults
    private let suiteName: String?
    
    /// Initializes UserDefaultsStorage with a specific UserDefaults instance
    /// - Parameter userDefaults: The UserDefaults instance to use (defaults to .standard)
    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.suiteName = nil
    }
    
    /// Initializes UserDefaultsStorage with a specific suite name
    /// - Parameter suiteName: The suite name for the UserDefaults
    public init(suiteName: String) {
        self.userDefaults = UserDefaults(suiteName: suiteName) ?? .standard
        self.suiteName = suiteName
    }
    
    // MARK: - StorageProtocol Implementation
    
    @discardableResult
    public func store(_ value: Value, for key: Key) -> Bool {
        userDefaults.set(value, forKey: key)
        return userDefaults.synchronize()
    }
    
    public func retrieve(for key: Key) -> Value? {
        return userDefaults.object(forKey: key)
    }
    
    @discardableResult
    public func remove(for key: Key) -> Bool {
        userDefaults.removeObject(forKey: key)
        return userDefaults.synchronize()
    }
    
    @discardableResult
    public func clear() -> Bool {
        guard let suiteName = suiteName else {
            // For standard UserDefaults, we can't clear everything
            // Instead, we'll remove all keys that we know about
            return false
        }
        
        if let suiteDefaults = UserDefaults(suiteName: suiteName) {
            let dictionary = suiteDefaults.dictionaryRepresentation()
            dictionary.keys.forEach { key in
                suiteDefaults.removeObject(forKey: key)
            }
            return suiteDefaults.synchronize()
        }
        
        return false
    }
    
    public func exists(for key: Key) -> Bool {
        return userDefaults.object(forKey: key) != nil
    }
    
    // MARK: - BatchStorageProtocol Implementation
    
    @discardableResult
    public func storeBatch(_ items: [Key: Value]) -> Bool {
        items.forEach { key, value in
            userDefaults.set(value, forKey: key)
        }
        return userDefaults.synchronize()
    }
    
    public func retrieveBatch(for keys: [Key]) -> [Key: Value] {
        var result: [Key: Value] = [:]
        
        for key in keys {
            if let value = userDefaults.object(forKey: key) {
                result[key] = value
            }
        }
        
        return result
    }
    
    @discardableResult
    public func removeBatch(for keys: [Key]) -> Bool {
        keys.forEach { key in
            userDefaults.removeObject(forKey: key)
        }
        return userDefaults.synchronize()
    }
}

// MARK: - Type-Safe UserDefaults Extensions

extension UserDefaultsStorage {
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
        guard let data = retrieve(for: key) as? Data else {
            return nil
        }
        
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            Logger.error("Failed to decode value for key '\(key)': \(error)")
            return nil
        }
    }
    
    /// Stores a primitive value for a given key
    /// - Parameters:
    ///   - value: The primitive value to store
    ///   - key: The key to associate with the value
    /// - Returns: Success status of the operation
    @discardableResult
    public func storePrimitive<T>(_ value: T, for key: Key) -> Bool {
        return store(value, for: key)
    }
    
    /// Retrieves a primitive value for a given key
    /// - Parameter key: The key to retrieve the value for
    /// - Returns: The primitive value, if any
    public func retrievePrimitive<T>(_ type: T.Type, for key: Key) -> T? {
        return retrieve(for: key) as? T
    }
}
