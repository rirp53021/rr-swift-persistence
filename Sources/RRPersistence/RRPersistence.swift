import Foundation

/// Main module for RRPersistence
/// Provides local data storage capabilities including UserDefaults, Keychain, and InMemoryCache
/// with enhanced error handling using Result types and comprehensive logging
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

// MARK: - RRPersistence Configuration

/// Configuration for RRPersistence framework
public struct RRPersistenceConfiguration {
    /// Global logger configuration
    public static var logger: Logger = Logger.withCategory("RRPersistence")
    
    /// Whether to enable performance logging by default
    public static var enablePerformanceLogging: Bool = true
    
    /// Default UserDefaults storage configuration
    public static var defaultUserDefaults: UserDefaultsStorage = {
        UserDefaultsStorage(logger: logger)
    }()
    
    /// Default Keychain storage configuration
    public static var defaultKeychain: KeychainStorage = {
        KeychainStorage(service: "RRPersistence", logger: logger)
    }()
    
    /// Default InMemory cache configuration
    public static var defaultCache: InMemoryCache = {
        InMemoryCache(logger: logger)
    }()
    
    /// Configures the global logger for RRPersistence
    /// - Parameters:
    ///   - isEnabled: Whether logging is enabled
    ///   - logLevel: The minimum log level to display
    ///   - category: The category for organizing logs
    public static func configureLogging(
        isEnabled: Bool = true,
        logLevel: Logger.LogLevel = .info,
        category: String = "RRPersistence"
    ) {
        logger.configure(isEnabled: isEnabled, logLevel: logLevel, category: category)
    }
}
