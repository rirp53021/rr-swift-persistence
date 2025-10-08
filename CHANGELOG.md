# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [2.0.0] - 2025-01-08

### Changed
- **BREAKING**: Converted `InMemoryCache` from GCD to Swift actor for modern concurrency
  - All storage operations now use `async/await` instead of synchronous returns
  - Automatic thread-safety without manual queue management
  - Eliminated DispatchQueue barriers in favor of actor isolation
  - Cleanup timer replaced with structured concurrency using `Task`
  - All protocols (`StorageProtocol`, `BatchStorageProtocol`, `ExpirableStorageProtocol`) now require `async` methods

### Fixed
- **Critical**: Eliminated all race conditions through actor isolation
  - No more manual barrier flag management
  - Actor provides guaranteed serialized access to cache state
  - Prevents data corruption from concurrent operations
- Fixed deinit warning by properly managing cleanup task lifecycle

### Migration Guide

#### Before (Synchronous):
```swift
let cache = InMemoryCache()
let result = cache.store("value", for: "key")
let value = cache.retrieve(for: "key")
```

#### After (Async):
```swift
let cache = InMemoryCache()
let result = await cache.store("value", for: "key")
let value = await cache.retrieve(for: "key")
```

All method calls now require `await` keyword. The API surface remains the same, only the calling convention has changed.

## [1.2.0] - 2025-01-08

### Fixed
- **Critical**: Fixed race condition in `InMemoryCache` concurrent queue operations
  - All write operations now use `.sync(flags: .barrier)` for thread-safe writes
  - Read operations use standard `.sync` for concurrent read access
  - Separated read-modify-write operations in `retrieve()` to use proper barriers
  - Fixed timer-based cleanup to execute on main thread and use barrier for modifications
  - Eliminates data corruption from simultaneous write operations

### Changed
- Improved thread safety of cache operations using DispatchQueue barriers
- Enhanced `retrieve()` method to separate read and write phases
- Timer-based cleanup now explicitly runs on main thread for consistency

### Details

#### Operations Updated with Barrier Flags:
- `store(_:for:)` - Uses barrier for cache writes
- `remove(for:)` - Uses barrier for cache modifications  
- `clear()` - Uses barrier for clearing entire cache
- `storeBatch(_:)` - Uses barrier for batch writes
- `removeBatch(for:)` - Uses barrier for batch removals
- `store(_:for:expirationDate:)` - Uses barrier for writes with expiration
- `removeExpired()` - Uses barrier for expired item removal

#### Read-Only Operations (No Barrier):
- `retrieve(for:)` - Now properly separated into read + conditional write with barrier
- `exists(for:)` - Read-only check
- `retrieveBatch(for:)` - Concurrent read operation
- `statistics` - Read-only cache statistics

### Migration Guide
No API changes - this is a transparent fix. All existing code continues to work without modifications.

## [1.1.0] - Prior releases

See git history for earlier changes.

