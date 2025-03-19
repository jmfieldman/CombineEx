//
//  DeferredPublisher.swift
//  Copyright © 2025 Jason Fieldman.
//

import Combine

// MARK: - DeferredPublisherProtocol

/// A protocol that represents a "deferred" publisher, which runs its internal
/// work at point of subscription, for each subscriber.
///
/// - Note: By conforming to `DeferredPublisherProtocol`, a type promises
///   that it will create (or re-create) its underlying publisher on demand
///   through `createPublisher`.
public protocol DeferredPublisherProtocol<Output, Failure>: Publisher {
    /// A publisher capable of producing values of `Output` or failing with `Failure`.
    associatedtype WrappedPublisher = any Publisher<Output, Failure>

    /// A closure that, when called, returns a new instance of the
    /// wrapped publisher. This publisher is typically created "just in time"
    /// for a subscriber.
    ///
    /// - Returns: A newly created `WrappedPublisher` for each subscription.
    var createPublisher: () -> WrappedPublisher { get }
}

// MARK: - Deferred Extension

extension Deferred: DeferredPublisherProtocol {
    /// Erases this deferred publisher to an `AnyDeferredPublisher`,
    /// hiding its concrete type.
    ///
    /// Use this method when you need to return a type-erased version of a
    /// deferred publisher, such as from a public API or library module.
    ///
    /// - Returns: An `AnyDeferredPublisher` wrapping this `Deferred` publisher.
    public func eraseToAnyDeferredPublisher() -> AnyDeferredPublisher<Output, Failure> {
        AnyDeferredPublisher(self)
    }
}

// MARK: - AnyDeferredPublisher

/// A type-erased deferred publisher that wraps any `Deferred` publisher,
/// hiding its concrete type. This allows you to return a "deferred" publisher
/// from a public API without exposing implementation details.
///
/// `AnyDeferredPublisher` stores a closure that creates the underlying
/// publisher upon subscription, delaying the creation of the actual publisher
/// until values are requested. This is similar to Combine's `AnyPublisher`,
/// but specifically designed for deferred work.
public class AnyDeferredPublisher<Output, Failure: Error>: DeferredPublisherProtocol {
    /// A convenience type alias for the publisher produced by this deferred publisher.
    public typealias WrappedPublisher = AnyPublisher<Output, Failure>

    /// Internally wrapped `Deferred` publisher that creates a new
    /// `AnyPublisher` each time it is subscribed to.
    private let deferredPublisher: Deferred<WrappedPublisher>

    /// Creates a new `AnyDeferredPublisher` by wrapping the given `Deferred`
    /// publisher, then erasing its type to `AnyPublisher`.
    ///
    /// - Parameter deferredPublisher: A deferred publisher that will be
    ///   wrapped and type-erased.
    /// - Note: Each subscription to this `AnyDeferredPublisher` invokes the
    ///   `deferredPublisher.createPublisher()` closure, which produces a fresh
    ///   `AnyPublisher<Output, Failure>`.
    public init(
        _ deferredPublisher: Deferred<some Publisher<Output, Failure>>
    ) {
        // Wrap the incoming `Deferred`, erasing it to `AnyPublisher<Output, Failure>`.
        self.deferredPublisher = Deferred {
            deferredPublisher
                .createPublisher()
                .eraseToAnyPublisher()
        }
    }

    /// A convenience initializer that takes a closure to create the
    /// underlying publisher on demand.
    ///
    /// - Parameter createPublisher: A closure that returns a `WrappedPublisher`
    ///   every time it's called. This closure is deferred until subscription.
    public convenience init(
        createPublisher: @escaping () -> WrappedPublisher
    ) {
        // Wrap the closure in a Deferred<WrappedPublisher>, then
        // forward to the designated initializer.
        self.init(Deferred(createPublisher: createPublisher))
    }

    // MARK: - Publisher Conformance

    /// Subscribes a `Subscriber` to this publisher, which triggers the creation
    /// of a new `AnyPublisher` under the hood.
    ///
    /// Once subscribed, the internal `Deferred` publisher calls
    /// `createPublisher()` to generate a new upstream publisher, which then
    /// passes elements or completion to the subscriber.
    ///
    /// - Parameter subscriber: The subscriber that will receive
    ///   elements and completion from this deferred publisher.
    public func receive<S>(
        subscriber: S
    ) where
        S: Subscriber,
        Failure == S.Failure,
        Output == S.Input
    {
        deferredPublisher.receive(subscriber: subscriber)
    }

    /// A closure that returns the erased publisher each time it's called.
    ///
    /// This property provides the underlying creation logic for new
    /// subscriptions. Each call to this closure yields a fresh
    /// `WrappedPublisher`.
    public var createPublisher: () -> WrappedPublisher {
        deferredPublisher.createPublisher
    }

    // MARK: - Type Erasure

    /// Returns `self`, as this publisher is already erased to an
    /// `AnyDeferredPublisher`.
    ///
    /// - Returns: `self`.
    public func eraseToAnyDeferredPublisher() -> AnyDeferredPublisher<Output, Failure> {
        self
    }

    // MARK: - Convenience Constructors

    /// Returns an `AnyDeferredPublisher` that publishes no elements and completes immediately.
    ///
    /// This is functionally equivalent to `Deferred { Empty() }`, and it is useful
    /// when you need a deferred, empty publisher for testing or stubbing.
    ///
    /// - Returns: An `AnyDeferredPublisher` that never publishes any elements and completes immediately.
    @_disfavoredOverload
    public static func empty() -> AnyDeferredPublisher<Output, Failure> {
        Deferred {
            Empty(outputType: Output.self, failureType: Failure.self)
        }
        .eraseToAnyDeferredPublisher()
    }

    /// Returns an `AnyDeferredPublisher` that immediately publishes a single value
    /// and then completes.
    ///
    /// This is functionally equivalent to `Deferred { Just(value) }` (with an
    /// appropriate failure type).
    ///
    /// - Parameter value: The single value that will be published.
    /// - Returns: An `AnyDeferredPublisher` that publishes `value` exactly once and then completes.
    @_disfavoredOverload
    public static func just(_ value: Output) -> AnyDeferredPublisher<Output, Failure> {
        Deferred {
            Just(value)
                .setFailureType(to: Failure.self)
        }
        .eraseToAnyDeferredPublisher()
    }

    /// Returns an `AnyDeferredPublisher` that immediately fails with the specified error.
    ///
    /// This is functionally equivalent to `Deferred { Fail(error) }`.
    ///
    /// - Parameter failure: The error that this publisher will immediately emit.
    /// - Returns: An `AnyDeferredPublisher` that fails with `failure` and never publishes any value.
    @_disfavoredOverload
    public static func fail(_ failure: Failure) -> AnyDeferredPublisher<Output, Failure> {
        Deferred {
            Fail(outputType: Output.self, failure: failure)
        }
        .eraseToAnyDeferredPublisher()
    }
}
