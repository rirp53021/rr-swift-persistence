import Foundation
import RRFoundation

// MARK: - In-Memory Cache

/// In-memory cache that implements StorageProtocol and ExpirableStorageProtocol with enhanced error handling and logging
/// Thread-safe implementation using Swift actors
public actor InMemoryCache: StorageProtocol, BatchStorageProtocol, ExpirableStorageProtocol {
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
    private let maxSize: Int
    private let cleanupInterval: TimeInterval
    private let logger: Logger
    private var cleanupTask: Task<Void, Never>?
    
    /// Initializes InMemoryCache with configuration
    /// - Parameters:
    ///   - maxSize: Maximum number of items in cache (defaults to 1000)
    ///   - cleanupInterval: How often to clean up expired items in seconds (defaults to 60)
    ///   - logger: Custom logger instance (defaults to shared logger with "InMemoryCache" category)
    public init(maxSize: Int = 1000, cleanupInterval: TimeInterval = 60, logger: Logger? = nil) {
        self.maxSize = maxSize
        self.cleanupInterval = cleanupInterval
        self.logger = logger ?? Logger.withCategory("InMemoryCache")
        
        // Start cleanup task asynchronously
        Task {
            await self.logger.info("InMemoryCache initialized with maxSize: \(maxSize), cleanupInterval: \(cleanupInterval)s")
            await self.startCleanupTask()
        }
    }
    
    deinit {
        cleanupTask?.cancel()
        logger.debug("InMemoryCache deinitialized")
    }
    
    // MARK: - StorageProtocol Implementation
    
    public func store(_ value: Value, for key: Key) async -> Result<Void, StorageError> {
        let startTime = Date()
        
        let result = Result.catching {
            // Check if we need to evict items
            if self.cache.count >= self.maxSize {
                self.evictOldestItems()
            }
            
            let item = CacheItem(value: value, expirationDate: nil, creationDate: Date())
            self.cache[key] = item
        }
        .mapError { error in
            let storageError = StorageError.from(error)
            storageError.log(context: "Failed to store value for key: \(key)", operation: "store")
            return storageError
        }
        
        if case .success = result {
            let duration = Date().timeIntervalSince(startTime)
            self.logger.logPerformance(operation: "store", duration: duration)
            self.logger.debug("Successfully stored value for key: \(key)")
        }
        
        return result
    }
    
    public func retrieve(for key: Key) async -> Result<Value?, StorageError> {
        let startTime = Date()
        
        // Check if value exists
        guard let item = cache[key] else {
            return .success(nil)
        }
        
        // Check if expired
        if item.isExpired {
            cache.removeValue(forKey: key)
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance(operation: "retrieve", duration: duration)
            logger.debug("Removed expired value for key: \(key)")
            return .success(nil)
        }
        
        let duration = Date().timeIntervalSince(startTime)
        logger.logPerformance(operation: "retrieve", duration: duration)
        logger.debug("Successfully retrieved value for key: \(key)")
        
        return .success(item.value)
    }
    
    public func remove(for key: Key) async -> Result<Void, StorageError> {
        let startTime = Date()
        
        let result = Result.catching {
            self.cache.removeValue(forKey: key) != nil
        }
        .map { _ in () }
        .mapError { error in
            let storageError = StorageError.from(error)
            storageError.log(context: "Failed to remove value for key: \(key)", operation: "remove")
            return storageError
        }
        
        if case .success = result {
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance(operation: "remove", duration: duration)
            logger.debug("Successfully removed value for key: \(key)")
        }
        
        return result
    }
    
    public func clear() async -> Result<Void, StorageError> {
        let startTime = Date()
        
        let result = Result.catching {
            self.cache.removeAll()
        }
        .mapError { error in
            let storageError = StorageError.from(error)
            storageError.log(context: "Failed to clear cache", operation: "clear")
            return storageError
        }
        
        if case .success = result {
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance(operation: "clear", duration: duration)
            logger.debug("Successfully cleared cache")
        }
        
        return result
    }
    
    public func exists(for key: Key) async -> Result<Bool, StorageError> {
        let startTime = Date()
        
        let result = Result.catching {
            guard let item = self.cache[key] else { return false }
            return !item.isExpired
        }
        .mapError { error in
            let storageError = StorageError.from(error)
            storageError.log(context: "Failed to check existence for key: \(key)", operation: "exists")
            return storageError
        }
        
        if case .success(let exists) = result {
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance(operation: "exists", duration: duration)
            logger.debug("Key '\(key)' exists: \(exists)")
        }
        
        return result
    }
    
    // MARK: - BatchStorageProtocol Implementation
    
    public func storeBatch(_ items: [Key: Value]) async -> Result<Void, StorageError> {
        let startTime = Date()
        
        let result = Result.catching {
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
        .mapError { error in
            let storageError = StorageError.from(error)
            storageError.log(context: "Failed to store batch of \(items.count) items", operation: "storeBatch")
            return storageError
        }
        
        if case .success = result {
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance(operation: "storeBatch", duration: duration)
            logger.debug("Successfully stored batch of \(items.count) items")
        }
        
        return result
    }
    
    public func retrieveBatch(for keys: [Key]) async -> Result<[Key: Value], StorageError> {
        let startTime = Date()
        
        let result = Result.catching {
            var result: [Key: Value] = [:]
            
            for key in keys {
                if let item = self.cache[key], !item.isExpired {
                    result[key] = item.value
                }
            }
            
            return result
        }
        .mapError { error in
            let storageError = StorageError.from(error)
            storageError.log(context: "Failed to retrieve batch for \(keys.count) keys", operation: "retrieveBatch")
            return storageError
        }
        
        if case .success(let batchResult) = result {
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance(operation: "retrieveBatch", duration: duration)
            logger.debug("Successfully retrieved batch: \(batchResult.count)/\(keys.count) items found")
        }
        
        return result
    }
    
    public func removeBatch(for keys: [Key]) async -> Result<Void, StorageError> {
        let startTime = Date()
        
        let result = Result.catching {
            for key in keys {
                self.cache.removeValue(forKey: key)
            }
        }
        .mapError { error in
            let storageError = StorageError.from(error)
            storageError.log(context: "Failed to remove batch of \(keys.count) keys", operation: "removeBatch")
            return storageError
        }
        
        if case .success = result {
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance(operation: "removeBatch", duration: duration)
            logger.debug("Successfully removed batch of \(keys.count) keys")
        }
        
        return result
    }
    
    // MARK: - ExpirableStorageProtocol Implementation
    
    public func store(_ value: Value, for key: Key, expirationDate: Date) async -> Result<Void, StorageError> {
        let startTime = Date()
        
        let result = Result.catching {
            // Check if we need to evict items
            if self.cache.count >= self.maxSize {
                self.evictOldestItems()
            }
            
            let item = CacheItem(value: value, expirationDate: expirationDate, creationDate: Date())
            self.cache[key] = item
        }
        .mapError { error in
            let storageError = StorageError.from(error)
            storageError.log(context: "Failed to store value with expiration for key: \(key)", operation: "storeWithExpiration")
            return storageError
        }
        
        if case .success = result {
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance(operation: "storeWithExpiration", duration: duration)
            logger.debug("Successfully stored value with expiration for key: \(key)")
        }
        
        return result
    }
    
    public func retrieveValid(for key: Key) async -> Result<Value?, StorageError> {
        return await retrieve(for: key) // This already checks expiration
    }
    
    public func removeExpired() async -> Result<Int, StorageError> {
        let startTime = Date()
        
        let result = Result.catching {
            let expiredKeys = self.cache.compactMap { key, item in
                item.isExpired ? key : nil
            }
            
            expiredKeys.forEach { self.cache.removeValue(forKey: $0) }
            
            return expiredKeys.count
        }
        .mapError { error in
            let storageError = StorageError.from(error)
            storageError.log(context: "Failed to remove expired items", operation: "removeExpired")
            return storageError
        }
        
        if case .success(let count) = result {
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance(operation: "removeExpired", duration: duration)
            if count > 0 {
                logger.debug("Successfully removed \(count) expired items")
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
    
    private func startCleanupTask() {
        cleanupTask = Task { [weak self] in
            while !Task.isCancelled {
                // Use nanoseconds for compatibility with older OS versions
                try? await Task.sleep(nanoseconds: UInt64((self?.cleanupInterval ?? 60) * 1_000_000_000))
                
                guard !Task.isCancelled, let self = self else { break }
                
                let result = await self.removeExpired()
                if case .success(let count) = result, count > 0 {
                    await self.logger.debug("Cleanup task removed \(count) expired items")
                }
            }
        }
    }
}

// MARK: - Cache Statistics

public extension InMemoryCache {
    
    /// Returns cache statistics
    var statistics: CacheStatistics {
        get async {
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
    struct CacheStatistics: Sendable {
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
    func store<T: Codable>(_ value: T, for key: Key) async -> Result<Void, StorageError> {
        let startTime = Date()
        
        let result = Result.catching {
            try JSONEncoder().encode(value)
        }
        .mapError { error in
            StorageError.encodingFailed(key)
        }
        
        guard case .success(let data) = result else {
            if case .failure(let error) = result {
                return .failure(error)
            }
            return .failure(.encodingFailed(key))
        }
        
        let storeResult = await self.store(data, for: key)
        
        if case .success = storeResult {
            let duration = Date().timeIntervalSince(startTime)
            self.logger.logPerformance(operation: "storeCodable", duration: duration)
            self.logger.debug("Successfully stored Codable value for key: \(key)")
        }
        
        return storeResult
    }
    
    /// Retrieves a Codable value for a given key
    /// - Parameter key: The key to retrieve the value for
    /// - Returns: Result containing the decoded value or error
    func retrieve<T: Codable>(_ type: T.Type, for key: Key) async -> Result<T?, StorageError> {
        let startTime = Date()
        
        let retrieveResult = await retrieve(for: key)
        
        guard case .success(let optionalValue) = retrieveResult else {
            if case .failure(let error) = retrieveResult {
                return .failure(error)
            }
            return .success(nil)
        }
        
        guard let data = optionalValue as? Data else {
            return .success(nil)
        }
        
        let result: Result<T?, StorageError> = Result.catching {
            try JSONDecoder().decode(type, from: data)
        }
        .mapError { error in
            StorageError.decodingFailed(key)
        }
        .map { value -> T? in
            return value
        }
        
        if case .success(let value) = result {
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
    func store(_ value: Value, for key: Key, ttl: TimeInterval) async -> Result<Void, StorageError> {
        let expirationDate = Date().addingTimeInterval(ttl)
        return await store(value, for: key, expirationDate: expirationDate)
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
