//
//  PersistentProperty.swift
//  Copyright © 2024 Jason Fieldman.
//

import Combine
import Foundation

public enum PersistentPropertyError: Error {
    /// An error occurred while storing data.
    ///
    /// - Parameters:
    ///   - error: The underlying error that occurred during storage.
    case storeError(Error)

    /// An error occurred while retrieving data.
    ///
    /// - Parameters:
    ///   - error: The underlying error that occurred during retrieval.
    case retrieveError(Error)
}

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
    ) throws(PersistentPropertyError)

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
    ) throws(PersistentPropertyError) -> T?
}

public protocol PersistentPropertyEnvironmentProviding {
    /// The environment identifier for persistent properties.
    var persistentPropertyEnvironmentId: String { get }

    /// The storage engine used for persistent properties.
    var persistentPropertyStorageEngine: PersistentPropertyStorageEngine { get }
}

public struct PersistentPropertyKey {
    /// The main key for the property.
    public let key: String

    /// An optional subkey for more specific storage needs.
    public let subKey: String?

    /// Initializes a PersistentPropertyKey with a main key and an optional subkey.
    ///
    /// - Parameters:
    ///   - key: The main key for the property.
    ///   - subKey: An optional subkey, defaults to nil.
    public init(key: String, subKey: String? = nil) {
        self.key = key
        self.subKey = subKey
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
    private let mutableError = MutableProperty<PersistentPropertyError?>(nil)

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
                mutableError.value = error as? PersistentPropertyError
            }
        })
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
                assertionFailure("You cannot update this property as a side effect of previous modification (invalid cycle.)")
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
                assertionFailure("You cannot update this property as a side effect of previous modification (invalid cycle.)")
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
                if isModifying {
                    assertionFailure("Cannot read property value imperatively during a side effect of modification")
                }
                return _value
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
                assertionFailure("Cannot subscribe to a property value as a side effect of modification")
            }
            isModifying = true
            subject.receive(subscriber: subscriber)
            isModifying = false
        }
    }
}
