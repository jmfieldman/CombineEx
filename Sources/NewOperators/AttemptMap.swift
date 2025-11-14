//
//  AttemptMap.swift
//  Copyright © 2024 Jason Fieldman.
//

import Combine

public extension Publishers {
    /// A publisher that applies a transformation to the elements emitted by an upstream publisher,
    /// allowing for failure handling through `Result`.
    struct AttemptMap<Upstream: Publisher, NewOutput>: Publisher {
        public typealias Output = NewOutput
        public typealias Failure = Upstream.Failure

        private let upstream: Upstream
        private let transform: @Sendable (Upstream.Output) -> Result<NewOutput, Failure>

        /// Creates a new `AttemptMap` publisher.
        ///
        /// - Parameters:
        ///   - upstream: The upstream publisher from which to receive values.
        ///   - transform: A closure that takes an element from the upstream publisher and returns
        ///                a `Result` containing either the transformed value or a failure.
        public init(upstream: Upstream, transform: @escaping @Sendable (Upstream.Output) -> Result<NewOutput, Failure>) {
            self.upstream = upstream
            self.transform = transform
        }

        /// Subscribes the given subscriber to this publisher.
        ///
        /// - Parameter subscriber: The subscriber to attach to this publisher.
        public func receive<S: Subscriber>(subscriber: S) where S.Input == NewOutput, S.Failure == Failure {
            let subscription = AttemptMapSubscription(transform: transform, subscriber: subscriber)
            upstream.subscribe(subscription)
        }
    }
}

private extension Publishers.AttemptMap {
    private final class AttemptMapSubscription<S: Subscriber>: Subscriber where S.Input == NewOutput, S.Failure == Upstream.Failure {
        typealias Input = Upstream.Output
        typealias Failure = Upstream.Failure

        private let transform: (Upstream.Output) -> Result<NewOutput, Upstream.Failure>
        private var subscriber: S?

        init(transform: @escaping @Sendable (Upstream.Output) -> Result<NewOutput, Upstream.Failure>, subscriber: S) {
            self.transform = transform
            self.subscriber = subscriber
        }

        /// Receives a subscription from the upstream publisher.
        ///
        /// - Parameter subscription: A new subscription to manage elements and completion.
        func receive(subscription: Subscription) {
            subscriber?.receive(subscription: subscription)
        }

        /// Receives a completion event from the upstream publisher.
        ///
        /// - Parameter completion: The completion event sent by the upstream publisher.
        func receive(completion: Subscribers.Completion<Upstream.Failure>) {
            subscriber?.receive(completion: completion)
            subscriber = nil
        }

        /// Receives a value from the upstream publisher.
        ///
        /// - Parameter input: The received value to be transformed and sent to the downstream subscriber.
        /// - Returns: A demand indicating whether more values are needed or if the subscription should be canceled
        func receive(_ input: Upstream.Output) -> Subscribers.Demand {
            switch transform(input) {
            case let .success(value):
                _ = subscriber?.receive(value)
                return .unlimited
            case let .failure(error):
                subscriber?.receive(completion: .failure(error))
                subscriber = nil
                return .none
            }
        }
    }
}

public extension Publisher {
    /// Maps each element of the publisher using a transformation that returns a `Result` type.
    ///
    /// - Parameter transform: A closure that takes an element and returns a `Result` containing the transformed value or a failure.
    /// - Returns: A `Publishers.AttemptMap` instance that applies the transformation to each element.
    func attemptMap<NewOutput>(
        _ transform: @escaping @Sendable (Output) -> Result<NewOutput, Failure>
    ) -> Publishers.AttemptMap<Self, NewOutput> {
        Publishers.AttemptMap(upstream: self, transform: transform)
    }
}

public extension DeferredPublisherProtocol {
    /// Maps each element of the deferred publisher using a transformation that returns a `Result` type.
    ///
    /// - Parameter transform: A closure that takes an element and returns a `Result` containing the transformed value or a failure.
    /// - Returns: A `Deferred<Publishers.AttemptMap<WrappedPublisher, NewOutput>>` instance that applies the transformation to each element.
    @_disfavoredOverload
    func attemptMap<NewOutput>(
        _ transform: @escaping @Sendable (WrappedPublisher.Output) -> Result<NewOutput, Failure>
    ) -> Deferred<Publishers.AttemptMap<WrappedPublisher, NewOutput>> where WrappedPublisher.Failure == Failure {
        deferredLift { $0.attemptMap(transform) }
    }
}

public extension DeferredFutureProtocol {
    /// Maps the output of the deferred future using a transformation that returns a `Result` type.
    ///
    /// - Parameter transform: A closure that takes an output and returns a `Result` containing the transformed value or a failure.
    /// - Returns: A `DeferredFuture<NewOutput, Failure>` instance that applies the transformation to the output.
    @_disfavoredOverload
    func attemptMap<NewOutput>(
        _ transform: @escaping @Sendable (Output) -> Result<NewOutput, Failure>
    ) -> DeferredFuture<NewOutput, Failure> {
        futureLiftOutput { outerResult, innerPromise in
            innerPromise(transform(outerResult))
        }
    }
}
