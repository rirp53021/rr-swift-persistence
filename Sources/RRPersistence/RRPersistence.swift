import Foundation

/// Main module for RRPersistence
/// Provides local data storage capabilities including UserDefaults, Keychain, CoreData, and InMemoryCache
@_exported import RRFoundation

// Re-export the main types for easier access
public typealias RRPersistenceUserDefaults = UserDefaultsStorage
public typealias RRPersistenceKeychain = KeychainStorage
public typealias RRPersistenceCache = InMemoryCache

/// Version information for the RRPersistence framework
public enum RRPersistenceVersion {
    /// Current version of the RRPersistence framework
    public static let current = "1.0.0"
}
