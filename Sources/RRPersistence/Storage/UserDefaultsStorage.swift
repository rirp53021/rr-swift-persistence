import Foundation
import RRFoundation

// MARK: - UserDefaults Storage

/// Wrapper for UserDefaults that implements StorageProtocol with enhanced error handling and logging
public final class UserDefaultsStorage: StorageProtocol, BatchStorageProtocol {
    public typealias Key = String
    public typealias Value = Any
    
    private let userDefaults: UserDefaults
    private let suiteName: String?
    private let logger: Logger
    
    /// Initializes UserDefaultsStorage with a specific UserDefaults instance
    /// - Parameters:
    ///   - userDefaults: The UserDefaults instance to use (defaults to .standard)
    ///   - logger: Custom logger instance (defaults to shared logger with "UserDefaults" category)
    public init(userDefaults: UserDefaults = .standard, logger: Logger? = nil) {
        self.userDefaults = userDefaults
        self.suiteName = nil
        self.logger = logger ?? Logger.withCategory("UserDefaults")
    }
    
    /// Initializes UserDefaultsStorage with a specific suite name
    /// - Parameters:
    ///   - suiteName: The suite name for the UserDefaults
    ///   - logger: Custom logger instance (defaults to shared logger with "UserDefaults" category)
    public init(suiteName: String, logger: Logger? = nil) {
        self.userDefaults = UserDefaults(suiteName: suiteName) ?? .standard
        self.suiteName = suiteName
        self.logger = logger ?? Logger.withCategory("UserDefaults")
    }
    
    // MARK: - StorageProtocol Implementation
    
    public func store(_ value: Value, for key: Key) -> Result<Void, StorageError> {
        let startTime = Date()
        
        let result = Result.catching {
            self.userDefaults.set(value, forKey: key)
            guard self.userDefaults.synchronize() else {
                throw StorageError.synchronizationFailed
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
            return self.userDefaults.object(forKey: key)
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
            self.userDefaults.removeObject(forKey: key)
            guard self.userDefaults.synchronize() else {
                throw StorageError.synchronizationFailed
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
            guard let suiteName = self.suiteName else {
                throw StorageError.storageUnavailable
            }
            
            guard let suiteDefaults = UserDefaults(suiteName: suiteName) else {
                throw StorageError.storageUnavailable
            }
            
            let dictionary = suiteDefaults.dictionaryRepresentation()
            dictionary.keys.forEach { key in
                suiteDefaults.removeObject(forKey: key)
            }
            
            guard suiteDefaults.synchronize() else {
                throw StorageError.synchronizationFailed
            }
        }
        .mapError { error in
            let storageError = StorageError.from(error)
            storageError.log(context: "Failed to clear storage", operation: "clear")
            return storageError
        }
        
        result.onSuccess { _ in
            let duration = Date().timeIntervalSince(startTime)
            self.logger.logPerformance(operation: "clear", duration: duration)
            self.logger.debug("Successfully cleared storage")
        }
        
        return result
    }
    
    public func exists(for key: Key) -> Result<Bool, StorageError> {
        let startTime = Date()
        
        let result = Result.catching {
            return self.userDefaults.object(forKey: key) != nil
        }
        .mapError { error in
            let storageError = StorageError.from(error)
            storageError.log(context: "Failed to check existence for key: \(key)", operation: "exists")
            return storageError
        }
        
        result.onSuccess { exists in
            let duration = Date().timeIntervalSince(startTime)
            self.logger.logPerformance(operation: "exists", duration: duration)
            self.logger.debug("Key '\(key)' exists: \(exists)")
        }
        
        return result
    }
    
    // MARK: - BatchStorageProtocol Implementation
    
    public func storeBatch(_ items: [Key: Value]) -> Result<Void, StorageError> {
        let startTime = Date()
        
        let result = Result.catching {
            items.forEach { key, value in
                self.userDefaults.set(value, forKey: key)
            }
            guard self.userDefaults.synchronize() else {
                throw StorageError.synchronizationFailed
            }
        }
        .mapError { error in
            let storageError = StorageError.from(error)
            storageError.log(context: "Failed to store batch of \(items.count) items", operation: "storeBatch")
            return storageError
        }
        
        result.onSuccess { _ in
            let duration = Date().timeIntervalSince(startTime)
            self.logger.logPerformance(operation: "storeBatch", duration: duration)
            self.logger.debug("Successfully stored batch of \(items.count) items")
        }
        
        return result
    }
    
    public func retrieveBatch(for keys: [Key]) -> Result<[Key: Value], StorageError> {
        let startTime = Date()
        
        let result = Result.catching {
            var result: [Key: Value] = [:]
            
            for key in keys {
                if let value = self.userDefaults.object(forKey: key) {
                    result[key] = value
                }
            }
            
            return result
        }
        .mapError { error in
            let storageError = StorageError.from(error)
            storageError.log(context: "Failed to retrieve batch for \(keys.count) keys", operation: "retrieveBatch")
            return storageError
        }
        
        result.onSuccess { result in
            let duration = Date().timeIntervalSince(startTime)
            self.logger.logPerformance(operation: "retrieveBatch", duration: duration)
            self.logger.debug("Successfully retrieved batch: \(result.count)/\(keys.count) items found")
        }
        
        return result
    }
    
    public func removeBatch(for keys: [Key]) -> Result<Void, StorageError> {
        let startTime = Date()
        
        let result = Result.catching {
            keys.forEach { key in
                self.userDefaults.removeObject(forKey: key)
            }
            guard self.userDefaults.synchronize() else {
                throw StorageError.synchronizationFailed
            }
        }
        .mapError { error in
            let storageError = StorageError.from(error)
            storageError.log(context: "Failed to remove batch of \(keys.count) keys", operation: "removeBatch")
            return storageError
        }
        
        result.onSuccess { _ in
            let duration = Date().timeIntervalSince(startTime)
            self.logger.logPerformance(operation: "removeBatch", duration: duration)
            self.logger.debug("Successfully removed batch of \(keys.count) keys")
        }
        
        return result
    }
}

// MARK: - Type-Safe UserDefaults Extensions

public extension UserDefaultsStorage {
    
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
        .flatMap { data in
            self.store(data, for: key)
        }
        .mapError { error in
            if let storageError = error as? StorageError {
                return storageError
            }
            return StorageError.encodingFailed(key)
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
                guard let data = value as? Data else {
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
    
    /// Stores a primitive value for a given key
    /// - Parameters:
    ///   - value: The primitive value to store
    ///   - key: The key to associate with the value
    /// - Returns: Result indicating success or failure with error details
    func storePrimitive<T>(_ value: T, for key: Key) -> Result<Void, StorageError> {
        return store(value, for: key)
    }
    
    /// Retrieves a primitive value for a given key
    /// - Parameter key: The key to retrieve the value for
    /// - Returns: Result containing the primitive value or error
    func retrievePrimitive<T>(_ type: T.Type, for key: Key) -> Result<T?, StorageError> {
        return retrieve(for: key)
            .map { value in
                value as? T
            }
    }
}

// MARK: - Convenience Extensions

public extension UserDefaultsStorage {
    
    /// Creates a UserDefaultsStorage instance with a specific category for logging
    /// - Parameter category: The logging category
    /// - Returns: A new UserDefaultsStorage instance
    static func withCategory(_ category: String) -> UserDefaultsStorage {
        let logger = Logger.withCategory(category)
        return UserDefaultsStorage(logger: logger)
    }
    
    /// Creates a UserDefaultsStorage instance for a specific suite with custom logging category
    /// - Parameters:
    ///   - suiteName: The suite name
    ///   - category: The logging category
    /// - Returns: A new UserDefaultsStorage instance
    static func withSuite(_ suiteName: String, category: String) -> UserDefaultsStorage {
        let logger = Logger.withCategory(category)
        return UserDefaultsStorage(suiteName: suiteName, logger: logger)
    }
}