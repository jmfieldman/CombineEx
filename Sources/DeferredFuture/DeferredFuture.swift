//
//  DeferredFuture.swift
//  Copyright © 2024 Jason Fieldman.
//

import Combine

// MARK: - DeferredFutureProtocol

/// A protocol representing a deferred future, extending `Publisher`.
///
/// This protocol encapsulates the concept of deferring the creation of an
/// underlying `Future` until there is a subscription, at which time the
/// future's `attemptToFulfill` closure is called. Conforming types
/// must define how they publish values and errors, and how to erase
/// themselves to an `AnyDeferredFuture` or `AnyDeferredPublisher`.
public protocol DeferredFutureProtocol<Output, Failure>: Publisher {
    /// A convenience type alias for the underlying `Future`.
    associatedtype WrappedFuture = Future<Output, Failure>

    /// The closure that attempts to fulfill the `Future`'s promise.
    ///
    /// This closure is typically called once a subscriber requests values,
    /// allowing you to provide the eventual result (`.success`) or error
    /// (`.failure`).
    var attemptToFulfill: (@escaping Future<Output, Failure>.Promise) -> Void { get }

    /// Erases the concrete deferred future type, returning an
    /// `AnyDeferredFuture` that hides the implementation details.
    ///
    /// This is useful for returning a type-erased deferred future
    /// from a library or API.
    func eraseToAnyDeferredFuture() -> AnyDeferredFuture<Output, Failure>

    /// Erases the concrete publisher type, returning an
    /// `AnyDeferredPublisher` that hides the implementation details.
    ///
    /// This is useful for returning a type-erased deferred publisher
    /// from a library or API.
    func eraseToAnyDeferredPublisher() -> AnyDeferredPublisher<Output, Failure>
}

// MARK: DeferredFuture

/// A publisher that defers the creation of a `Future` until
/// subscription time, allowing you to asynchronously fulfill a promise
/// at a later point in time.
///
/// `DeferredFuture` is especially useful when you need to create an
/// asynchronous operation “just in time” for a subscriber. It wraps a
/// Combine `Future` inside a `Deferred` operator. Once subscribed,
/// the `attemptToFulfill` closure is executed to fulfill (or fail)
/// the promise.
///
/// Example usage:
///
///     let deferredFetch = DeferredFuture<String, MyError> { promise in
///         // Perform some asynchronous work...
///         fetchData { result in
///             switch result {
///             case .success(let responseString):
///                 promise(.success(responseString))
///             case .failure(let error):
///                 promise(.failure(error))
///             }
///        }
///     }
///
///     // Deferred work starts when `deferredFetch` is subscribed to.
///     let cancellable = deferredFetch
///         .sink(
///             receiveCompletion: { print("Completion: \($0)") },
///             receiveValue: { print("Value: \($0)") }
///         )
public struct DeferredFuture<Output, Failure: Error>: DeferredFutureProtocol, Publisher {
    /// A convenience type alias for the underlying `Future` that
    /// delivers `Output` or fails with `Failure`.
    public typealias WrappedFuture = Future<Output, Failure>

    /// The closure that attempts to fulfill the `Future`'s promise.
    /// This closure is executed once a subscriber requests values.
    ///
    /// - Parameter promise: A closure that you must call with either
    ///   `.success(Output)` or `.failure(Failure)` to resolve the future.
    public let attemptToFulfill: (@escaping WrappedFuture.Promise) -> Void

    /// The internal `Deferred` that wraps the `Future`. The `Future`
    /// is only created when this `Deferred` is subscribed to.
    let wrappedDeferredFuture: Deferred<WrappedFuture>

    /// Creates a new deferred future using a closure that attempts to
    /// fulfill the promise when a subscriber demands values.
    ///
    /// - Parameter attemptToFulfill: A closure that takes a promise
    ///   you must call to complete the future. This closure is deferred
    ///   until subscription time.
    public init(
        _ attemptToFulfill: @escaping (@escaping WrappedFuture.Promise) -> Void
    ) {
        self.attemptToFulfill = attemptToFulfill
        self.wrappedDeferredFuture = Deferred {
            Future(attemptToFulfill)
        }
    }

    /// Create a `DeferredFuture` that attempts to execute an async function
    /// and returns its value (or thrown error as a failure).
    ///
    /// - Parameter task: An async function whose return value is emitted as
    ///   the value of the future, or whose thrown error is emitted as the
    ///   failure.
    public static func withTask(_ task: @escaping () async throws(Failure) -> Output) -> Self {
        .init { promise in
            Task {
                do throws(Failure) {
                    try await promise(.success(task()))
                } catch {
                    promise(.failure(error))
                }
            }
        }
    }

    // MARK: - Publisher Conformance

    /// Subscribes the specified subscriber to this publisher.
    ///
    /// Once subscribed, `DeferredFuture` will create its underlying
    /// `Future` and call `attemptToFulfill` to begin the asynchronous
    /// operation.
    ///
    /// - Parameter subscriber: The subscriber to register, which will
    ///   receive elements and completion.
    public func receive<S>(
        subscriber: S
    ) where
        S: Subscriber,
        Failure == S.Failure,
        Output == S.Input
    {
        wrappedDeferredFuture.receive(subscriber: subscriber)
    }

    // MARK: - DeferredFutureProtocol Conformance

    /// Exposes the factory closure for creating the underlying
    /// `Future`. You typically do not need to call this directly.
    ///
    /// - Returns: A closure that creates a new `Future` when called.
    public var createPublisher: () -> WrappedFuture {
        wrappedDeferredFuture.createPublisher
    }

    // MARK: - Type Erasure

    /// Erases this publisher to an `AnyPublisher`.
    ///
    /// Use this to hide the specific publisher type from downstream
    /// subscribers when publishing from an API or library.
    ///
    /// - Returns: An `AnyPublisher` wrapping this deferred future.
    public func eraseToAnyPublisher() -> AnyPublisher<Output, Failure> {
        AnyPublisher(self)
    }

    /// Erases this publisher to an `AnyDeferredPublisher`.
    ///
    /// This is useful for abstracting away the concrete `Deferred<Future>`
    /// type, providing a more general deferred publisher interface.
    ///
    /// - Returns: An `AnyDeferredPublisher` wrapping this deferred future.
    public func eraseToAnyDeferredPublisher() -> AnyDeferredPublisher<Output, Failure> {
        AnyDeferredPublisher(wrappedDeferredFuture)
    }

    /// Erases this deferred future to an `AnyDeferredFuture`.
    ///
    /// This is helpful for returning a type-erased deferred future
    /// from an API or library without exposing the concrete type.
    ///
    /// - Returns: An `AnyDeferredFuture` wrapping this deferred future.
    public func eraseToAnyDeferredFuture() -> AnyDeferredFuture<Output, Failure> {
        AnyDeferredFuture(self)
    }
}

// MARK: - DeferredFuture Extension

public extension DeferredFuture {
    /// Creates a deferred future that immediately succeeds with a given value.
    ///
    /// This is convenient when you want a future that yields a known,
    /// precomputed value without needing any asynchronous logic.
    ///
    /// - Parameter value: The value to succeed with.
    /// - Returns: A new `DeferredFuture` that immediately succeeds with `value`.
    static func just(_ value: Output) -> DeferredFuture<Output, Failure> {
        DeferredFuture { $0(.success(value)) }
    }

    /// Creates a deferred future that immediately fails with a given error.
    ///
    /// This is convenient when you want a future that immediately completes
    /// with an error, for example, for testing or to unify asynchronous
    /// and synchronous error paths.
    ///
    /// - Parameter error: The error to fail with.
    /// - Returns: A new `DeferredFuture` that immediately fails with `error`.
    static func fail(_ error: Failure) -> DeferredFuture<Output, Failure> {
        DeferredFuture { $0(.failure(error)) }
    }
}

// MARK: - AnyDeferredFuture

/// A type-erased `DeferredFuture` that hides the specific underlying
/// deferred future implementation.
///
/// `AnyDeferredFuture` can wrap any concrete `DeferredFuture` instance
/// and expose it only through the `DeferredFutureProtocol`.
///
/// Use this type when you need to return a deferred future without
/// exposing its actual type in your API, allowing for flexibility
/// in future implementation changes.
public class AnyDeferredFuture<Output, Failure: Error>: DeferredFutureProtocol {
    /// A convenience alias for the concrete `DeferredFuture` type
    /// wrapped by this class.
    public typealias WrappedDeferredFuture = DeferredFuture<Output, Failure>

    /// The concrete `DeferredFuture` being type-erased.
    private let wrappedDeferredFuture: DeferredFuture<Output, Failure>

    /// Creates a new type-erased deferred future by wrapping
    /// the provided concrete `DeferredFuture`.
    ///
    /// - Parameter deferredFuture: The `DeferredFuture` to wrap.
    public init(
        _ deferredFuture: DeferredFuture<Output, Failure>
    ) {
        self.wrappedDeferredFuture = deferredFuture
    }

    /// A convenience initializer allowing you to create an
    /// `AnyDeferredFuture` from a closure that attempts to fulfill
    /// the wrapped future’s promise.
    ///
    /// - Parameter attemptToFulfill: A closure that is deferred
    ///   until subscription time, used to complete or fail the future.
    public convenience init(
        attemptToFulfill: @escaping (@escaping WrappedFuture.Promise) -> Void
    ) {
        self.init(DeferredFuture(attemptToFulfill))
    }

    // MARK: - Publisher Conformance

    /// Subscribes the given subscriber to this deferred future.
    ///
    /// Once subscribed, the wrapped `DeferredFuture` begins its
    /// asynchronous operation by calling the `attemptToFulfill`
    /// closure.
    ///
    /// - Parameter subscriber: The subscriber requesting values
    ///   from this publisher.
    public func receive<S>(
        subscriber: S
    ) where
        S: Subscriber,
        Failure == S.Failure,
        Output == S.Input
    {
        wrappedDeferredFuture.receive(subscriber: subscriber)
    }

    /// The closure that attempts to fulfill the underlying future’s promise.
    ///
    /// This simply forwards to the wrapped deferred future.
    public var attemptToFulfill: (@escaping Future<Output, Failure>.Promise) -> Void {
        wrappedDeferredFuture.attemptToFulfill
    }

    // MARK: - Type Erasure

    /// Returns `self`, as this instance is already type-erased.
    ///
    /// - Returns: This `AnyDeferredFuture`.
    public func eraseToAnyDeferredFuture() -> AnyDeferredFuture<Output, Failure> {
        self
    }

    /// Erases the "Future" nature of this class to a generic deferred publisher
    /// type, returning an `AnyDeferredPublisher`.
    ///
    /// - Returns: A type-erased deferred publisher for this deferred future.
    public func eraseToAnyDeferredPublisher() -> AnyDeferredPublisher<Output, Failure> {
        let wrapped = wrappedDeferredFuture
        return AnyDeferredPublisher(createPublisher: {
            wrapped.createPublisher().eraseToAnyPublisher()
        })
    }
}
