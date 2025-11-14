//
//  Custom.swift
//  Copyright © 2025 Jason Fieldman.
//

import Combine
import Foundation
import os

public extension Publishers {
    /// A protocol for handling subscriptions with custom logic.
    ///
    /// - associatedtype Output: The type of values produced by the publisher.
    /// - associatedtype Failure: The type of error that can occur, conforming to `Error`.
    protocol CustomSubscriptionHandler<Output, Failure> {
        associatedtype Output
        associatedtype Failure: Error

        /// Sends a value to the subscriber.
        ///
        /// - Parameter value: The value to send.
        func sendValue(_ value: Output)

        /// Sends a completion event to the subscriber.
        ///
        /// - Parameter completion: The completion event to send.
        func sendCompletion(_ completion: Subscribers.Completion<Failure>)

        /// A property indicating whether the subscription has been cancelled.
        var cancelled: Property<Bool> { get }

        /// A property representing the current demand from the subscriber.
        var demand: Property<Subscribers.Demand> { get }
    }

    /// A custom publisher that uses a subscription handler for sending values and completions.
    ///
    /// - Parameters:
    ///   - Output: The type of values produced by the publisher.
    ///   - Failure: The type of error that can occur, conforming to `Error`.
    struct Custom<Output, Failure: Error>: Publisher {
        /// The handler that manages the subscription logic.
        let subscriptionHandler: (any CustomSubscriptionHandler<Output, Failure>) -> Void

        /// Initializes the custom publisher with a subscription handler.
        ///
        /// - Parameter subscriptionHandler: A closure that handles the subscription logic.
        public init(
            _ subscriptionHandler: @escaping @Sendable (any CustomSubscriptionHandler<Output, Failure>) -> Void
        ) {
            self.subscriptionHandler = subscriptionHandler
        }

        /// Attaches the specified subscriber to this publisher.
        ///
        /// - Parameter subscriber: The subscriber to attach.
        public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
            let subscription = CustomSubscription(
                subscriber: subscriber
            )
            subscriber.receive(subscription: subscription)
            subscriptionHandler(subscription)
        }

        /// A custom subscription that handles the logic for sending values and completions to a subscriber.
        private final class CustomSubscription<S: Subscriber>: Subscription, CustomSubscriptionHandler where S.Input == Output, S.Failure == Failure {
            private var subscriber: S?

            private let mutableCancelled: MutableProperty<Bool> = .init(false)
            private let mutableDemand: MutableProperty<Subscribers.Demand> = .init(.unlimited)

            /// A property indicating whether the subscription has been cancelled.
            public private(set) lazy var cancelled = Property(mutableCancelled)
            /// A property representing the current demand from the subscriber.
            public private(set) lazy var demand = Property(mutableDemand)

            /// Initializes the custom subscription with a subscriber.
            ///
            /// - Parameter subscriber: The subscriber to attach.
            init(
                subscriber: S
            ) {
                self.subscriber = subscriber
            }

            /// Requests a specific demand from the publisher.
            ///
            /// - Parameter demand: The demand to request.
            public func request(_ demand: Subscribers.Demand) {
                mutableDemand.value = demand
            }

            /// Cancels the subscription.
            public func cancel() {
                subscriber = nil
                mutableCancelled.value = true
            }

            /// Sends a value to the subscriber.
            ///
            /// - Parameter value: The value to send.
            public func sendValue(_ value: Output) {
                guard let subscriber else { return }
                mutableDemand.value = subscriber.receive(value)
            }

            /// Sends a completion event to the subscriber.
            ///
            /// - Parameter completion: The completion event to send.
            public func sendCompletion(_ completion: Subscribers.Completion<Failure>) {
                guard let subscriber else { return }
                subscriber.receive(completion: completion)
            }
        }
    }
}

/// A deferred publisher that uses a subscription handler for sending values and completions.
///
/// - Parameters:
///   - Output: The type of values produced by the publisher.
///   - Failure: The type of error that can occur, conforming to `Error`.
public struct DeferredCustom<Output, Failure: Error>: DeferredPublisherProtocol {
    private let subscriptionHandler: @Sendable (any Publishers.CustomSubscriptionHandler<Output, Failure>) -> Void
    public let createPublisher: () -> any Publisher<Output, Failure>

    /// Initializes the deferred custom publisher with a subscription handler.
    ///
    /// - Parameter subscriptionHandler: A closure that handles the subscription logic.
    public init(
        subscriptionHandler: @escaping @Sendable (any Publishers.CustomSubscriptionHandler<Output, Failure>) -> Void
    ) {
        self.subscriptionHandler = subscriptionHandler
        self.createPublisher = {
            Publishers.Custom(subscriptionHandler)
        }
    }

    /// Attaches the specified subscriber to this publisher.
    ///
    /// - Parameter subscriber: The subscriber to attach.
    public func receive<S>(subscriber: S) where S: Subscriber, Failure == S.Failure, Output == S.Input {
        createPublisher().receive(subscriber: subscriber)
    }

    /// Erases this `DeferredCustom` to an `AnyDeferredPublisher`,
    /// hiding its concrete type.
    ///
    /// Use this method when you need to return a type-erased version of a
    /// deferred publisher, such as from a public API or library module.
    ///
    /// - Returns: An `AnyDeferredPublisher` wrapping this `Deferred` publisher.
    public func eraseToAnyDeferredPublisher() -> AnyDeferredPublisher<Output, Failure> {
        Deferred { Publishers.Custom(subscriptionHandler) }
            .eraseToAnyDeferredPublisher()
    }
}
