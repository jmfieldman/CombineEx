//
//  PersistentProperty.swift
//  Copyright © 2024 Jason Fieldman.
//

import Combine
import Foundation
import Security

public protocol PersistentPropertyStorageEngine: Sendable {
    /// Stores a value in the persistent storage.
    ///
    /// - Parameters:
    ///   - value: The value to be stored, conforming to Codable.
    ///   - key: The key under which the value should be stored.
    ///
    /// - Throws: PersistentPropertyError if storing fails.
    func store(
        value: some Codable,
        key: PersistentPropertyKey
    ) throws

    /// Retrieves a value from the persistent storage.
    ///
    /// - Parameters:
    ///   - key: The key under which the value is stored.
    ///
    /// - Returns: The retrieved value, if available, conforming to Codable.
    /// - Throws: PersistentPropertyError if retrieval fails.
    func retrieve<T: Codable>(
        key: PersistentPropertyKey
    ) throws -> T?
}

public struct PersistentPropertyKey: Hashable, Sendable {
    /// The main key for the property.
    public let key: String

    /// An optional subkey for more specific storage needs.
    public let subKey: String?

    /// A string suitable as a key for storage systems that require a sanitized string.
    public let sanitizedIndex: String

    /// Initializes a PersistentPropertyKey with a main key and an optional subkey.
    ///
    /// - Parameters:
    ///   - key: The main key for the property.
    ///   - subKey: An optional subkey, defaults to nil.
    public init(
        key: CustomStringConvertible,
        subKey: CustomStringConvertible? = nil
    ) {
        self.key = key.description
        self.subKey = subKey?.description

        let illegalCharacters = CharacterSet(charactersIn: "/\\?%*:|\"<>")
            .union(.whitespacesAndNewlines)
            .union(.illegalCharacters)
            .union(.controlCharacters)

        self.sanitizedIndex = self.key.unicodeScalars.map { illegalCharacters.contains($0) ? "_" : String($0) }.joined() +
            (self.subKey ?? "").unicodeScalars.map { illegalCharacters.contains($0) ? "_" : String($0) }.joined()
    }
}

public final class PersistentProperty<Output: Codable>: ComposableMutablePropertyProtocol, @unchecked Sendable {
    /// The type of error that can be produced by this property, which is never.
    public typealias Failure = Never

    /// A property that holds the current error state of this persistent property.
    public let error: Property<Error?>

    /// The storage engine for this property.
    private let storageEngine: any PersistentPropertyStorageEngine

    /// The key that identifies this property in the storage.
    private let key: PersistentPropertyKey

    /// A lock to ensure thread safety when modifying the value.
    private let lock = NSRecursiveLock()

    /// The internal storage for the current value of the property.
    private var _value: Output

    /// A flag to indicate if there is an ongoing modification.
    private var isModifying = false

    /// A subject that emits the current value of the property.
    private let subject: CurrentValueSubject<Output, Failure>

    /// A queue for handling write operations.
    private let writeQueue: DispatchQueue

    /// A cancellable for the write operation.
    private var writeCancellable: AnyCancellable?

    /// A mutable property that holds the current error, if any.
    private let mutableError = MutableProperty<Error?>(nil)

    /// Initializes a PersistentProperty with an initial value.
    ///
    /// - Parameters:
    ///   - environment: An object that provides the persistent property storage engine and environment ID.
    ///   - key: The key that identifies this property in the persistent storage.
    ///   - defaultValue: The default value to use if no value is found in the persistent storage.
    public init(
        storageEngine: any PersistentPropertyStorageEngine,
        key: PersistentPropertyKey,
        defaultValue: Output
    ) {
        var initialValue: Output?

        do {
            initialValue = try storageEngine.retrieve(key: key)
        } catch {
            mutableError.value = error
        }

        self.storageEngine = storageEngine
        self.key = key
        self.error = Property(mutableError)
        self.writeQueue = DispatchQueue(label: "PersistentProperty.writeQueue.\(key)")
        self._value = initialValue ?? defaultValue
        self.subject = .init(_value)
        self.writeCancellable = subject.sink(receiveValue: { [weak self] value in
            guard let self else { return }
            do {
                try self.storageEngine.store(
                    value: value,
                    key: key
                )
            } catch {
                mutableError.value = error
            }
        })
    }

    public convenience init(
        storageEngine: any PersistentPropertyStorageEngine,
        key: CustomStringConvertible,
        defaultValue: Output
    ) {
        self.init(
            storageEngine: storageEngine,
            key: PersistentPropertyKey(key: key),
            defaultValue: defaultValue
        )
    }

    /// Updates the internal value container then sends the value to the
    /// internal passthrough subject.
    ///
    /// It is considered a programming error for this function be called
    /// as a downstream side effect of updating the passthrough subject,
    /// since it indicates there is a cycle in your reactive graph.
    ///
    /// - Parameters:
    ///   - value: The new value to be set.
    private func update(_ value: Output) {
        lock.withLock {
            if isModifying {
                assertionFailure("It is considered a programming error if the value of a PersistentProperty is updated as an immediate side effect of a previous update or subscription (invalid update cycle.)")
            }
            isModifying = true
            _value = value
            subject.send(value)
            isModifying = false
        }
    }

    /// Allows the caller to modify the value as a single atomic operation.
    ///
    /// This is not a thread-safe increment:
    ///   mutableProperty.value = mutableProperty.value + 1
    ///
    /// This is considered a thread-safe increment:
    ///   mutableProperty.modify { $0 += 1 }
    ///
    /// - Parameters:
    ///   - block: A closure that takes a mutable reference to the value and modifies it.
    public func modify(_ block: (inout Output) -> Void) {
        lock.withLock {
            if isModifying {
                assertionFailure("It is considered a programming error if the value of a PersistentProperty is updated as an immediate side effect of a previous update or subscription (invalid update cycle.)")
            }
            isModifying = true
            block(&_value)
            subject.send(_value)
            isModifying = false
        }
    }

    /// Allows the caller to perform an action with the current value as an
    /// atomic operation.
    ///
    /// - Parameters:
    ///   - action: A closure that takes the current value and returns a result.
    ///
    /// - Returns: The result of the action.
    public func withValue<Result>(_ action: (Output) -> Result) -> Result {
        lock.withLock {
            action(_value)
        }
    }

    /// Allows the caller to perform an action with the current value as an
    /// atomic operation.
    ///
    /// - Parameters:
    ///   - action: A throwing closure that takes the current value and returns a result.
    ///
    /// - Returns: The result of the action.
    /// - Throws: An error if the action throws.
    public func tryWithValue<Result>(_ action: (Output) throws -> Result) rethrows -> Result {
        try lock.withLock {
            try action(_value)
        }
    }
}

public extension PersistentProperty {
    /// Returns the current value.
    ///
    /// It is considered a programming error to read this value imperatively during a
    /// downstream side effect of this Property being modified. You can refactor your
    /// publisher chain so that this read occurs on a separate thread, or pipe the value
    /// around outside of this Property.
    ///
    /// - Returns: The current value of the property.
    var value: Output {
        get {
            lock.withLock {
                _value
            }
        }

        set {
            update(newValue)
        }
    }

    /// Receives a subscriber for the property's value changes.
    ///
    /// - Parameters:
    ///   - subscriber: The subscriber that will receive the property's value changes.
    func receive<S>(subscriber: S) where S: Subscriber, Never == S.Failure, Output == S.Input {
        lock.withLock {
            if isModifying {
                assertionFailure("It is considered a programming error if the value of a PersistentProperty is updated as an immediate side effect of a previous update or subscription (invalid update cycle.)")
            }
            isModifying = true
            subject.receive(subscriber: subscriber)
            isModifying = false
        }
    }
}

// MARK: - Concrete File-Based Persistence Engine

/// An enumeration representing possible errors that can occur in the `FileBasedPersistentPropertyStorageEngine`.
public enum FileBasedPersistentPropertyStorageEngineError: Error {
    /// Indicates that the root directory is not available.
    case noRootDirectory

    /// Indicates an error occurred while attempting to create a directory.
    /// - Parameter underlyingError: The original error that caused the failure to create the directory.
    case unableToCreateDirectory(Error)

    /// Indicates an error occurred while constructing or handling a file path.
    case filePathError

    /// Indicates an error occurred during encoding data to disk.
    /// - Parameter underlyingError: The original error that caused the failure to encode data to disk.
    case encodeToDiskError(Error)

    /// Indicates an error occurred during decoding data from disk.
    /// - Parameter underlyingError: The original error that caused the failure to decode data from disk.
    case decodeFromDiskError(Error)
}

/// A default storage engine that can be used for simple file-based value storage.
public final class FileBasedPersistentPropertyStorageEngine: PersistentPropertyStorageEngine, Sendable {
    /// Specifies the root directory used for this File-based engine
    public enum RootDirectory {
        /// Standard Documents directory
        case documents

        /// Standard Caches directory
        case caches

        /// Temporary directory
        case temporary

        /// Use the App Group document container. Useful for sharing storage with
        /// your app extensions.
        case appGroup(String)
    }

    /// The root directory where persistent properties are stored.
    private let rootDirectoryUrl: URL?

    /// An error that occurred during the initialization of the storage engine, if any.
    private let initializationError: FileBasedPersistentPropertyStorageEngineError?

    /// Initializes the storage engine with a specified root directory
    /// - Parameters:
    ///   - rootDirectoryUrl: The directory to store all persistent value files
    public init(rootDirectoryUrl: URL) {
        do {
            try FileManager.default.createDirectory(at: rootDirectoryUrl, withIntermediateDirectories: true, attributes: nil)
        } catch {
            self.initializationError = .unableToCreateDirectory(error)
            self.rootDirectoryUrl = nil
            return
        }

        self.initializationError = nil
        self.rootDirectoryUrl = rootDirectoryUrl
    }

    /// Initializes the storage engine with a specified environment ID and root directory option.
    /// - Parameters:
    ///   - environmentId: A unique identifier for the environment.
    ///   - rootDirectory: A enum of possible root storage directories.
    public init(environmentId: String, rootDirectory: RootDirectory) {
        let directoryUrl: URL? = switch rootDirectory {
        case .documents:
            FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        case .caches:
            FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
        case .temporary:
            URL(fileURLWithPath: NSTemporaryDirectory())
        case let .appGroup(identifier):
            FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
        }

        guard let directoryUrl else {
            self.initializationError = .noRootDirectory
            self.rootDirectoryUrl = nil
            return
        }

        let appended = directoryUrl.appendingPathComponent(environmentId).appendingPathComponent("_PersistentProperties_")

        do {
            try FileManager.default.createDirectory(at: appended, withIntermediateDirectories: true, attributes: nil)
        } catch {
            self.initializationError = .unableToCreateDirectory(error)
            self.rootDirectoryUrl = nil
            return
        }

        self.initializationError = nil
        self.rootDirectoryUrl = appended
    }

    /// Attempt to wipe and restore the directory holding the persistent property values
    public func wipeDirectory() {
        guard let rootDirectoryUrl else {
            return
        }

        try? FileManager.default.removeItem(at: rootDirectoryUrl)
        try? FileManager.default.createDirectory(at: rootDirectoryUrl, withIntermediateDirectories: true, attributes: nil)
    }

    /// Ensures that codable primitives are wrapped in a dictionary
    private struct CodableBox<T: Codable>: Codable {
        let value: T
    }

    /// Stores a value to the file system with the specified environment ID and key.
    /// - Parameters:
    ///   - value: The value to store, must conform to `Codable`.
    ///   - key: The key under which the value is stored, must conform to `PersistentPropertyKey`.
    /// - Throws: An error if the storage engine is not properly initialized, a file path error occurs,
    ///           or an encoding error occurs.
    public func store(value: some Codable, key: PersistentPropertyKey) throws {
        if let error = initializationError {
            throw error
        }

        guard let fileURL = rootDirectoryUrl?.appendingPathComponent(key.sanitizedIndex) else {
            throw FileBasedPersistentPropertyStorageEngineError.filePathError
        }

        do {
            let data = try JSONEncoder().encode(CodableBox(value: value))
            try data.write(to: fileURL, options: .atomic)
        } catch {
            throw FileBasedPersistentPropertyStorageEngineError.encodeToDiskError(error)
        }
    }

    /// Retrieves a value from the file system with the specified environment ID and key.
    /// - Parameters:
    ///   - key: The key under which the value is stored, must conform to `PersistentPropertyKey`.
    /// - Throws: An error if the storage engine is not properly initialized, a file path error occurs,
    ///           or a decoding error occurs.
    /// - Returns: The retrieved value, if it exists and can be decoded; otherwise, `nil`.
    public func retrieve<T>(key: PersistentPropertyKey) throws -> T? where T: Codable {
        if let error = initializationError {
            throw error
        }

        guard let fileURL = rootDirectoryUrl?.appendingPathComponent(key.sanitizedIndex) else {
            throw FileBasedPersistentPropertyStorageEngineError.filePathError
        }

        if !FileManager.default.isReadableFile(atPath: fileURL.path) {
            // It is not an error if the file is not present; a value may not
            // have been written yet. Just return nil here.
            return nil
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let obj = try JSONDecoder().decode(CodableBox<T>.self, from: data)
            return obj.value
        } catch {
            throw FileBasedPersistentPropertyStorageEngineError.decodeFromDiskError(error)
        }
    }
}

// MARK: - Concrete Keychain-Based Persistence Engine

/// An enumeration representing possible errors that can occur in the `FileBasedPersistentPropertyStorageEngine`.
public enum KeychainPersistentPropertyStorageEngineError: Error {
    /// A security error occurred accessing the data from the keychain.
    case securityError(OSStatus)

    /// Indicates an error occurred during encoding.
    /// - Parameter underlyingError: The original error that caused the failure to encode.
    case encodeError(Error)

    /// Indicates an error occurred during decoding.
    /// - Parameter underlyingError: The original error that caused the failure to decode.
    case decodeError(Error)
}

public final class KeychainPersistentPropertyStorageEngine: PersistentPropertyStorageEngine, Sendable {
    private let accessGroup: String
    private let service: String
    private let synchronized: Bool

    /// Use the device keychain
    ///  - accessGroup: The keychain access group. Make sure you have Keychain Sharing
    ///    entitlements with at least one access group enabled. The string you pass to
    ///    `accessGroup` should be prefixes with your 10-digit `AppIdentifierPrefix`
    ///    bundle value, e.g. "XXXXXXXXXX.com.yourdomain.yourgroup"
    ///  - service: represents the keychain service string, but should be some value
    ///    representing the access scope of your key/value pairs. For example, you
    ///    can construct it like, "\(app_name)_\(userId)_\(prod|dev|local)"
    ///  - synchronized: whether or not to synchronize this in the iCloud keychain
    public init(accessGroup: String, service: String, synchronized: Bool) {
        self.accessGroup = accessGroup
        self.service = service
        self.synchronized = synchronized
    }

    /// Ensures that codable primitives are wrapped in a dictionary
    private struct CodableBox<T: Codable>: Codable {
        let value: T
    }

    /// Stores a value to the keychain key.
    /// - Parameters:
    ///   - value: The value to store, must conform to `Codable`.
    ///   - key: The key under which the value is stored, must conform to `PersistentPropertyKey`.
    /// - Throws: An error if the storage engine is not properly initialized, a file path error occurs,
    ///           or an encoding error occurs.
    public func store(value: some Codable, key: PersistentPropertyKey) throws {
        let data: Data
        do {
            data = try JSONEncoder().encode(CodableBox(value: value))
        } catch {
            throw KeychainPersistentPropertyStorageEngineError.encodeError(error)
        }

        let keychainItem = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key.sanitizedIndex,
            kSecAttrService: service,
            kSecAttrAccessGroup: accessGroup,
            kSecAttrSynchronizable: synchronized,
            kSecValueData: data,
        ] as [String: Any]

        let status = SecItemAdd(keychainItem as CFDictionary, nil)
        if status != errSecSuccess {
            // Attempt to update instead
            let query = [
                kSecClass: kSecClassGenericPassword,
                kSecAttrSynchronizable: synchronized,
                kSecAttrAccount: key.sanitizedIndex,
                kSecAttrService: service,
                kSecAttrAccessGroup: accessGroup,
            ] as [String: Any]

            let updateStatus = SecItemUpdate(query as CFDictionary, [kSecValueData: data] as CFDictionary)
            if updateStatus != errSecSuccess {
                throw KeychainPersistentPropertyStorageEngineError.securityError(updateStatus)
            }
        }
    }

    /// Retrieves a value from the keychain with the specified environment ID and key.
    /// - Parameters:
    ///   - key: The key under which the value is stored, must conform to `PersistentPropertyKey`.
    /// - Throws: An error if the storage engine is not properly initialized, a file path error occurs,
    ///           or a decoding error occurs.
    /// - Returns: The retrieved value, if it exists and can be decoded; otherwise, `nil`.
    public func retrieve<T>(key: PersistentPropertyKey) throws -> T? where T: Decodable, T: Encodable {
        let query = [
            kSecMatchLimit: kSecMatchLimitOne,
            kSecReturnData: true,
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key.sanitizedIndex,
            kSecAttrService: service,
            kSecAttrAccessGroup: accessGroup,
        ] as [String: Any]

        var readData: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &readData)
        guard status == errSecSuccess, let data = readData as? Data else {
            throw KeychainPersistentPropertyStorageEngineError.securityError(status)
        }

        do {
            let obj = try JSONDecoder().decode(CodableBox<T>.self, from: data)
            return obj.value
        } catch {
            throw FileBasedPersistentPropertyStorageEngineError.decodeFromDiskError(error)
        }
    }
}
