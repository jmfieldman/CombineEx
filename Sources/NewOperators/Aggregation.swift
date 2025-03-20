//
//  Aggregation.swift
//  Copyright © 2025 Jason Fieldman.
//

import Combine
import Foundation

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
        private let componentBuilder: (any AggregatePublisherAggregator<Failure>) -> Void
        private let aggregationBlock: ([Any]) -> Output

        /// Creates a new `Aggregate` publisher.
        ///
        /// - Parameters:
        ///   - strategy: The strategy used to combine the values from sub-publishers.
        ///   - componentBuilder: A closure that is called with an aggregator object, allowing you to add publishers.
        ///   - aggregationBlock: A block that takes an array of values and returns a single output value.
        public init(
            strategy: Strategy,
            componentBuilder: @escaping (any AggregatePublisherAggregator<Failure>) -> Void,
            aggregationBlock: @escaping ([Any]) -> Output
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
        public final class AggregateSubscription<S: Subscriber>: Subscription, AggregatePublisherAggregator where S.Input == Output, S.Failure == Failure {
            public typealias AggregateFailure = Failure
            public typealias Input = Output

            private var subscriber: S?
            private var isCancelled = false
            private var demand: Subscribers.Demand = .unlimited

            private let strategy: Strategy
            private let componentBuilder: (AggregateSubscription) -> Void
            private let aggregationBlock: ([Any]) -> Output

            private var lock = NSLock()
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
                componentBuilder: @escaping (AggregateSubscription) -> Void,
                aggregationBlock: @escaping ([Any]) -> Output
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

                    lock.withLock {
                        if demand != .unlimited, demand > 0 {
                            demand -= 1
                        }
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

// MARK: - Publisher Combine Latest

// Additional combineLatest implementations that combine the receiver with
// other publishers -- these extend the limit beyond 3

public extension Publisher {
    func combineLatest<A, B, C, D>(
        _ p1: some Publisher<A, Failure>,
        _ p2: some Publisher<B, Failure>,
        _ p3: some Publisher<C, Failure>,
        _ p4: some Publisher<D, Failure>
    ) -> Publishers.Aggregate<(Output, A, B, C, D), Failure> {
        Publishers.Aggregate<(Output, A, B, C, D), Failure>(
            strategy: .combineLatest)
        {
            $0.add(self)
            $0.add(p1)
            $0.add(p2)
            $0.add(p3)
            $0.add(p4)
        } aggregationBlock: {
            ($0[0] as! Output, $0[1] as! A, $0[2] as! B, $0[3] as! C, $0[4] as! D)
        }
    }

    func combineLatest<A, B, C, D, E>(
        _ p1: some Publisher<A, Failure>,
        _ p2: some Publisher<B, Failure>,
        _ p3: some Publisher<C, Failure>,
        _ p4: some Publisher<D, Failure>,
        _ p5: some Publisher<E, Failure>
    ) -> Publishers.Aggregate<(Output, A, B, C, D, E), Failure> {
        Publishers.Aggregate<(Output, A, B, C, D, E), Failure>(
            strategy: .combineLatest)
        {
            $0.add(self)
            $0.add(p1)
            $0.add(p2)
            $0.add(p3)
            $0.add(p4)
            $0.add(p5)
        } aggregationBlock: {
            ($0[0] as! Output, $0[1] as! A, $0[2] as! B, $0[3] as! C, $0[4] as! D, $0[5] as! E)
        }
    }

    func combineLatest<A, B, C, D, E, F>(
        _ p1: some Publisher<A, Failure>,
        _ p2: some Publisher<B, Failure>,
        _ p3: some Publisher<C, Failure>,
        _ p4: some Publisher<D, Failure>,
        _ p5: some Publisher<E, Failure>,
        _ p6: some Publisher<F, Failure>
    ) -> Publishers.Aggregate<(Output, A, B, C, D, E, F), Failure> {
        Publishers.Aggregate<(Output, A, B, C, D, E, F), Failure>(
            strategy: .combineLatest)
        {
            $0.add(self)
            $0.add(p1)
            $0.add(p2)
            $0.add(p3)
            $0.add(p4)
            $0.add(p5)
            $0.add(p6)
        } aggregationBlock: {
            ($0[0] as! Output, $0[1] as! A, $0[2] as! B, $0[3] as! C, $0[4] as! D, $0[5] as! E, $0[6] as! F)
        }
    }

    func combineLatest<A, B, C, D, E, F, G>(
        _ p1: some Publisher<A, Failure>,
        _ p2: some Publisher<B, Failure>,
        _ p3: some Publisher<C, Failure>,
        _ p4: some Publisher<D, Failure>,
        _ p5: some Publisher<E, Failure>,
        _ p6: some Publisher<F, Failure>,
        _ p7: some Publisher<G, Failure>
    ) -> Publishers.Aggregate<(Output, A, B, C, D, E, F, G), Failure> {
        Publishers.Aggregate<(Output, A, B, C, D, E, F, G), Failure>(
            strategy: .combineLatest)
        {
            $0.add(self)
            $0.add(p1)
            $0.add(p2)
            $0.add(p3)
            $0.add(p4)
            $0.add(p5)
            $0.add(p6)
            $0.add(p7)
        } aggregationBlock: {
            ($0[0] as! Output, $0[1] as! A, $0[2] as! B, $0[3] as! C, $0[4] as! D, $0[5] as! E, $0[6] as! F, $0[7] as! G)
        }
    }

    func combineLatest<A, B, C, D, E, F, G, H>(
        _ p1: some Publisher<A, Failure>,
        _ p2: some Publisher<B, Failure>,
        _ p3: some Publisher<C, Failure>,
        _ p4: some Publisher<D, Failure>,
        _ p5: some Publisher<E, Failure>,
        _ p6: some Publisher<F, Failure>,
        _ p7: some Publisher<G, Failure>,
        _ p8: some Publisher<H, Failure>
    ) -> Publishers.Aggregate<(Output, A, B, C, D, E, F, G, H), Failure> {
        Publishers.Aggregate<(Output, A, B, C, D, E, F, G, H), Failure>(
            strategy: .combineLatest)
        {
            $0.add(self)
            $0.add(p1)
            $0.add(p2)
            $0.add(p3)
            $0.add(p4)
            $0.add(p5)
            $0.add(p6)
            $0.add(p7)
            $0.add(p8)
        } aggregationBlock: {
            ($0[0] as! Output, $0[1] as! A, $0[2] as! B, $0[3] as! C, $0[4] as! D, $0[5] as! E, $0[6] as! F, $0[7] as! G, $0[8] as! H)
        }
    }

    func combineLatest<A, B, C, D, E, F, G, H, I>(
        _ p1: some Publisher<A, Failure>,
        _ p2: some Publisher<B, Failure>,
        _ p3: some Publisher<C, Failure>,
        _ p4: some Publisher<D, Failure>,
        _ p5: some Publisher<E, Failure>,
        _ p6: some Publisher<F, Failure>,
        _ p7: some Publisher<G, Failure>,
        _ p8: some Publisher<H, Failure>,
        _ p9: some Publisher<I, Failure>
    ) -> Publishers.Aggregate<(Output, A, B, C, D, E, F, G, H, I), Failure> {
        Publishers.Aggregate<(Output, A, B, C, D, E, F, G, H, I), Failure>(
            strategy: .combineLatest)
        {
            $0.add(self)
            $0.add(p1)
            $0.add(p2)
            $0.add(p3)
            $0.add(p4)
            $0.add(p5)
            $0.add(p6)
            $0.add(p7)
            $0.add(p8)
            $0.add(p9)
        } aggregationBlock: {
            ($0[0] as! Output, $0[1] as! A, $0[2] as! B, $0[3] as! C, $0[4] as! D, $0[5] as! E, $0[6] as! F, $0[7] as! G, $0[8] as! H, $0[9] as! I)
        }
    }
}

// MARK: - Publisher Static Combine Latest

// Additional static combineLatest implementations that combine the arguments
// together into a single publisher, allowing up to 10 combined publishers.

public extension Publisher {
    static func combineLatest<A, B>(
        _ p1: some Publisher<A, Failure>,
        _ p2: some Publisher<B, Failure>
    ) -> Publishers.Aggregate<(A, B), Failure> {
        Publishers.Aggregate<(A, B), Failure>(
            strategy: .combineLatest)
        {
            $0.add(p1)
            $0.add(p2)
        } aggregationBlock: {
            ($0[0] as! A, $0[1] as! B)
        }
    }

    static func combineLatest<A, B, C>(
        _ p1: some Publisher<A, Failure>,
        _ p2: some Publisher<B, Failure>,
        _ p3: some Publisher<C, Failure>
    ) -> Publishers.Aggregate<(A, B, C), Failure> {
        Publishers.Aggregate<(A, B, C), Failure>(
            strategy: .combineLatest)
        {
            $0.add(p1)
            $0.add(p2)
            $0.add(p3)
        } aggregationBlock: {
            ($0[0] as! A, $0[1] as! B, $0[2] as! C)
        }
    }

    static func combineLatest<A, B, C, D>(
        _ p1: some Publisher<A, Failure>,
        _ p2: some Publisher<B, Failure>,
        _ p3: some Publisher<C, Failure>,
        _ p4: some Publisher<D, Failure>
    ) -> Publishers.Aggregate<(A, B, C, D), Failure> {
        Publishers.Aggregate<(A, B, C, D), Failure>(
            strategy: .combineLatest)
        {
            $0.add(p1)
            $0.add(p2)
            $0.add(p3)
            $0.add(p4)
        } aggregationBlock: {
            ($0[0] as! A, $0[1] as! B, $0[2] as! C, $0[3] as! D)
        }
    }

    static func combineLatest<A, B, C, D, E>(
        _ p1: some Publisher<A, Failure>,
        _ p2: some Publisher<B, Failure>,
        _ p3: some Publisher<C, Failure>,
        _ p4: some Publisher<D, Failure>,
        _ p5: some Publisher<E, Failure>
    ) -> Publishers.Aggregate<(A, B, C, D, E), Failure> {
        Publishers.Aggregate<(A, B, C, D, E), Failure>(
            strategy: .combineLatest)
        {
            $0.add(p1)
            $0.add(p2)
            $0.add(p3)
            $0.add(p4)
            $0.add(p5)
        } aggregationBlock: {
            ($0[0] as! A, $0[1] as! B, $0[2] as! C, $0[3] as! D, $0[4] as! E)
        }
    }

    static func combineLatest<A, B, C, D, E, F>(
        _ p1: some Publisher<A, Failure>,
        _ p2: some Publisher<B, Failure>,
        _ p3: some Publisher<C, Failure>,
        _ p4: some Publisher<D, Failure>,
        _ p5: some Publisher<E, Failure>,
        _ p6: some Publisher<F, Failure>
    ) -> Publishers.Aggregate<(A, B, C, D, E, F), Failure> {
        Publishers.Aggregate<(A, B, C, D, E, F), Failure>(
            strategy: .combineLatest)
        {
            $0.add(p1)
            $0.add(p2)
            $0.add(p3)
            $0.add(p4)
            $0.add(p5)
            $0.add(p6)
        } aggregationBlock: {
            ($0[0] as! A, $0[1] as! B, $0[2] as! C, $0[3] as! D, $0[4] as! E, $0[5] as! F)
        }
    }

    static func combineLatest<A, B, C, D, E, F, G>(
        _ p1: some Publisher<A, Failure>,
        _ p2: some Publisher<B, Failure>,
        _ p3: some Publisher<C, Failure>,
        _ p4: some Publisher<D, Failure>,
        _ p5: some Publisher<E, Failure>,
        _ p6: some Publisher<F, Failure>,
        _ p7: some Publisher<G, Failure>
    ) -> Publishers.Aggregate<(A, B, C, D, E, F, G), Failure> {
        Publishers.Aggregate<(A, B, C, D, E, F, G), Failure>(
            strategy: .combineLatest)
        {
            $0.add(p1)
            $0.add(p2)
            $0.add(p3)
            $0.add(p4)
            $0.add(p5)
            $0.add(p6)
            $0.add(p7)
        } aggregationBlock: {
            ($0[0] as! A, $0[1] as! B, $0[2] as! C, $0[3] as! D, $0[4] as! E, $0[5] as! F, $0[6] as! G)
        }
    }

    static func combineLatest<A, B, C, D, E, F, G, H>(
        _ p1: some Publisher<A, Failure>,
        _ p2: some Publisher<B, Failure>,
        _ p3: some Publisher<C, Failure>,
        _ p4: some Publisher<D, Failure>,
        _ p5: some Publisher<E, Failure>,
        _ p6: some Publisher<F, Failure>,
        _ p7: some Publisher<G, Failure>,
        _ p8: some Publisher<H, Failure>
    ) -> Publishers.Aggregate<(A, B, C, D, E, F, G, H), Failure> {
        Publishers.Aggregate<(A, B, C, D, E, F, G, H), Failure>(
            strategy: .combineLatest)
        {
            $0.add(p1)
            $0.add(p2)
            $0.add(p3)
            $0.add(p4)
            $0.add(p5)
            $0.add(p6)
            $0.add(p7)
            $0.add(p8)
        } aggregationBlock: {
            ($0[0] as! A, $0[1] as! B, $0[2] as! C, $0[3] as! D, $0[4] as! E, $0[5] as! F, $0[6] as! G, $0[7] as! H)
        }
    }

    static func combineLatest<A, B, C, D, E, F, G, H, I>(
        _ p1: some Publisher<A, Failure>,
        _ p2: some Publisher<B, Failure>,
        _ p3: some Publisher<C, Failure>,
        _ p4: some Publisher<D, Failure>,
        _ p5: some Publisher<E, Failure>,
        _ p6: some Publisher<F, Failure>,
        _ p7: some Publisher<G, Failure>,
        _ p8: some Publisher<H, Failure>,
        _ p9: some Publisher<I, Failure>
    ) -> Publishers.Aggregate<(A, B, C, D, E, F, G, H, I), Failure> {
        Publishers.Aggregate<(A, B, C, D, E, F, G, H, I), Failure>(
            strategy: .combineLatest)
        {
            $0.add(p1)
            $0.add(p2)
            $0.add(p3)
            $0.add(p4)
            $0.add(p5)
            $0.add(p6)
            $0.add(p7)
            $0.add(p8)
            $0.add(p9)
        } aggregationBlock: {
            ($0[0] as! A, $0[1] as! B, $0[2] as! C, $0[3] as! D, $0[4] as! E, $0[5] as! F, $0[6] as! G, $0[7] as! H, $0[8] as! I)
        }
    }

    static func combineLatest<A, B, C, D, E, F, G, H, I, J>(
        _ p1: some Publisher<A, Failure>,
        _ p2: some Publisher<B, Failure>,
        _ p3: some Publisher<C, Failure>,
        _ p4: some Publisher<D, Failure>,
        _ p5: some Publisher<E, Failure>,
        _ p6: some Publisher<F, Failure>,
        _ p7: some Publisher<G, Failure>,
        _ p8: some Publisher<H, Failure>,
        _ p9: some Publisher<I, Failure>,
        _ p10: some Publisher<J, Failure>
    ) -> Publishers.Aggregate<(A, B, C, D, E, F, G, H, I, J), Failure> {
        Publishers.Aggregate<(A, B, C, D, E, F, G, H, I, J), Failure>(
            strategy: .combineLatest)
        {
            $0.add(p1)
            $0.add(p2)
            $0.add(p3)
            $0.add(p4)
            $0.add(p5)
            $0.add(p6)
            $0.add(p7)
            $0.add(p8)
            $0.add(p9)
            $0.add(p10)
        } aggregationBlock: {
            ($0[0] as! A, $0[1] as! B, $0[2] as! C, $0[3] as! D, $0[4] as! E, $0[5] as! F, $0[6] as! G, $0[7] as! H, $0[8] as! I, $0[9] as! J)
        }
    }
}

// MARK: - DeferredPublisher Combine Latest

public extension DeferredPublisherProtocol {
    @_disfavoredOverload
    func combineLatest<A>(
        _ p1: some DeferredPublisherProtocol<A, Failure>
    ) -> Deferred<Publishers.Aggregate<(Output, A), Failure>> {
        Deferred {
            Publishers.Aggregate<(Output, A), Failure>(
                strategy: .combineLatest)
            {
                $0.add(self)
                $0.add(p1)
            } aggregationBlock: {
                ($0[0] as! Output, $0[1] as! A)
            }
        }
    }

    @_disfavoredOverload
    func combineLatest<A, NewOutput>(
        _ p1: some DeferredPublisherProtocol<A, Failure>,
        _ transform: @escaping (Output, A) -> NewOutput
    ) -> Deferred<Publishers.Aggregate<NewOutput, Failure>> {
        Deferred {
            Publishers.Aggregate<NewOutput, Failure>(
                strategy: .combineLatest)
            {
                $0.add(self)
                $0.add(p1)
            } aggregationBlock: {
                transform($0[0] as! Output, $0[1] as! A)
            }
        }
    }

    @_disfavoredOverload
    func combineLatest<A, B>(
        _ p1: some DeferredPublisherProtocol<A, Failure>,
        _ p2: some DeferredPublisherProtocol<B, Failure>
    ) -> Deferred<Publishers.Aggregate<(Output, A, B), Failure>> {
        Deferred {
            Publishers.Aggregate<(Output, A, B), Failure>(
                strategy: .combineLatest)
            {
                $0.add(self)
                $0.add(p1)
                $0.add(p2)
            } aggregationBlock: {
                ($0[0] as! Output, $0[1] as! A, $0[2] as! B)
            }
        }
    }

    @_disfavoredOverload
    func combineLatest<A, B, NewOutput>(
        _ p1: some DeferredPublisherProtocol<A, Failure>,
        _ p2: some DeferredPublisherProtocol<B, Failure>,
        _ transform: @escaping (Output, A, B) -> NewOutput
    ) -> Deferred<Publishers.Aggregate<NewOutput, Failure>> {
        Deferred {
            Publishers.Aggregate<NewOutput, Failure>(
                strategy: .combineLatest)
            {
                $0.add(self)
                $0.add(p1)
                $0.add(p2)
            } aggregationBlock: {
                transform($0[0] as! Output, $0[1] as! A, $0[2] as! B)
            }
        }
    }

    @_disfavoredOverload
    func combineLatest<A, B, C>(
        _ p1: some DeferredPublisherProtocol<A, Failure>,
        _ p2: some DeferredPublisherProtocol<B, Failure>,
        _ p3: some DeferredPublisherProtocol<C, Failure>
    ) -> Deferred<Publishers.Aggregate<(Output, A, B, C), Failure>> {
        Deferred {
            Publishers.Aggregate<(Output, A, B, C), Failure>(
                strategy: .combineLatest)
            {
                $0.add(self)
                $0.add(p1)
                $0.add(p2)
                $0.add(p3)
            } aggregationBlock: {
                ($0[0] as! Output, $0[1] as! A, $0[2] as! B, $0[3] as! C)
            }
        }
    }

    @_disfavoredOverload
    func combineLatest<A, B, C, NewOutput>(
        _ p1: some DeferredPublisherProtocol<A, Failure>,
        _ p2: some DeferredPublisherProtocol<B, Failure>,
        _ p3: some DeferredPublisherProtocol<C, Failure>,
        _ transform: @escaping (Output, A, B, C) -> NewOutput
    ) -> Deferred<Publishers.Aggregate<NewOutput, Failure>> {
        Deferred {
            Publishers.Aggregate<NewOutput, Failure>(
                strategy: .combineLatest)
            {
                $0.add(self)
                $0.add(p1)
                $0.add(p2)
                $0.add(p3)
            } aggregationBlock: {
                transform($0[0] as! Output, $0[1] as! A, $0[2] as! B, $0[3] as! C)
            }
        }
    }

    @_disfavoredOverload
    func combineLatest<A, B, C, D>(
        _ p1: some DeferredPublisherProtocol<A, Failure>,
        _ p2: some DeferredPublisherProtocol<B, Failure>,
        _ p3: some DeferredPublisherProtocol<C, Failure>,
        _ p4: some DeferredPublisherProtocol<D, Failure>
    ) -> Deferred<Publishers.Aggregate<(Output, A, B, C, D), Failure>> {
        Deferred {
            Publishers.Aggregate<(Output, A, B, C, D), Failure>(
                strategy: .combineLatest)
            {
                $0.add(self)
                $0.add(p1)
                $0.add(p2)
                $0.add(p3)
                $0.add(p4)
            } aggregationBlock: {
                ($0[0] as! Output, $0[1] as! A, $0[2] as! B, $0[3] as! C, $0[4] as! D)
            }
        }
    }

    @_disfavoredOverload
    func combineLatest<A, B, C, D, E>(
        _ p1: some DeferredPublisherProtocol<A, Failure>,
        _ p2: some DeferredPublisherProtocol<B, Failure>,
        _ p3: some DeferredPublisherProtocol<C, Failure>,
        _ p4: some DeferredPublisherProtocol<D, Failure>,
        _ p5: some DeferredPublisherProtocol<E, Failure>
    ) -> Deferred<Publishers.Aggregate<(Output, A, B, C, D, E), Failure>> {
        Deferred {
            Publishers.Aggregate<(Output, A, B, C, D, E), Failure>(
                strategy: .combineLatest)
            {
                $0.add(self)
                $0.add(p1)
                $0.add(p2)
                $0.add(p3)
                $0.add(p4)
                $0.add(p5)
            } aggregationBlock: {
                ($0[0] as! Output, $0[1] as! A, $0[2] as! B, $0[3] as! C, $0[4] as! D, $0[5] as! E)
            }
        }
    }
}

// MARK: - Zip

public extension Publisher {
    func zip<A, B, C, D>(
        _ p1: some Publisher<A, Failure>,
        _ p2: some Publisher<B, Failure>,
        _ p3: some Publisher<C, Failure>,
        _ p4: some Publisher<D, Failure>
    ) -> Publishers.Aggregate<(Output, A, B, C, D), Failure> {
        Publishers.Aggregate<(Output, A, B, C, D), Failure>(
            strategy: .zip)
        {
            $0.add(self)
            $0.add(p1)
            $0.add(p2)
            $0.add(p3)
            $0.add(p4)
        } aggregationBlock: {
            ($0[0] as! Output, $0[1] as! A, $0[2] as! B, $0[3] as! C, $0[4] as! D)
        }
    }

    func zip<A, B, C, D, E>(
        _ p1: some Publisher<A, Failure>,
        _ p2: some Publisher<B, Failure>,
        _ p3: some Publisher<C, Failure>,
        _ p4: some Publisher<D, Failure>,
        _ p5: some Publisher<E, Failure>
    ) -> Publishers.Aggregate<(Output, A, B, C, D, E), Failure> {
        Publishers.Aggregate<(Output, A, B, C, D, E), Failure>(
            strategy: .zip)
        {
            $0.add(self)
            $0.add(p1)
            $0.add(p2)
            $0.add(p3)
            $0.add(p4)
            $0.add(p5)
        } aggregationBlock: {
            ($0[0] as! Output, $0[1] as! A, $0[2] as! B, $0[3] as! C, $0[4] as! D, $0[5] as! E)
        }
    }

    func zip<A, B, C, D, E, F>(
        _ p1: some Publisher<A, Failure>,
        _ p2: some Publisher<B, Failure>,
        _ p3: some Publisher<C, Failure>,
        _ p4: some Publisher<D, Failure>,
        _ p5: some Publisher<E, Failure>,
        _ p6: some Publisher<F, Failure>
    ) -> Publishers.Aggregate<(Output, A, B, C, D, E, F), Failure> {
        Publishers.Aggregate<(Output, A, B, C, D, E, F), Failure>(
            strategy: .zip)
        {
            $0.add(self)
            $0.add(p1)
            $0.add(p2)
            $0.add(p3)
            $0.add(p4)
            $0.add(p5)
            $0.add(p6)
        } aggregationBlock: {
            ($0[0] as! Output, $0[1] as! A, $0[2] as! B, $0[3] as! C, $0[4] as! D, $0[5] as! E, $0[6] as! F)
        }
    }

    func zip<A, B, C, D, E, F, G>(
        _ p1: some Publisher<A, Failure>,
        _ p2: some Publisher<B, Failure>,
        _ p3: some Publisher<C, Failure>,
        _ p4: some Publisher<D, Failure>,
        _ p5: some Publisher<E, Failure>,
        _ p6: some Publisher<F, Failure>,
        _ p7: some Publisher<G, Failure>
    ) -> Publishers.Aggregate<(Output, A, B, C, D, E, F, G), Failure> {
        Publishers.Aggregate<(Output, A, B, C, D, E, F, G), Failure>(
            strategy: .zip)
        {
            $0.add(self)
            $0.add(p1)
            $0.add(p2)
            $0.add(p3)
            $0.add(p4)
            $0.add(p5)
            $0.add(p6)
            $0.add(p7)
        } aggregationBlock: {
            ($0[0] as! Output, $0[1] as! A, $0[2] as! B, $0[3] as! C, $0[4] as! D, $0[5] as! E, $0[6] as! F, $0[7] as! G)
        }
    }

    func zip<A, B, C, D, E, F, G, H>(
        _ p1: some Publisher<A, Failure>,
        _ p2: some Publisher<B, Failure>,
        _ p3: some Publisher<C, Failure>,
        _ p4: some Publisher<D, Failure>,
        _ p5: some Publisher<E, Failure>,
        _ p6: some Publisher<F, Failure>,
        _ p7: some Publisher<G, Failure>,
        _ p8: some Publisher<H, Failure>
    ) -> Publishers.Aggregate<(Output, A, B, C, D, E, F, G, H), Failure> {
        Publishers.Aggregate<(Output, A, B, C, D, E, F, G, H), Failure>(
            strategy: .zip)
        {
            $0.add(self)
            $0.add(p1)
            $0.add(p2)
            $0.add(p3)
            $0.add(p4)
            $0.add(p5)
            $0.add(p6)
            $0.add(p7)
            $0.add(p8)
        } aggregationBlock: {
            ($0[0] as! Output, $0[1] as! A, $0[2] as! B, $0[3] as! C, $0[4] as! D, $0[5] as! E, $0[6] as! F, $0[7] as! G, $0[8] as! H)
        }
    }

    func zip<A, B, C, D, E, F, G, H, I>(
        _ p1: some Publisher<A, Failure>,
        _ p2: some Publisher<B, Failure>,
        _ p3: some Publisher<C, Failure>,
        _ p4: some Publisher<D, Failure>,
        _ p5: some Publisher<E, Failure>,
        _ p6: some Publisher<F, Failure>,
        _ p7: some Publisher<G, Failure>,
        _ p8: some Publisher<H, Failure>,
        _ p9: some Publisher<I, Failure>
    ) -> Publishers.Aggregate<(Output, A, B, C, D, E, F, G, H, I), Failure> {
        Publishers.Aggregate<(Output, A, B, C, D, E, F, G, H, I), Failure>(
            strategy: .zip)
        {
            $0.add(self)
            $0.add(p1)
            $0.add(p2)
            $0.add(p3)
            $0.add(p4)
            $0.add(p5)
            $0.add(p6)
            $0.add(p7)
            $0.add(p8)
            $0.add(p9)
        } aggregationBlock: {
            ($0[0] as! Output, $0[1] as! A, $0[2] as! B, $0[3] as! C, $0[4] as! D, $0[5] as! E, $0[6] as! F, $0[7] as! G, $0[8] as! H, $0[9] as! I)
        }
    }
}
