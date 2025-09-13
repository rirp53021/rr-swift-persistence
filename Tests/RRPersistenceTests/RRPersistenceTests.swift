import Foundation
import Testing
@testable import RRPersistence

final class RRPersistenceTests {
    
    // MARK: - UserDefaults Storage Tests
    
    func testUserDefaultsStorage() {
        let storage = UserDefaultsStorage()
        let testKey = "test_key"
        let testValue = "test_value"
        
        // Test store and retrieve
        let storeResult = storage.store(testValue, for: testKey)
        #expect(storeResult.isSuccess)
        
        let retrievedValue = storage.retrieve(for: testKey)
        #expect(retrievedValue.isSuccess)
        #expect(retrievedValue.value as? String == testValue)
        
        // Test exists
        let existsResult = storage.exists(for: testKey)
        #expect(existsResult.isSuccess)
        #expect(existsResult.value == true)
        
        // Test remove
        let removeResult = storage.remove(for: testKey)
        #expect(removeResult.isSuccess)
        
        // Test value is removed
        let existsAfterRemove = storage.exists(for: testKey)
        #expect(existsAfterRemove.isSuccess)
        #expect(existsAfterRemove.value == false)
        
        // Clean up
        storage.remove(for: testKey)
    }
    
    func testUserDefaultsStorageBatch() {
        let storage = UserDefaultsStorage()
        let testItems = [
            "key1": "value1",
            "key2": "value2",
            "key3": "value3"
        ]
        
        // Test batch store
        let storeResult = storage.storeBatch(testItems)
        #expect(storeResult == true)
        
        // Test batch retrieve
        let retrievedItems = storage.retrieveBatch(for: Array(testItems.keys))
        #expect(retrievedItems.count == testItems.count)
        
        // Test batch remove
        let removeResult = storage.removeBatch(for: Array(testItems.keys))
        #expect(removeResult == true)
        
        // Clean up
        storage.removeBatch(for: Array(testItems.keys))
    }
    
    func testUserDefaultsStorageCodable() {
        struct TestModel: Codable, Equatable {
            let id: Int
            let name: String
        }
        
        let storage = UserDefaultsStorage()
        let testKey = "codable_test_key"
        let testModel = TestModel(id: 1, name: "Test")
        
        // Test store codable
        let storeResult = storage.store(testModel, for: testKey)
        #expect(storeResult == true)
        
        // Test retrieve codable
        let retrievedModel = storage.retrieve(TestModel.self, for: testKey)
        #expect(retrievedModel == testModel)
        
        // Clean up
        storage.remove(for: testKey)
    }
    
    // MARK: - In-Memory Cache Tests
    
    func testInMemoryCache() {
        let cache = InMemoryCache(maxSize: 5)
        let testKey = "cache_test_key"
        let testValue = "cache_test_value"
        
        // Test store and retrieve
        let storeResult = cache.store(testValue, for: testKey)
        #expect(storeResult == true)
        
        let retrievedValue = cache.retrieve(for: testKey) as? String
        #expect(retrievedValue == testValue)
        
        // Test exists
        #expect(cache.exists(for: testKey) == true)
        
        // Test remove
        let removeResult = cache.remove(for: testKey)
        #expect(removeResult == true)
        
        // Test value is removed
        #expect(cache.exists(for: testKey) == false)
    }
    
    func testInMemoryCacheExpiration() {
        let cache = InMemoryCache(maxSize: 10)
        let testKey = "expiration_test_key"
        let testValue = "expiration_test_value"
        
        // Test store with expiration
        let expirationDate = Date().addingTimeInterval(1) // 1 second from now
        let storeResult = cache.store(testValue, for: testKey, expirationDate: expirationDate)
        #expect(storeResult == true)
        
        // Value should exist immediately
        #expect(cache.exists(for: testKey) == true)
        
        // Wait for expiration
        Thread.sleep(forTimeInterval: 1.1)
        
        // Value should be expired now
        #expect(cache.exists(for: testKey) == false)
        
        // Clean up
        cache.remove(for: testKey)
    }
    
    func testInMemoryCacheMaxSize() {
        let cache = InMemoryCache(maxSize: 3)
        
        // Fill cache to capacity
        for i in 1...3 {
            let key = "key\(i)"
            let value = "value\(i)"
            cache.store(value, for: key)
        }
        
        // Cache should be at max size
        #expect(cache.statistics.totalItems == 3)
        
        // Add one more item - should trigger eviction
        cache.store("value4", for: "key4")
        
        // Cache should still be at max size
        #expect(cache.statistics.totalItems == 3)
        
        // Clean up
        cache.clear()
    }
    
    func testInMemoryCacheBatch() {
        let cache = InMemoryCache(maxSize: 10)
        let testItems = [
            "batch_key1": "batch_value1",
            "batch_key2": "batch_value2",
            "batch_key3": "batch_value3"
        ]
        
        // Test batch store
        let storeResult = cache.storeBatch(testItems)
        #expect(storeResult == true)
        
        // Test batch retrieve
        let retrievedItems = cache.retrieveBatch(for: Array(testItems.keys))
        #expect(retrievedItems.count == testItems.count)
        
        // Test batch remove
        let removeResult = cache.removeBatch(for: Array(testItems.keys))
        #expect(removeResult == true)
        
        // Clean up
        cache.clear()
    }
    
    // MARK: - Keychain Storage Tests
    
    func testKeychainStorage() {
        let storage = KeychainStorage(service: "test_service")
        let testKey = "keychain_test_key"
        let testValue = "keychain_test_value"
        
        // Test store and retrieve
        let storeResult = storage.store(testValue, for: testKey)
        #expect(storeResult == true)
        
        let retrievedValue = storage.retrieveString(for: testKey)
        #expect(retrievedValue == testValue)
        
        // Test exists
        #expect(storage.exists(for: testKey) == true)
        
        // Test remove
        let removeResult = storage.remove(for: testKey)
        #expect(removeResult == true)
        
        // Test value is removed
        #expect(storage.exists(for: testKey) == false)
        
        // Clean up
        storage.remove(for: testKey)
    }
    
    func testKeychainStorageCodable() {
        struct TestModel: Codable, Equatable {
            let id: Int
            let name: String
        }
        
        let storage = KeychainStorage(service: "test_service")
        let testKey = "keychain_codable_test_key"
        let testModel = TestModel(id: 1, name: "Test")
        
        // Test store codable
        let storeResult = storage.store(testModel, for: testKey)
        #expect(storeResult == true)
        
        // Test retrieve codable
        let retrievedModel = storage.retrieve(TestModel.self, for: testKey)
        #expect(retrievedModel == testModel)
        
        // Clean up
        storage.remove(for: testKey)
    }
    
    // MARK: - Storage Protocols Tests
    
    func testStorageProtocols() {
        // Test that all storage implementations conform to StorageProtocol
        let userDefaultsStorage: any StorageProtocol = UserDefaultsStorage()
        let keychainStorage: any StorageProtocol = KeychainStorage(service: "test")
        let cacheStorage: any StorageProtocol = InMemoryCache()
        
        // Test that they can be used polymorphically
        #expect(userDefaultsStorage.store("test", for: "key") == true)
        #expect(keychainStorage.store("test".data(using: .utf8)!, for: "key") == true)
        #expect(cacheStorage.store("test", for: "key") == true)
        
        // Clean up - using concrete types since remove is not in protocol
        if let userDefaults = userDefaultsStorage as? UserDefaultsStorage {
            _ = userDefaults.remove(for: "key")
        }
        if let keychain = keychainStorage as? KeychainStorage {
            _ = keychain.remove(for: "key")
        }
        if let cache = cacheStorage as? InMemoryCache {
            _ = cache.remove(for: "key")
        }
    }
}

