//
//  EventHandlingMainActor.swift
//  Copyright © 2025 Jason Fieldman.
//

import Combine

// MARK: - Publisher

public extension Publisher {
    /// Configures the publisher to handle subscription events on the main actor.
    ///
    /// - Parameter receiveSubscription: A closure that is called when the publisher receives a subscription.
    /// - Returns: A `Publishers.HandleEvents` instance with the specified subscription handler.
    func handleSubscriptionOnMainActor(
        _ receiveSubscription: (@MainActor @Sendable () -> Void)? = nil
    ) -> Publishers.HandleEvents<Self> {
        handleEvents(receiveSubscription: { _ in
            Task { @MainActor in
                receiveSubscription?()
            }
        })
    }

    /// Configures the publisher to handle value events on the main actor.
    ///
    /// - Parameter receiveValue: A closure that is called when the publisher receives a value.
    /// - Returns: A `Publishers.HandleEvents` instance with the specified value handler.
    func handleValueOnMainActor(
        _ receiveValue: (@MainActor @Sendable (Output) -> Void)? = nil
    ) -> Publishers.HandleEvents<Self> {
        handleEvents(receiveOutput: { value in
            Task { @MainActor in
                receiveValue?(value)
            }
        })
    }

    /// Configures the publisher to handle error events on the main actor.
    ///
    /// - Parameter receiveError: A closure that is called when the publisher receives an error.
    /// - Returns: A `Publishers.HandleEvents` instance with the specified error handler.
    func handleErrorOnMainActor(
        _ receiveError: (@MainActor @Sendable (Failure) -> Void)? = nil
    ) -> Publishers.HandleEvents<Self> {
        handleEvents(receiveCompletion: {
            switch $0 {
            case .finished:
                break
            case let .failure(error):
                Task { @MainActor in
                    receiveError?(error)
                }
            }
        })
    }

    /// Configures the publisher to handle finished events on the main actor.
    ///
    /// - Parameter receiveFinished: A closure that is called when the publisher finishes.
    /// - Returns: A `Publishers.HandleEvents` instance with the specified finished handler.
    func handleFinishedOnMainActor(
        _ receiveFinished: (@MainActor @Sendable () -> Void)? = nil
    ) -> Publishers.HandleEvents<Self> {
        handleEvents(receiveCompletion: {
            switch $0 {
            case .finished:
                Task { @MainActor in
                    receiveFinished?()
                }
            case .failure:
                break
            }
        })
    }

    /// Configures the publisher to handle completion events on the main actor.
    ///
    /// - Parameter receiveCompletion: A closure that is called when the publisher receives a completion event.
    /// - Returns: A `Publishers.HandleEvents` instance with the specified completion handler.
    func handleCompletionOnMainActor(
        _ receiveCompletion: (@MainActor @Sendable (Subscribers.Completion<Failure>) -> Void)? = nil
    ) -> Publishers.HandleEvents<Self> {
        handleEvents(receiveCompletion: { completion in
            Task { @MainActor in
                receiveCompletion?(completion)
            }
        })
    }

    /// Configures the publisher to handle cancellation events on the main actor.
    ///
    /// - Parameter receiveCancel: A closure that is called when the publisher receives a cancellation.
    /// - Returns: A `Publishers.HandleEvents` instance with the specified cancellation handler.
    func handleCancelOnMainActor(
        _ receiveCancel: (@MainActor @Sendable () -> Void)? = nil
    ) -> Publishers.HandleEvents<Self> {
        handleEvents(receiveCancel: {
            Task { @MainActor in
                receiveCancel?()
            }
        })
    }
}

// MARK: - DeferredPublisherProtocol

public extension DeferredPublisherProtocol {
    /// Configures the deferred publisher to handle subscription events on the main actor.
    ///
    /// - Parameter receiveSubscription: A closure that is called when the publisher receives a subscription.
    /// - Returns: A `Deferred<Publishers.HandleEvents<WrappedPublisher>>` instance with the specified subscription handler.
    @_disfavoredOverload
    func handleSubscriptionOnMainActor(
        _ receiveSubscription: (@MainActor @Sendable () -> Void)? = nil
    ) -> Deferred<Publishers.HandleEvents<WrappedPublisher>> where WrappedPublisher: Publisher {
        deferredLift { $0.handleSubscriptionOnMainActor(receiveSubscription) }
    }

    /// Configures the deferred publisher to handle value events on the main actor.
    ///
    /// - Parameter receiveValue: A closure that is called when the publisher receives a value.
    /// - Returns: A `Deferred<Publishers.HandleEvents<WrappedPublisher>>` instance with the specified value handler.
    @_disfavoredOverload
    func handleValueOnMainActor(
        _ receiveValue: (@MainActor @Sendable (Output) -> Void)? = nil
    ) -> Deferred<Publishers.HandleEvents<WrappedPublisher>> where WrappedPublisher: Publisher, Output == WrappedPublisher.Output {
        deferredLift { $0.handleValueOnMainActor(receiveValue) }
    }

    /// Configures the deferred publisher to handle error events on the main actor.
    ///
    /// - Parameter receiveError: A closure that is called when the publisher receives an error.
    /// - Returns: A `Deferred<Publishers.HandleEvents<WrappedPublisher>>` instance with the specified error handler.
    @_disfavoredOverload
    func handleErrorOnMainActor(
        _ receiveError: (@MainActor @Sendable (Failure) -> Void)? = nil
    ) -> Deferred<Publishers.HandleEvents<WrappedPublisher>> where WrappedPublisher: Publisher, Failure == WrappedPublisher.Failure {
        deferredLift { $0.handleErrorOnMainActor(receiveError) }
    }

    /// Configures the deferred publisher to handle finished events on the main actor.
    ///
    /// - Parameter receiveFinished: A closure that is called when the publisher finishes.
    /// - Returns: A `Deferred<Publishers.HandleEvents<WrappedPublisher>>` instance with the specified finished handler.
    @_disfavoredOverload
    func handleFinishedOnMainActor(
        _ receiveFinished: (@MainActor @Sendable () -> Void)? = nil
    ) -> Deferred<Publishers.HandleEvents<WrappedPublisher>> where WrappedPublisher: Publisher {
        deferredLift { $0.handleFinishedOnMainActor(receiveFinished) }
    }

    /// Configures the deferred publisher to handle completion events on the main actor.
    ///
    /// - Parameter receiveCompletion: A closure that is called when the publisher receives a completion event.
    /// - Returns: A `Deferred<Publishers.HandleEvents<WrappedPublisher>>` instance with the specified completion handler.
    @_disfavoredOverload
    func handleCompletionOnMainActor(
        _ receiveCompletion: (@MainActor @Sendable (Subscribers.Completion<Failure>) -> Void)? = nil
    ) -> Deferred<Publishers.HandleEvents<WrappedPublisher>> where WrappedPublisher: Publisher, Failure == WrappedPublisher.Failure {
        deferredLift { $0.handleCompletionOnMainActor(receiveCompletion) }
    }

    /// Configures the deferred publisher to handle cancellation events on the main actor.
    ///
    /// - Parameter receiveCancel: A closure that is called when the publisher receives a cancellation.
    /// - Returns: A `Deferred<Publishers.HandleEvents<WrappedPublisher>>` instance with the specified cancellation handler.
    @_disfavoredOverload
    func handleCancelOnMainActor(
        _ receiveCancel: (@MainActor @Sendable () -> Void)? = nil
    ) -> Deferred<Publishers.HandleEvents<WrappedPublisher>> where WrappedPublisher: Publisher {
        deferredLift { $0.handleCancelOnMainActor(receiveCancel) }
    }
}

// MARK: - DeferredFutureProtocol

public extension DeferredFutureProtocol {
    /// Configures the deferred future to handle subscription events on the main actor.
    ///
    /// - Parameter receiveSubscription: A closure that is called when the future receives a subscription.
    /// - Returns: A `DeferredFuture<Output, Failure>` instance with the specified subscription handler.
    @_disfavoredOverload
    func handleSubscriptionOnMainActor(
        _ receiveSubscription: (@MainActor @Sendable () -> Void)? = nil
    ) -> DeferredFuture<Output, Failure> {
        let outerAttempt = attemptToFulfill
        return DeferredFuture<Output, Failure> { innerPromise in
            Task { @MainActor in receiveSubscription?() }
            outerAttempt { outerResult in
                innerPromise(outerResult)
            }
        }
    }

    /// Configures the deferred future to handle value events on the main actor.
    ///
    /// - Parameter receiveOutput: A closure that is called when the future receives a value.
    /// - Returns: A `DeferredFuture<Output, Failure>` instance with the specified value handler.
    @_disfavoredOverload
    func handleValueOnMainActor(
        _ receiveOutput: (@MainActor @Sendable (Output) -> Void)? = nil
    ) -> DeferredFuture<Output, Failure> {
        futureLiftOutput { outerValue, innerPromise in
            Task { @MainActor in receiveOutput?(outerValue) }
            innerPromise(.success(outerValue))
        }
    }

    /// Configures the deferred future to handle error events on the main actor.
    ///
    /// - Parameter receiveError: A closure that is called when the future receives an error.
    /// - Returns: A `DeferredFuture<Output, Failure>` instance with the specified error handler.
    @_disfavoredOverload
    func handleErrorOnMainActor(
        _ receiveError: (@MainActor @Sendable (Failure) -> Void)? = nil
    ) -> DeferredFuture<Output, Failure> {
        futureLiftFailure { outerError, innerPromise in
            Task { @MainActor in receiveError?(outerError) }
            innerPromise(.failure(outerError))
        }
    }

    /// Configures the deferred future to handle finished events on the main actor.
    ///
    /// - Parameter receiveFinished: A closure that is called when the future finishes.
    /// - Returns: A `DeferredFuture<Output, Failure>` instance with the specified finished handler.
    @_disfavoredOverload
    func handleFinishedOnMainActor(
        _ receiveFinished: (@MainActor @Sendable () -> Void)? = nil
    ) -> DeferredFuture<Output, Failure> {
        futureLiftResult { outerResult, innerPromise in
            innerPromise(outerResult)
            Task { @MainActor in receiveFinished?() }
        }
    }

    /// Configures the deferred future to handle completion events on the main actor.
    ///
    /// - Parameter receiveCompletion: A closure that is called when the future receives a completion event.
    /// - Returns: A `DeferredFuture<Output, Failure>` instance with the specified completion handler.
    @_disfavoredOverload
    func handleCompletionOnMainActor(
        _ receiveCompletion: (@MainActor @Sendable (Result<Output, Failure>) -> Void)? = nil
    ) -> DeferredFuture<Output, Failure> {
        futureLiftResult { outerResult, innerPromise in
            innerPromise(outerResult)
            Task { @MainActor in receiveCompletion?(outerResult) }
        }
    }
}
