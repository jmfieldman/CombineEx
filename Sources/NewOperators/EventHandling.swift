//
//  EventHandling.swift
//  Copyright © 2025 Jason Fieldman.
//

import Combine

// MARK: - Publisher

public extension Publisher {
    /// Configures the publisher to handle subscription events.
    ///
    /// - Parameter receiveSubscription: A closure that is called when the publisher receives a subscription.
    /// - Returns: A `Publishers.HandleEvents` instance with the specified subscription handler.
    func handleSubscription(
        _ receiveSubscription: (() -> Void)? = nil
    ) -> Publishers.HandleEvents<Self> {
        handleEvents(receiveSubscription: { _ in receiveSubscription?() })
    }

    /// Configures the publisher to handle value events.
    ///
    /// - Parameter receiveValue: A closure that is called when the publisher receives a value.
    /// - Returns: A `Publishers.HandleEvents` instance with the specified value handler.
    func handleValue(
        _ receiveValue: ((Output) -> Void)? = nil
    ) -> Publishers.HandleEvents<Self> {
        handleEvents(receiveOutput: { receiveValue?($0) })
    }

    /// Configures the publisher to handle error events.
    ///
    /// - Parameter receiveError: A closure that is called when the publisher receives an error.
    /// - Returns: A `Publishers.HandleEvents` instance with the specified error handler.
    func handleError(
        _ receiveError: ((Failure) -> Void)? = nil
    ) -> Publishers.HandleEvents<Self> {
        handleEvents(receiveCompletion: {
            switch $0 {
            case .finished:
                break
            case let .failure(error):
                receiveError?(error)
            }
        })
    }

    /// Configures the publisher to handle finished events.
    ///
    /// - Parameter receiveFinished: A closure that is called when the publisher finishes.
    /// - Returns: A `Publishers.HandleEvents` instance with the specified finished handler.
    func handleFinished(
        _ receiveFinished: (() -> Void)? = nil
    ) -> Publishers.HandleEvents<Self> {
        handleEvents(receiveCompletion: {
            switch $0 {
            case .finished:
                receiveFinished?()
            case .failure:
                break
            }
        })
    }

    /// Configures the publisher to handle completion events.
    ///
    /// - Parameter receiveCompletion: A closure that is called when the publisher receives a completion event.
    /// - Returns: A `Publishers.HandleEvents` instance with the specified completion handler.
    func handleCompletion(
        _ receiveCompletion: ((Subscribers.Completion<Failure>) -> Void)? = nil
    ) -> Publishers.HandleEvents<Self> {
        handleEvents(receiveCompletion: { receiveCompletion?($0) })
    }

    /// Configures the publisher to handle cancellation events.
    ///
    /// - Parameter receiveCancel: A closure that is called when the publisher receives a cancellation.
    /// - Returns: A `Publishers.HandleEvents` instance with the specified cancellation handler.
    func handleCancel(
        _ receiveCancel: (() -> Void)? = nil
    ) -> Publishers.HandleEvents<Self> {
        handleEvents(receiveCancel: { receiveCancel?() })
    }
}

// MARK: - DeferredPublisherProtocol

public extension DeferredPublisherProtocol {
    /// Configures the deferred publisher to handle subscription events.
    ///
    /// - Parameter receiveSubscription: A closure that is called when the publisher receives a subscription.
    /// - Returns: A `Deferred<Publishers.HandleEvents<WrappedPublisher>>` instance with the specified subscription handler.
    @_disfavoredOverload
    func handleSubscription(
        _ receiveSubscription: (() -> Void)? = nil
    ) -> Deferred<Publishers.HandleEvents<WrappedPublisher>> where WrappedPublisher: Publisher {
        deferredLift { $0.handleSubscription(receiveSubscription) }
    }

    /// Configures the deferred publisher to handle value events.
    ///
    /// - Parameter receiveValue: A closure that is called when the publisher receives a value.
    /// - Returns: A `Deferred<Publishers.HandleEvents<WrappedPublisher>>` instance with the specified value handler.
    @_disfavoredOverload
    func handleValue(
        _ receiveValue: ((Output) -> Void)? = nil
    ) -> Deferred<Publishers.HandleEvents<WrappedPublisher>> where WrappedPublisher: Publisher, Output == WrappedPublisher.Output {
        deferredLift { $0.handleValue(receiveValue) }
    }

    /// Configures the deferred publisher to handle error events.
    ///
    /// - Parameter receiveError: A closure that is called when the publisher receives an error.
    /// - Returns: A `Deferred<Publishers.HandleEvents<WrappedPublisher>>` instance with the specified error handler.
    @_disfavoredOverload
    func handleError(
        _ receiveError: ((Failure) -> Void)? = nil
    ) -> Deferred<Publishers.HandleEvents<WrappedPublisher>> where WrappedPublisher: Publisher, Failure == WrappedPublisher.Failure {
        deferredLift { $0.handleError(receiveError) }
    }

    /// Configures the deferred publisher to handle finished events.
    ///
    /// - Parameter receiveFinished: A closure that is called when the publisher finishes.
    /// - Returns: A `Deferred<Publishers.HandleEvents<WrappedPublisher>>` instance with the specified finished handler.
    @_disfavoredOverload
    func handleFinished(
        _ receiveFinished: (() -> Void)? = nil
    ) -> Deferred<Publishers.HandleEvents<WrappedPublisher>> where WrappedPublisher: Publisher {
        deferredLift { $0.handleFinished(receiveFinished) }
    }

    /// Configures the deferred publisher to handle completion events.
    ///
    /// - Parameter receiveCompletion: A closure that is called when the publisher receives a completion event.
    /// - Returns: A `Deferred<Publishers.HandleEvents<WrappedPublisher>>` instance with the specified completion handler.
    @_disfavoredOverload
    func handleCompletion(
        _ receiveCompletion: ((Subscribers.Completion<Failure>) -> Void)? = nil
    ) -> Deferred<Publishers.HandleEvents<WrappedPublisher>> where WrappedPublisher: Publisher, Failure == WrappedPublisher.Failure {
        deferredLift { $0.handleCompletion(receiveCompletion) }
    }

    /// Configures the deferred publisher to handle cancellation events.
    ///
    /// - Parameter receiveCancel: A closure that is called when the publisher receives a cancellation.
    /// - Returns: A `Deferred<Publishers.HandleEvents<WrappedPublisher>>` instance with the specified cancellation handler.
    @_disfavoredOverload
    func handleCancel(
        _ receiveCancel: (() -> Void)? = nil
    ) -> Deferred<Publishers.HandleEvents<WrappedPublisher>> where WrappedPublisher: Publisher {
        deferredLift { $0.handleCancel(receiveCancel) }
    }
}

// MARK: - DeferredFutureProtocol

public extension DeferredFutureProtocol {
    /// Configures the deferred future to handle subscription events.
    ///
    /// - Parameter receiveSubscription: A closure that is called when the future receives a subscription.
    /// - Returns: A `DeferredFuture<Output, Failure>` instance with the specified subscription handler.
    @_disfavoredOverload
    func handleSubscription(
        _ receiveSubscription: (() -> Void)? = nil
    ) -> DeferredFuture<Output, Failure> {
        let outerAttempt = attemptToFulfill
        return DeferredFuture<Output, Failure> { innerPromise in
            receiveSubscription?()
            outerAttempt { outerResult in
                innerPromise(outerResult)
            }
        }
    }

    /// Configures the deferred future to handle value events.
    ///
    /// - Parameter receiveOutput: A closure that is called when the future receives a value.
    /// - Returns: A `DeferredFuture<Output, Failure>` instance with the specified value handler.
    @_disfavoredOverload
    func handleValue(
        _ receiveOutput: ((Output) -> Void)? = nil
    ) -> DeferredFuture<Output, Failure> {
        futureLiftOutput { outerValue, innerPromise in
            receiveOutput?(outerValue)
            innerPromise(.success(outerValue))
        }
    }

    /// Configures the deferred future to handle error events.
    ///
    /// - Parameter receiveError: A closure that is called when the future receives an error.
    /// - Returns: A `DeferredFuture<Output, Failure>` instance with the specified error handler.
    @_disfavoredOverload
    func handleError(
        _ receiveError: ((Failure) -> Void)? = nil
    ) -> DeferredFuture<Output, Failure> {
        futureLiftFailure { outerError, innerPromise in
            receiveError?(outerError)
            innerPromise(.failure(outerError))
        }
    }

    /// Configures the deferred future to handle finished events.
    ///
    /// - Parameter receiveFinished: A closure that is called when the future finishes.
    /// - Returns: A `DeferredFuture<Output, Failure>` instance with the specified finished handler.
    @_disfavoredOverload
    func handleFinished(
        _ receiveFinished: (() -> Void)? = nil
    ) -> DeferredFuture<Output, Failure> {
        futureLiftResult { outerResult, innerPromise in
            innerPromise(outerResult)
            receiveFinished?()
        }
    }

    /// Configures the deferred future to handle completion events.
    ///
    /// - Parameter receiveCompletion: A closure that is called when the future receives a completion event.
    /// - Returns: A `DeferredFuture<Output, Failure>` instance with the specified completion handler.
    @_disfavoredOverload
    func handleCompletion(
        _ receiveCompletion: ((Result<Output, Failure>) -> Void)? = nil
    ) -> DeferredFuture<Output, Failure> {
        futureLiftResult { outerResult, innerPromise in
            innerPromise(outerResult)
            receiveCompletion?(outerResult)
        }
    }
}
