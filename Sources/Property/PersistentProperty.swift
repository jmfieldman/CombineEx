//
//  PersistentProperty.swift
//  Copyright © 2025 Jason Fieldman.
//

import Combine
import Foundation

public enum PersistentPropertyError: Error {
    case storeError(Error)
    case retrieveError(Error)
}

public protocol PersistentPropertyStorageEngine {
    func store<T: Codable>(
        value: T,
        environmentId: String,
        key: PersistentPropertyKey
    ) throws(PersistentPropertyError)

    func retrieve<T: Codable>(
        environmentId: String,
        key: PersistentPropertyKey
    ) throws(PersistentPropertyError) -> T?
}

public protocol PersistentPropertyEnvironmentProviding {
    var persistentPropertyEnvironmentId: String { get }
    var persistentPropertyStorageEngine: PersistentPropertyStorageEngine { get }
}

public struct PersistentPropertyKey {
    public let key: String
    public let subKey: String?

    public init(key: String, subKey: String? = nil) {
        self.key = key
        self.subKey = subKey
    }
}

public final class PersistentProperty<Output: Codable>: ComposableMutablePropertyProtocol {
    public typealias Failure = Never

    public private(set) lazy var error = Property(mutableError)

    private let environment: PersistentPropertyEnvironmentProviding
    private let key: PersistentPropertyKey
    private let lock = NSRecursiveLock()
    private var _value: Output
    private var isModifying = false
    private let subject: CurrentValueSubject<Output, Failure>
    private lazy var writeQueue = DispatchQueue(label: "PersistentProperty.writeQueue.\(key.key)\(key.subKey.flatMap { ".\($0)" } ?? "")")
    private var writeCancellable: AnyCancellable?
    private let mutableError = MutableProperty<PersistentPropertyError?>(nil)

    /// Initializes a MutableProperty with an initial value.
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
    public func withValue<Result>(_ action: (Output) -> Result) -> Result {
        lock.withLock {
            action(_value)
        }
    }

    /// Allows the caller to perform an action with the current value as an
    /// atomic operation.
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
