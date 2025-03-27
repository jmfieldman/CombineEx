//
//  Custom.swift
//  Copyright © 2025 Jason Fieldman.
//

import Combine
import Foundation
import os

public extension Publishers {
    protocol CustomSubscriptionHandler<Output, Failure> {
        associatedtype Output
        associatedtype Failure: Error

        func sendValue(_ value: Output)
        func sendCompletion(_ completion: Subscribers.Completion<Failure>)

        var cancelled: Property<Bool> { get }
        var demand: Property<Subscribers.Demand> { get }
    }

    struct Custom<Output, Failure: Error>: Publisher {
        let subscriptionHandler: (any CustomSubscriptionHandler<Output, Failure>) -> Void

        public init(
            _ subscriptionHandler: @escaping (any CustomSubscriptionHandler<Output, Failure>) -> Void
        ) {
            self.subscriptionHandler = subscriptionHandler
        }

        public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
            let subscription = CustomSubscription(
                subscriber: subscriber
            )
            subscriber.receive(subscription: subscription)
            subscriptionHandler(subscription)
        }

        public final class CustomSubscription<S: Subscriber>: Subscription, CustomSubscriptionHandler where S.Input == Output, S.Failure == Failure {
            private var subscriber: S?

            private let mutableCancelled: MutableProperty<Bool> = .init(false)
            private let mutableDemand: MutableProperty<Subscribers.Demand> = .init(.unlimited)

            public private(set) lazy var cancelled = Property(mutableCancelled)
            public private(set) lazy var demand = Property(mutableDemand)

            init(
                subscriber: S
            ) {
                self.subscriber = subscriber
            }

            public func request(_ demand: Subscribers.Demand) {
                mutableDemand.value = demand
            }

            public func cancel() {
                subscriber = nil
                mutableCancelled.value = true
            }

            public func sendValue(_ value: Output) {
                guard let subscriber else { return }
                mutableDemand.value = subscriber.receive(value)
            }

            public func sendCompletion(_ completion: Subscribers.Completion<Failure>) {
                guard let subscriber else { return }
                subscriber.receive(completion: completion)
            }
        }
    }
}

public struct DeferredCustom<Output, Failure: Error>: DeferredPublisherProtocol {
    private let subscriptionHandler: (any Publishers.CustomSubscriptionHandler<Output, Failure>) -> Void
    public let createPublisher: () -> any Publisher<Output, Failure>

    public init(
        subscriptionHandler: @escaping (any Publishers.CustomSubscriptionHandler<Output, Failure>) -> Void
    ) {
        self.subscriptionHandler = subscriptionHandler
        self.createPublisher = {
            Publishers.Custom(subscriptionHandler)
        }
    }

    public func receive<S>(subscriber: S) where S: Subscriber, Failure == S.Failure, Output == S.Input {
        createPublisher().receive(subscriber: subscriber)
    }

    /// Erases this DeferredCustom to an `AnyDeferredPublisher`,
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
