# RRPersistence

A Swift framework for local data persistence and storage management, built on top of RRFoundation.

## Features

- **UserDefaults Wrapper**: Type-safe wrapper for UserDefaults with batch operations
- **Keychain Storage**: Secure storage using iOS Keychain with encryption support
- **In-Memory Cache**: High-performance in-memory cache with expiration and size limits
- **Protocol-Based Design**: Unified interface through storage protocols
- **Type Safety**: Full support for Codable types and primitive values
- **Batch Operations**: Efficient batch storage, retrieval, and removal
- **Expiration Support**: Automatic cleanup of expired cache items
- **Thread Safety**: Concurrent access support for cache operations

## Requirements

- iOS 13.0+
- macOS 11.0+
- tvOS 13.0+
- watchOS 6.0+
- visionOS 1.0+
- Swift 5.9+
- Xcode 15.0+

## Installation

### Swift Package Manager

Add the following dependency to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/rirp53021/rr-swift-persistence.git", from: "1.0.0")
]
```

Or for local development:

```swift
dependencies: [
    .package(path: "../rr-swift-persistence")
]
```

## Usage

### Basic Storage

```swift
import RRPersistence

// UserDefaults storage
let userDefaultsStorage = UserDefaultsStorage()
userDefaultsStorage.store("Hello World", for: "greeting")
let greeting = userDefaultsStorage.retrieve(for: "greeting") as? String

// Keychain storage
let keychainStorage = KeychainStorage(service: "my_app")
keychainStorage.store("secret_value", for: "api_key")
let apiKey = keychainStorage.retrieveString(for: "api_key")

// In-memory cache
let cache = InMemoryCache(maxSize: 100)
cache.store("cached_value", for: "cache_key")
let cachedValue = cache.retrieve(for: "cache_key") as? String
```

### Codable Support

```swift
struct User: Codable {
    let id: Int
    let name: String
    let email: String
}

let user = User(id: 1, name: "John Doe", email: "john@example.com")

// Store Codable objects
userDefaultsStorage.store(user, for: "current_user")
keychainStorage.store(user, for: "secure_user")

// Retrieve Codable objects
let storedUser = userDefaultsStorage.retrieve(User.self, for: "current_user")
let secureUser = keychainStorage.retrieve(User.self, for: "secure_user")
```

### Batch Operations

```swift
let items = [
    "key1": "value1",
    "key2": "value2",
    "key3": "value3"
]

// Batch store
userDefaultsStorage.storeBatch(items)

// Batch retrieve
let retrievedItems = userDefaultsStorage.retrieveBatch(for: Array(items.keys))

// Batch remove
userDefaultsStorage.removeBatch(for: Array(items.keys))
```

### Cache with Expiration

```swift
let cache = InMemoryCache(maxSize: 1000, cleanupInterval: 60)

// Store with expiration date
let expirationDate = Date().addingTimeInterval(3600) // 1 hour
cache.store("temporary_data", for: "temp_key", expirationDate: expirationDate)

// Store with TTL (time-to-live)
cache.store("short_lived_data", for: "short_key", ttl: 300) // 5 minutes

// Check cache statistics
let stats = cache.statistics
print("Cache usage: \(stats.usagePercentage)%")
print("Valid items: \(stats.validItems)")
print("Expired items: \(stats.expiredItems)")
```

### Protocol-Based Usage

```swift
// Use any storage implementation through protocols
func saveData<T>(_ data: T, for key: String, using storage: any StorageProtocol) -> Bool {
    return storage.store(data, for: key)
}

func loadData<T>(_ type: T.Type, for key: String, using storage: any StorageProtocol) -> T? {
    return storage.retrieve(for: key) as? T
}

// Usage
let userDefaults: any StorageProtocol = UserDefaultsStorage()
let keychain: any StorageProtocol = KeychainStorage(service: "app")

saveData("Hello", for: "greeting", using: userDefaults)
saveData("Secret".data(using: .utf8)!, for: "secret", using: keychain)
```

## Architecture

### Storage Protocols

- **`StorageProtocol`**: Basic storage operations (store, retrieve, remove, clear, exists)
- **`BatchStorageProtocol`**: Batch operations for multiple items
- **`ExpirableStorageProtocol`**: Support for expiration dates
- **`EncryptedStorageProtocol`**: Encryption and decryption support

### Implementations

- **`UserDefaultsStorage`**: Wrapper around UserDefaults with batch support
- **`KeychainStorage`**: Secure storage using iOS Keychain
- **`InMemoryCache`**: High-performance in-memory cache with expiration

## Configuration

### UserDefaults Storage

```swift
// Standard UserDefaults
let standardStorage = UserDefaultsStorage()

// Custom UserDefaults suite
let customStorage = UserDefaultsStorage(suiteName: "com.myapp.custom")
```

### Keychain Storage

```swift
// Basic keychain storage
let keychain = KeychainStorage(service: "com.myapp.keychain")

// With custom accessibility
let secureKeychain = KeychainStorage(
    service: "com.myapp.secure",
    accessibility: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
)
```

### In-Memory Cache

```swift
// Default configuration (1000 items, 60s cleanup)
let defaultCache = InMemoryCache()

// Custom configuration
let customCache = InMemoryCache(
    maxSize: 500,
    cleanupInterval: 30
)
```

## Testing

The framework includes comprehensive unit tests for all storage implementations:

```bash
# Run tests
swift test

# Or using Xcode
xcodebuild -scheme RRPersistence test
```

## Dependencies

- **RRFoundation**: Core utilities and extensions
- **Foundation**: Basic Swift types and functionality
- **Security**: Keychain operations (iOS/macOS)

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass
6. Submit a pull request

## Version History

- **1.0.0**: Initial release with UserDefaults, Keychain, and In-Memory Cache support

