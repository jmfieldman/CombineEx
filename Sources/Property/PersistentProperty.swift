//
//  PersistentProperty.swift
//  Copyright © 2024 Jason Fieldman.
//

import Combine
import Foundation

public protocol PersistentPropertyStorageEngine {
    /// Stores a value in the persistent storage.
    ///
    /// - Parameters:
    ///   - value: The value to be stored, conforming to Codable.
    ///   - environmentId: The identifier for the environment.
    ///   - key: The key under which the value should be stored.
    ///
    /// - Throws: PersistentPropertyError if storing fails.
    func store(
        value: some Codable,
        environmentId: String,
        key: PersistentPropertyKey
    ) throws

    /// Retrieves a value from the persistent storage.
    ///
    /// - Parameters:
    ///   - environmentId: The identifier for the environment.
    ///   - key: The key under which the value is stored.
    ///
    /// - Returns: The retrieved value, if available, conforming to Codable.
    /// - Throws: PersistentPropertyError if retrieval fails.
    func retrieve<T: Codable>(
        environmentId: String,
        key: PersistentPropertyKey
    ) throws -> T?
}

public protocol PersistentPropertyEnvironmentProviding {
    /// The environment identifier for persistent properties.
    var persistentPropertyEnvironmentId: String { get }

    /// The storage engine used for persistent properties.
    var persistentPropertyStorageEngine: any PersistentPropertyStorageEngine { get }
}

public struct PersistentPropertyKey {
    /// The main key for the property.
    public let key: CustomStringConvertible

    /// An optional subkey for more specific storage needs.
    public let subKey: CustomStringConvertible?

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
        self.key = key
        self.subKey = subKey

        let illegalCharacters = CharacterSet(charactersIn: "/\\?%*:|\"<>")
            .union(.whitespacesAndNewlines)
            .union(.illegalCharacters)
            .union(.controlCharacters)

        self.sanitizedIndex = key.description.unicodeScalars.map { illegalCharacters.contains($0) ? "_" : String($0) }.joined() +
            (subKey.flatMap { ".\($0.description)" } ?? "").unicodeScalars.map { illegalCharacters.contains($0) ? "_" : String($0) }.joined()
    }
}

public final class PersistentProperty<Output: Codable>: ComposableMutablePropertyProtocol {
    /// The type of error that can be produced by this property, which is never.
    public typealias Failure = Never

    /// A property that holds the current error state of this persistent property.
    public private(set) lazy var error = Property(mutableError)

    /// The environment provider that provides the storage engine and environment ID.
    private let environment: PersistentPropertyEnvironmentProviding

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
    private lazy var writeQueue = DispatchQueue(label: "PersistentProperty.writeQueue.\(key)")

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
        environment: PersistentPropertyEnvironmentProviding,
        key: PersistentPropertyKey,
        defaultValue: Output
    ) {
        var initialValue: Output?

        do {
            initialValue = try environment.persistentPropertyStorageEngine.retrieve(
                environmentId: environment.persistentPropertyEnvironmentId,
                key: key
            )
        } catch {
            mutableError.value = error
        }

        self.environment = environment
        self.key = key
        self._value = initialValue ?? defaultValue
        self.subject = .init(_value)
        self.writeCancellable = subject.sink(receiveValue: { [weak self] value in
            guard let self else { return }
            do {
                try self.environment.persistentPropertyStorageEngine.store(
                    value: value,
                    environmentId: self.environment.persistentPropertyEnvironmentId,
                    key: key
                )
            } catch {
                mutableError.value = error
            }
        })
    }

    public convenience init(
        environment: PersistentPropertyEnvironmentProviding,
        key: CustomStringConvertible,
        defaultValue: Output
    ) {
        self.init(
            environment: environment,
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

// MARK: - Concrete Default Environments

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

public class FileBasedPersistentPropertyStorageEngine: PersistentPropertyStorageEngine {
    private let rootDirectory: URL?
    private let initializationError: FileBasedPersistentPropertyStorageEngineError?

    init(environmentId: String, cache: Bool) {
        guard let directory = FileManager.default.urls(for: cache ? .cachesDirectory : .documentDirectory, in: .userDomainMask).first else {
            self.initializationError = .noRootDirectory
            self.rootDirectory = nil
            return
        }

        let appended = directory.appendingPathExtension(environmentId).appendingPathComponent("_PersistentProperties_")

        do {
            try FileManager.default.createDirectory(at: appended, withIntermediateDirectories: true, attributes: nil)
        } catch {
            self.initializationError = .unableToCreateDirectory(error)
            self.rootDirectory = nil
            return
        }

        self.initializationError = nil
        self.rootDirectory = appended
    }

    public func store(value: some Codable, environmentId: String, key: PersistentPropertyKey) throws {
        if let error = initializationError {
            throw error
        }

        guard let fileURL = rootDirectory?.appendingPathComponent(key.sanitizedIndex) else {
            throw FileBasedPersistentPropertyStorageEngineError.filePathError
        }

        do {
            let data = try JSONEncoder().encode(value)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            throw FileBasedPersistentPropertyStorageEngineError.encodeToDiskError(error)
        }
    }

    public func retrieve<T>(environmentId: String, key: PersistentPropertyKey) throws -> T? where T: Codable {
        if let error = initializationError {
            throw error
        }

        guard let fileURL = rootDirectory?.appendingPathComponent(key.sanitizedIndex) else {
            throw FileBasedPersistentPropertyStorageEngineError.filePathError
        }

        if !FileManager.default.isReadableFile(atPath: fileURL.path) {
            // It is not an error if the file is not present; a value may not
            // have been written yet. Just return nil here.
            return nil
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let obj = try JSONDecoder().decode(T.self, from: data)
            return obj
        } catch {
            throw FileBasedPersistentPropertyStorageEngineError.decodeFromDiskError(error)
        }
    }
}

public struct FileBasedPersistentPropertyEnvironment: PersistentPropertyEnvironmentProviding {
    public let persistentPropertyEnvironmentId: String
    public let persistentPropertyStorageEngine: any PersistentPropertyStorageEngine

    init(environmentId: String, storageEngine: any PersistentPropertyStorageEngine) {
        self.persistentPropertyEnvironmentId = environmentId
        self.persistentPropertyStorageEngine = storageEngine
    }
}

private let __defaultCacheStorage = FileBasedPersistentPropertyEnvironment(
    environmentId: "default_environment",
    storageEngine: FileBasedPersistentPropertyStorageEngine(environmentId: "default_environment", cache: true)
)

private let __defaultDocumentStorage = FileBasedPersistentPropertyEnvironment(
    environmentId: "default_environment",
    storageEngine: FileBasedPersistentPropertyStorageEngine(environmentId: "default_environment", cache: false)
)

public extension PersistentPropertyEnvironmentProviding {
    var defaultCaches: FileBasedPersistentPropertyEnvironment { __defaultCacheStorage }
    var defaultDocuments: FileBasedPersistentPropertyEnvironment { __defaultDocumentStorage }
}
