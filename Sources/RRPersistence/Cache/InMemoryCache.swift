import Foundation
import RRFoundation

// MARK: - In-Memory Cache

/// In-memory cache that implements StorageProtocol and ExpirableStorageProtocol with enhanced error handling and logging
public final class InMemoryCache: StorageProtocol, BatchStorageProtocol, ExpirableStorageProtocol {
    public typealias Key = String
    public typealias Value = Any
    
    private struct CacheItem {
        let value: Value
        let expirationDate: Date?
        let creationDate: Date
        
        var isExpired: Bool {
            guard let expirationDate = expirationDate else { return false }
            return Date() > expirationDate
        }
        
        var age: TimeInterval {
            return Date().timeIntervalSince(creationDate)
        }
    }
    
    private var cache: [Key: CacheItem] = [:]
    private let queue = DispatchQueue(label: "com.rrpersistence.cache", attributes: .concurrent)
    private let maxSize: Int
    private let cleanupInterval: TimeInterval
    private let logger: Logger
    
    /// Initializes InMemoryCache with configuration
    /// - Parameters:
    ///   - maxSize: Maximum number of items in cache (defaults to 1000)
    ///   - cleanupInterval: How often to clean up expired items in seconds (defaults to 60)
    ///   - logger: Custom logger instance (defaults to shared logger with "InMemoryCache" category)
    public init(maxSize: Int = 1000, cleanupInterval: TimeInterval = 60, logger: Logger? = nil) {
        self.maxSize = maxSize
        self.cleanupInterval = cleanupInterval
        self.logger = logger ?? Logger.withCategory("InMemoryCache")
        
        // Start cleanup timer
        startCleanupTimer()
        
        self.logger.info("InMemoryCache initialized with maxSize: \(maxSize), cleanupInterval: \(cleanupInterval)s")
    }
    
    deinit {
        stopCleanupTimer()
        logger.debug("InMemoryCache deinitialized")
    }
    
    // MARK: - StorageProtocol Implementation
    
    public func store(_ value: Value, for key: Key) -> Result<Void, StorageError> {
        let startTime = Date()
        
        let result = Result.catching {
            return self.queue.sync {
                // Check if we need to evict items
                if self.cache.count >= self.maxSize {
                    self.evictOldestItems()
                }
                
                let item = CacheItem(value: value, expirationDate: nil, creationDate: Date())
                self.cache[key] = item
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
            self.queue.sync {
                guard let item = self.cache[key] else { return Optional<Value>.none }
                
                // Check if item is expired
                if item.isExpired {
                    self.cache.removeValue(forKey: key)
                    return Optional<Value>.none
                }
                
                return Optional<Value>.some(item.value)
            }
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
            self.queue.sync {
                self.cache.removeValue(forKey: key) != nil
            }
        }
        .map { _ in () } // Convert Bool to Void
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
            return self.queue.sync {
                self.cache.removeAll()
            }
        }
        .mapError { error in
            let storageError = StorageError.from(error)
            storageError.log(context: "Failed to clear cache", operation: "clear")
            return storageError
        }
        
        result.onSuccess { _ in
            let duration = Date().timeIntervalSince(startTime)
            self.logger.logPerformance(operation: "clear", duration: duration)
            self.logger.debug("Successfully cleared cache")
        }
        
        return result
    }
    
    public func exists(for key: Key) -> Result<Bool, StorageError> {
        let startTime = Date()
        
        let result = Result.catching {
            return self.queue.sync {
                guard let item = self.cache[key] else { return false }
                return !item.isExpired
            }
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
            return self.queue.sync {
                // Check if we need to evict items
                let neededSpace = items.count
                if self.cache.count + neededSpace > self.maxSize {
                    self.evictOldestItems(keepCount: self.maxSize - neededSpace)
                }
                
                for (key, value) in items {
                    let item = CacheItem(value: value, expirationDate: nil, creationDate: Date())
                    self.cache[key] = item
                }
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
            return self.queue.sync {
                var result: [Key: Value] = [:]
                
                for key in keys {
                    if let item = self.cache[key], !item.isExpired {
                        result[key] = item.value
                    }
                }
                
                return result
            }
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
            return self.queue.sync {
                for key in keys {
                    self.cache.removeValue(forKey: key)
                }
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
    
    // MARK: - ExpirableStorageProtocol Implementation
    
    public func store(_ value: Value, for key: Key, expirationDate: Date) -> Result<Void, StorageError> {
        let startTime = Date()
        
        let result = Result.catching {
            return self.queue.sync {
                // Check if we need to evict items
                if self.cache.count >= self.maxSize {
                    self.evictOldestItems()
                }
                
                let item = CacheItem(value: value, expirationDate: expirationDate, creationDate: Date())
                self.cache[key] = item
            }
        }
        .mapError { error in
            let storageError = StorageError.from(error)
            storageError.log(context: "Failed to store value with expiration for key: \(key)", operation: "storeWithExpiration")
            return storageError
        }
        
        result.onSuccess { _ in
            let duration = Date().timeIntervalSince(startTime)
            self.logger.logPerformance(operation: "storeWithExpiration", duration: duration)
            self.logger.debug("Successfully stored value with expiration for key: \(key)")
        }
        
        return result
    }
    
    public func retrieveValid(for key: Key) -> Result<Value?, StorageError> {
        return retrieve(for: key) // This already checks expiration
    }
    
    public func removeExpired() -> Result<Int, StorageError> {
        let startTime = Date()
        
        let result = Result.catching {
            return self.queue.sync {
                let expiredKeys = self.cache.compactMap { key, item in
                    item.isExpired ? key : nil
                }
                
                expiredKeys.forEach { self.cache.removeValue(forKey: $0) }
                
                return expiredKeys.count
            }
        }
        .mapError { error in
            let storageError = StorageError.from(error)
            storageError.log(context: "Failed to remove expired items", operation: "removeExpired")
            return storageError
        }
        
        result.onSuccess { count in
            let duration = Date().timeIntervalSince(startTime)
            self.logger.logPerformance(operation: "removeExpired", duration: duration)
            if count > 0 {
                self.logger.debug("Successfully removed \(count) expired items")
            }
        }
        
        return result
    }
    
    // MARK: - Private Methods
    
    private func evictOldestItems(keepCount: Int? = nil) {
        let targetCount = keepCount ?? maxSize / 2
        
        let sortedItems = cache.sorted { first, second in
            first.value.creationDate < second.value.creationDate
        }
        
        let itemsToRemove = sortedItems.dropFirst(targetCount)
        let removedCount = itemsToRemove.count
        itemsToRemove.forEach { key, _ in
            cache.removeValue(forKey: key)
        }
        
        if removedCount > 0 {
            logger.debug("Evicted \(removedCount) oldest items from cache")
        }
    }
    
    private var cleanupTimer: Timer?
    
    private func startCleanupTimer() {
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: cleanupInterval, repeats: true) { [weak self] _ in
            self?.removeExpired()
                .onSuccess { count in
                    if count > 0 {
                        self?.logger.debug("Cleanup timer removed \(count) expired items")
                    }
                }
        }
    }
    
    private func stopCleanupTimer() {
        cleanupTimer?.invalidate()
        cleanupTimer = nil
    }
}

// MARK: - Cache Statistics

public extension InMemoryCache {
    
    /// Returns cache statistics
    var statistics: CacheStatistics {
        return queue.sync {
            let totalItems = cache.count
            let expiredItems = cache.values.filter { $0.isExpired }.count
            let validItems = totalItems - expiredItems
            
            return CacheStatistics(
                totalItems: totalItems,
                validItems: validItems,
                expiredItems: expiredItems,
                maxSize: maxSize,
                usagePercentage: Double(totalItems) / Double(maxSize) * 100
            )
        }
    }
    
    /// Cache statistics information
    struct CacheStatistics {
        public let totalItems: Int
        public let validItems: Int
        public let expiredItems: Int
        public let maxSize: Int
        public let usagePercentage: Double
        
        public var isFull: Bool {
            return totalItems >= maxSize
        }
        
        public var hasExpiredItems: Bool {
            return expiredItems > 0
        }
    }
}

// MARK: - Type-Safe Cache Extensions

public extension InMemoryCache {
    
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
    
    /// Stores a value with a time-to-live (TTL)
    /// - Parameters:
    ///   - value: The value to store
    ///   - key: The key to associate with the value
    ///   - ttl: Time to live in seconds
    /// - Returns: Result indicating success or failure with error details
    func store(_ value: Value, for key: Key, ttl: TimeInterval) -> Result<Void, StorageError> {
        let expirationDate = Date().addingTimeInterval(ttl)
        return store(value, for: key, expirationDate: expirationDate)
    }
}

// MARK: - Convenience Extensions

public extension InMemoryCache {
    
    /// Creates an InMemoryCache instance with a specific category for logging
    /// - Parameters:
    ///   - maxSize: Maximum number of items in cache
    ///   - category: The logging category
    /// - Returns: A new InMemoryCache instance
    static func withCategory(_ maxSize: Int = 1000, category: String) -> InMemoryCache {
        let logger = Logger.withCategory(category)
        return InMemoryCache(maxSize: maxSize, logger: logger)
    }
}
