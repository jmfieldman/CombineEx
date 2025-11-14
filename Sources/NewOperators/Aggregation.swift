//
//  Aggregation.swift
//  Copyright © 2024 Jason Fieldman.
//

import Combine
import Foundation
import os

// MARK: - AggregatePublisherAggregator

/// A protocol for aggregating publishers.
public protocol AggregatePublisherAggregator<AggregateFailure> {
    associatedtype AggregateFailure: Error

    /// Adds a publisher to be aggregated.
    ///
    /// - Parameter publisher: The publisher to add.
    func add(_ publisher: some Publisher<some Any, AggregateFailure>)
}

public extension Publishers {
    struct Aggregate<Output, Failure: Error>: Publisher {
        /// The strategy used to combine the values from sub-publishers.
        public enum Strategy {
            /// Emits an event whenever any of the source publishers emit a value, containing the
            /// most recent value of each publisher.
            case combineLatest

            /// Emits an i-th event when all of the source publishers have emitted at least i values.
            case zip
        }

        private let strategy: Strategy
        private let componentBuilder: @Sendable (any AggregatePublisherAggregator<Failure>) -> Void
        private let aggregationBlock: @Sendable ([Any]) -> Output

        /// Creates a new `Aggregate` publisher.
        ///
        /// - Parameters:
        ///   - strategy: The strategy used to combine the values from sub-publishers.
        ///   - componentBuilder: A closure that is called with an aggregator object, allowing you to add publishers.
        ///   - aggregationBlock: A block that takes an array of values and returns a single output value.
        public init(
            strategy: Strategy,
            componentBuilder: @escaping @Sendable (any AggregatePublisherAggregator<Failure>) -> Void,
            aggregationBlock: @escaping @Sendable ([Any]) -> Output
        ) {
            self.strategy = strategy
            self.componentBuilder = componentBuilder
            self.aggregationBlock = aggregationBlock
        }

        /// Connects the specified subscriber to this publisher.
        ///
        /// - Parameter subscriber: The subscriber to attach to this publisher.
        public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
            let subscription = AggregateSubscription(
                subscriber: subscriber,
                strategy: strategy,
                componentBuilder: componentBuilder,
                aggregationBlock: aggregationBlock
            )
            subscriber.receive(subscription: subscription)
            subscription.start()
        }

        /// A private class that manages the subscription and aggregation logic.
        private final class AggregateSubscription<S: Subscriber>: Subscription, AggregatePublisherAggregator where S.Input == Output, S.Failure == Failure {
            public typealias AggregateFailure = Failure
            public typealias Input = Output

            private var subscriber: S?
            private var isCancelled = false
            private var demand: Subscribers.Demand = .unlimited

            private let strategy: Strategy
            private let componentBuilder: (AggregateSubscription) -> Void
            private let aggregationBlock: ([Any]) -> Output

            private let lock = OSAllocatedUnfairLock()
            private var startBlocks: [() -> Void] = []
            private var values: ContiguousArray<[Any]> = []
            private var finished: ContiguousArray<Bool> = []
            private var countWithValues = 0
            private var cancellables: [AnyCancellable] = []

            /// Initializes a new `AggregateSubscription`.
            ///
            /// - Parameters:
            ///   - subscriber: The subscriber to attach to this subscription.
            ///   - strategy: The strategy used to combine the values from sub-publishers.
            ///   - componentBuilder: A closure that is called with an aggregator object, allowing you to add publishers.
            ///   - aggregationBlock: A block that takes an array of values and returns a single output value.
            init(
                subscriber: S,
                strategy: Strategy,
                componentBuilder: @escaping @Sendable (AggregateSubscription) -> Void,
                aggregationBlock: @escaping @Sendable ([Any]) -> Output
            ) {
                self.subscriber = subscriber
                self.strategy = strategy
                self.componentBuilder = componentBuilder
                self.aggregationBlock = aggregationBlock

                componentBuilder(self)
                self.values = ContiguousArray(repeating: [], count: startBlocks.count)
                self.finished = ContiguousArray(repeating: false, count: startBlocks.count)
            }

            /// Request a specified number of values from the publisher.
            ///
            /// - Parameter demand: The amount of values requested.
            public func request(_ demand: Subscribers.Demand) {
                lock.withLock {
                    self.demand = demand
                }
            }

            /// Cancel the subscription, stopping delivery of further events.
            public func cancel() {
                subscriber = nil
                isCancelled = true
                cancellables = []
            }

            /// Adds a publisher to be aggregated.
            ///
            /// - Parameter publisher: The publisher to add.
            public func add(_ publisher: some Publisher<some Any, Failure>) {
                let index = startBlocks.count
                startBlocks.append { [weak self] in
                    self?.attach(publisher, index: index)
                }
            }

            /// Attaches a publisher to be aggregated and starts receiving values.
            ///
            /// - Parameters:
            ///   - publisher: The publisher to attach.
            ///   - index: The index at which the publisher is stored.
            private func attach(_ publisher: some Publisher<some Any, Failure>, index: Int) {
                publisher.sink { [weak self] completion in
                    switch completion {
                    case .finished:
                        self?.onFinish(index: index)
                    case let .failure(error):
                        self?.onError(index: index, error: error)
                    }
                } receiveValue: { [weak self] value in
                    self?.onValue(index: index, value: value)
                }.store(in: &cancellables)
            }

            fileprivate func start() {
                startBlocks.forEach { $0() }
            }

            /// Processes a new value received from one of the publishers
            ///
            /// - Parameters:
            ///   - index: The index of the publisher that sent the value.
            ///   - value: The received value.
            private func onValue(index: Int, value: some Any) {
                lock.withLock {
                    if values[index].isEmpty {
                        countWithValues += 1
                        values[index].append(value)
                    } else {
                        switch strategy {
                        case .combineLatest:
                            values[index][0] = value
                        case .zip:
                            values[index].append(value)
                        }
                    }

                    // Emit next value if possible
                    guard let subscriber, countWithValues == values.count, demand > 0, !isCancelled else { return }

                    let nextValue = aggregationBlock(values.compactMap(\.first))
                    switch strategy {
                    case .combineLatest:
                        break
                    case .zip:
                        for i in 0 ..< values.count {
                            values[i].removeFirst()
                            if values[i].isEmpty {
                                countWithValues -= 1
                            }
                        }
                    }
                    _ = subscriber.receive(nextValue)

                    if demand != .unlimited, demand > 0 {
                        demand -= 1
                    }
                }
            }

            /// Processes an error received from one of the publishers; this
            /// cancels the publisher.
            ///
            /// - Parameters:
            ///   - index: The index of the publisher that sent the error.
            ///   - error: The error.
            private func onError(index: Int, error: Failure) {
                lock.withLock {
                    subscriber?.receive(completion: .failure(error))
                    cancel()
                }
            }

            /// Processes the completion event of one of the publishers.
            ///
            /// - Parameter index: The index of the publisher that completed.
            private func onFinish(index: Int) {
                lock.withLock {
                    finished[index] = true
                    guard let subscriber else { return }

                    switch strategy {
                    case .combineLatest:
                        // For combineLatest, we propogate the finish only when all
                        // upstream publishers have finished (or if one has finished
                        // without emitting a value)
                        if values[index].isEmpty || finished.allSatisfy({ $0 }) {
                            subscriber.receive(completion: .finished)
                            cancel()
                        }
                    case .zip:
                        // For zip, we propogate the finish only if any finished
                        // publisher has zero elements (otherwise it can still drain)
                        if values[index].isEmpty {
                            subscriber.receive(completion: .finished)
                            cancel()
                        }
                    }
                }
            }
        }
    }
}
