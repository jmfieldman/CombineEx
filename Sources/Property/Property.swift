//
//  Property.swift
//  Copyright © 2024 Jason Fieldman.
//

import Combine
import Foundation

public protocol PropertyProtocol<Output>: AnyObject, Publisher where Failure == Never {
    var value: Output { get }
}

public final class Property<Output>: PropertyProtocol, @unchecked Sendable {
    public typealias Failure = Never

    private let lock = NSRecursiveLock()
    private var _value: Output!
    private var isModifying = false
    private let subject = PassthroughSubject<Output, Failure>()
    private let captured: (any PropertyProtocol)?
    private var cancellable: AnyCancellable?

    /// Initializes a Property with a constant value.
    public init(value: Output) {
        self._value = value
        self.captured = nil
        self.cancellable = nil
    }

    /// Initializes a Property as a wrapper capturing another PropertyProtocol.
    /// This can be used to convert another PropertyProtocol implementation to
    /// a concrete read-only Property.
    public init<P: PropertyProtocol>(_ capturing: P) where P.Output == Output {
        self._value = capturing.value
        self.captured = capturing
        self.cancellable = capturing.sink(receiveValue: { [weak self] value in
            self?.update(value)
        })
    }

    /// Initializes a Property with an initial value, and then updates with each
    /// new value from the provided publisher.
    public init(initial: Output, then: some Publisher<Output, Never>) {
        self._value = initial
        self.captured = nil
        self.cancellable = then.sink(receiveValue: { [weak self] value in
            self?.update(value)
        })
    }

    /// Initializes a property from an unsafe Publisher. The publisher *must*
    /// emit an initial value *immediately* when it is initially subscribed to.
    /// This is primarily used to lift Property operators. The extra capturing
    /// argument is to ensure that the lifted Property is not deallocated out
    /// from underneath the new Property.
    init(unsafe: some Publisher<Output, Never>, capturing: (any PropertyProtocol)?) {
        self.captured = capturing
        self.cancellable = unsafe.sink(receiveValue: { [weak self] value in
            self?.update(value)
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
                assertionFailure("It is considered a programming error if the value of a Property is updated as an immediate side effect of a previous update or subscription (invalid update cycle.)")
            }
            isModifying = true
            _value = value
            subject.send(value)
            isModifying = false
        }
    }
}

public extension Property {
    /// Returns the current value.
    var value: Output {
        lock.withLock {
            _value
        }
    }

    func receive<S>(subscriber: S) where S: Subscriber, Never == S.Failure, Output == S.Input {
        lock.withLock {
            isModifying = true
            subject.prepend(_value).receive(subscriber: subscriber)
            isModifying = false
        }
    }
}
