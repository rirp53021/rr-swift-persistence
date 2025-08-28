import Foundation
import RRFoundation

// MARK: - In-Memory Cache

/// In-memory cache that implements StorageProtocol and ExpirableStorageProtocol
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
    
    /// Initializes InMemoryCache with configuration
    /// - Parameters:
    ///   - maxSize: Maximum number of items in cache (defaults to 1000)
    ///   - cleanupInterval: How often to clean up expired items in seconds (defaults to 60)
    public init(maxSize: Int = 1000, cleanupInterval: TimeInterval = 60) {
        self.maxSize = maxSize
        self.cleanupInterval = cleanupInterval
        
        // Start cleanup timer
        startCleanupTimer()
    }
    
    deinit {
        stopCleanupTimer()
    }
    
    // MARK: - StorageProtocol Implementation
    
    @discardableResult
    public func store(_ value: Value, for key: Key) -> Bool {
        return queue.sync {
            // Check if we need to evict items
            if cache.count >= maxSize {
                evictOldestItems()
            }
            
            let item = CacheItem(value: value, expirationDate: nil, creationDate: Date())
            cache[key] = item
            return true
        }
    }
    
    public func retrieve(for key: Key) -> Value? {
        return queue.sync {
            guard let item = cache[key] else { return nil }
            
            // Check if item is expired
            if item.isExpired {
                cache.removeValue(forKey: key)
                return nil
            }
            
            return item.value
        }
    }
    
    @discardableResult
    public func remove(for key: Key) -> Bool {
        return queue.sync {
            cache.removeValue(forKey: key) != nil
        }
    }
    
    @discardableResult
    public func clear() -> Bool {
        return queue.sync {
            cache.removeAll()
            return true
        }
    }
    
    public func exists(for key: Key) -> Bool {
        return queue.sync {
            guard let item = cache[key] else { return false }
            return !item.isExpired
        }
    }
    
    // MARK: - BatchStorageProtocol Implementation
    
    @discardableResult
    public func storeBatch(_ items: [Key: Value]) -> Bool {
        return queue.sync {
            // Check if we need to evict items
            let neededSpace = items.count
            if cache.count + neededSpace > maxSize {
                evictOldestItems(keepCount: maxSize - neededSpace)
            }
            
            for (key, value) in items {
                let item = CacheItem(value: value, expirationDate: nil, creationDate: Date())
                cache[key] = item
            }
            
            return true
        }
    }
    
    public func retrieveBatch(for keys: [Key]) -> [Key: Value] {
        return queue.sync {
            var result: [Key: Value] = [:]
            
            for key in keys {
                if let item = cache[key], !item.isExpired {
                    result[key] = item.value
                }
            }
            
            return result
        }
    }
    
    @discardableResult
    public func removeBatch(for keys: [Key]) -> Bool {
        return queue.sync {
            var success = true
            
            for key in keys {
                if cache.removeValue(forKey: key) == nil {
                    success = false
                }
            }
            
            return success
        }
    }
    
    // MARK: - ExpirableStorageProtocol Implementation
    
    @discardableResult
    public func store(_ value: Value, for key: Key, expirationDate: Date) -> Bool {
        return queue.sync {
            // Check if we need to evict items
            if cache.count >= maxSize {
                evictOldestItems()
            }
            
            let item = CacheItem(value: value, expirationDate: expirationDate, creationDate: Date())
            cache[key] = item
            return true
        }
    }
    
    public func retrieveValid(for key: Key) -> Value? {
        return retrieve(for: key) // This already checks expiration
    }
    
    @discardableResult
    public func removeExpired() -> Int {
        return queue.sync {
            let expiredKeys = cache.compactMap { key, item in
                item.isExpired ? key : nil
            }
            
            expiredKeys.forEach { cache.removeValue(forKey: $0) }
            
            return expiredKeys.count
        }
    }
    
    // MARK: - Private Methods
    
    private func evictOldestItems(keepCount: Int? = nil) {
        let targetCount = keepCount ?? maxSize / 2
        
        let sortedItems = cache.sorted { first, second in
            first.value.creationDate < second.value.creationDate
        }
        
        let itemsToRemove = sortedItems.dropFirst(targetCount)
        itemsToRemove.forEach { key, _ in
            cache.removeValue(forKey: key)
        }
    }
    
    private var cleanupTimer: Timer?
    
    private func startCleanupTimer() {
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: cleanupInterval, repeats: true) { [weak self] _ in
            self?.removeExpired()
        }
    }
    
    private func stopCleanupTimer() {
        cleanupTimer?.invalidate()
        cleanupTimer = nil
    }
}

// MARK: - Cache Statistics

extension InMemoryCache {
    /// Returns cache statistics
    public var statistics: CacheStatistics {
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
    public struct CacheStatistics {
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

extension InMemoryCache {
    /// Stores a Codable value for a given key
    /// - Parameters:
    ///   - value: The Codable value to store
    ///   - key: The key to associate with the value
    /// - Returns: Success status of the operation
    @discardableResult
    public func store<T: Codable>(_ value: T, for key: Key) -> Bool {
        // Convert to Data first to avoid infinite recursion
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
    
    /// Stores a value with a time-to-live (TTL)
    /// - Parameters:
    ///   - value: The value to store
    ///   - key: The key to associate with the value
    ///   - ttl: Time to live in seconds
    /// - Returns: Success status of the operation
    @discardableResult
    public func store(_ value: Value, for key: Key, ttl: TimeInterval) -> Bool {
        let expirationDate = Date().addingTimeInterval(ttl)
        return store(value, for: key, expirationDate: expirationDate)
    }
}
