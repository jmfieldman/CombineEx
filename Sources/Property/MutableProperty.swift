//
//  MutableProperty.swift
//  Copyright © 2024 Jason Fieldman.
//

import Combine
import Foundation

public protocol MutablePropertyProtocol<Output>: PropertyProtocol {
    /// The current value of the property
    var value: Output { get set }
}

public protocol ComposableMutablePropertyProtocol<Output>: MutablePropertyProtocol {
    /// Allows the caller to modify the value as a single atomic operation.
    ///
    /// This is not a thread-safe increment:
    ///   mutableProperty.value = mutableProperty.value + 1
    ///
    /// This is considered a thread-safe increment:
    ///   mutableProperty.modify { $0 += 1 }
    ///
    func modify(_ block: (inout Output) -> Void)

    /// Allows the caller to perform an action with the current value as an
    /// atomic operation.
    func withValue<Result>(_ action: (Output) -> Result) -> Result

    /// Allows the caller to perform an action with the current value as an
    /// atomic operation.
    func tryWithValue<Result>(_ action: (Output) throws -> Result) rethrows -> Result
}

public final class MutableProperty<Output>: ComposableMutablePropertyProtocol {
    public typealias Failure = Never

    private let lock = NSRecursiveLock()
    private var _value: Output
    private var isModifying = false
    private let subject: CurrentValueSubject<Output, Failure>

    /// Initializes a MutableProperty with an initial value.
    public init(_ value: Output) {
        self._value = value
        self.subject = .init(value)
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
                assertionFailure("It is considered a programming error if the value of a MutableProperty is updated as an immediate side effect of a previous update or subscription (invalid update cycle.)")
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
                assertionFailure("It is considered a programming error if the value of a MutableProperty is updated as an immediate side effect of a previous update or subscription (invalid update cycle.)")
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

public extension MutableProperty {
    /// Returns the current value.
    ///
    /// It is considered a programming error to read this value imperatively during a
    /// downstream side effect of this Property being modified. You can refactor your
    /// publisher chain so that this read occurs on a separate thread, or pipe the value
    /// around outside of this Property.
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

    func receive<S>(subscriber: S) where S: Subscriber, Never == S.Failure, Output == S.Input {
        lock.withLock {
            if isModifying {
                assertionFailure("It is considered a programming error if the value of a MutableProperty is updated as an immediate side effect of a previous update or subscription (invalid update cycle.)")
            }
            isModifying = true
            subject.receive(subscriber: subscriber)
            isModifying = false
        }
    }
}
