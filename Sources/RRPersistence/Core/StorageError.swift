import Foundation
import RRFoundation

// MARK: - Storage Error Types

/// Comprehensive error types for storage operations
public enum StorageError: Error, LocalizedError {
    case keyNotFound(String)
    case encodingFailed(String)
    case decodingFailed(String)
    case synchronizationFailed
    case keychainError(OSStatus)
    case invalidData
    case storageUnavailable
    case permissionDenied
    case quotaExceeded
    case networkError(Error)
    case unknown(Error)
    
    public var errorDescription: String? {
        switch self {
        case .keyNotFound(let key):
            return "Key '\(key)' not found in storage"
        case .encodingFailed(let key):
            return "Failed to encode value for key '\(key)'"
        case .decodingFailed(let key):
            return "Failed to decode value for key '\(key)'"
        case .synchronizationFailed:
            return "Failed to synchronize storage"
        case .keychainError(let status):
            return "Keychain error with status: \(status)"
        case .invalidData:
            return "Invalid data format"
        case .storageUnavailable:
            return "Storage is currently unavailable"
        case .permissionDenied:
            return "Permission denied for storage operation"
        case .quotaExceeded:
            return "Storage quota exceeded"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }
    
    public var failureReason: String? {
        switch self {
        case .keyNotFound:
            return "The requested key does not exist in storage"
        case .encodingFailed:
            return "The value could not be encoded for storage"
        case .decodingFailed:
            return "The stored data could not be decoded"
        case .synchronizationFailed:
            return "The storage synchronization operation failed"
        case .keychainError(let status):
            return "Keychain operation failed with OSStatus: \(status)"
        case .invalidData:
            return "The data format is invalid or corrupted"
        case .storageUnavailable:
            return "The storage system is not available"
        case .permissionDenied:
            return "Insufficient permissions for storage operation"
        case .quotaExceeded:
            return "Storage limit has been reached"
        case .networkError:
            return "Network connectivity issue"
        case .unknown:
            return "An unexpected error occurred"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .keyNotFound:
            return "Check if the key exists before retrieving"
        case .encodingFailed:
            return "Ensure the value conforms to Codable protocol"
        case .decodingFailed:
            return "Verify the stored data format matches expected type"
        case .synchronizationFailed:
            return "Try the operation again or check storage permissions"
        case .keychainError:
            return "Check keychain access permissions and try again"
        case .invalidData:
            return "Verify data integrity and format"
        case .storageUnavailable:
            return "Check storage system status and try again"
        case .permissionDenied:
            return "Request appropriate storage permissions"
        case .quotaExceeded:
            return "Free up storage space and try again"
        case .networkError:
            return "Check network connectivity and try again"
        case .unknown:
            return "Contact support if the issue persists"
        }
    }
}

// MARK: - Storage Error Extensions

public extension StorageError {
    
    /// Creates a StorageError from a generic Error
    /// - Parameter error: The underlying error
    /// - Returns: A StorageError instance
    static func from(_ error: Error) -> StorageError {
        if let storageError = error as? StorageError {
            return storageError
        }
        return .unknown(error)
    }
    
    /// Creates a StorageError from an OSStatus (for Keychain operations)
    /// - Parameter status: The OSStatus code
    /// - Returns: A StorageError instance
    static func fromKeychainStatus(_ status: OSStatus) -> StorageError {
        return .keychainError(status)
    }
    
    /// Logs the error using RRFoundation's Logger
    /// - Parameters:
    ///   - context: Additional context information
    ///   - operation: The operation that failed
    func log(context: String? = nil, operation: String? = nil) {
        var logMessage = "Storage Error: \(localizedDescription)"
        
        if let context = context {
            logMessage += " | Context: \(context)"
        }
        
        if let operation = operation {
            logMessage += " | Operation: \(operation)"
        }
        
        if let reason = failureReason {
            logMessage += " | Reason: \(reason)"
        }
        
        if let suggestion = recoverySuggestion {
            logMessage += " | Suggestion: \(suggestion)"
        }
        
        Logger.shared.error(logMessage)
    }
}

// MARK: - Result Extensions for Storage

public extension Result where Failure == StorageError {
    
    /// Logs the error if the result is a failure
    /// - Parameters:
    ///   - context: Additional context information
    ///   - operation: The operation that failed
    /// - Returns: The same result for chaining
    @discardableResult
    func logError(context: String? = nil, operation: String? = nil) -> Result<Success, Failure> {
        if case .failure(let error) = self {
            error.log(context: context, operation: operation)
        }
        return self
    }
    
    /// Maps a generic Error to StorageError
    /// - Parameter error: The error to map
    /// - Returns: A new result with StorageError
    static func fromError(_ error: Error) -> Result<Success, StorageError> {
        return .failure(.from(error))
    }
}
