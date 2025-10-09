//
//  Aggregation+DeferredFuture.swift
//  Copyright © 2025 Jason Fieldman.
//

import Combine
import Foundation
import os

// MARK: - CombineLatestAccumulator

/// A private class that helps us accumuate N promises. The class
/// retains itself until the outer promise is executed.
private class CombineLatestAccumulator<Output, Failure: Error> {
    private var values: [Any]
    private var nextIndex = 0
    private let lock = OSAllocatedUnfairLock()
    private var remaining: Int

    // While onAccumulated and outerPromise are guaranteed at init,
    // we keep them optional so that we can nullify them after the
    // first notification (just for safety).
    private var onAccumulated: (([Any]) -> Output)?
    private var outerPromise: (Future<Output, Failure>.Promise)?

    // Our futures gaurantee their output -- so we retain ourselves
    // until they all emit. This is a potential
    private var retainer: CombineLatestAccumulator?

    init(
        _ outerPromise: @escaping Future<Output, Failure>.Promise,
        _ count: Int,
        onAccumulated: @escaping ([Any]) -> Output
    ) {
        self.values = [Any](repeating: 0, count: count)
        self.outerPromise = outerPromise
        self.onAccumulated = onAccumulated
        self.remaining = count
        self.retainer = self
    }

    func add(_ future: some DeferredFutureProtocol<some Any, Failure>) {
        let index = nextIndex
        nextIndex += 1
        future.attemptToFulfill { [weak self] result in
            self?.lock.withLock { [weak self] in
                self?.handleOuterResult(result, index: index)
            }
        }
    }

    private func handleOuterResult(_ result: Result<some Any, Failure>, index: Int) {
        switch result {
        case let .success(value):
            values[index] = value
            remaining -= 1
            if remaining == 0, let onAccumulated {
                notify(.success(onAccumulated(values)))
            }
        case let .failure(error):
            notify(.failure(error))
        }
    }

    private func notify(_ result: Result<Output, Failure>) {
        outerPromise?(result)
        onAccumulated = nil
        outerPromise = nil
        retainer = nil
    }
}

// MARK: - Combine Latest

public extension DeferredFutureProtocol {
    /// Combines the output of this deferred future with another deferred future and emits a tuple of their outputs.
    ///
    /// - Parameters:
    ///   - other: Another deferred future to combine with this one.
    ///
    /// - Returns: A `DeferredFuture` that emits a tuple of the outputs from this and the other deferred future.
    @_disfavoredOverload
    func combineLatest<P>(
        _ other: some DeferredFutureProtocol<P, Failure>
    ) -> DeferredFuture<(Self.Output, P), Failure> {
        DeferredFuture { promise in
            let accumulator = CombineLatestAccumulator(promise, 2) {
                ($0[0] as! Self.Output, $0[1] as! P)
            }
            accumulator.add(self)
            accumulator.add(other)
        }
    }

    /// Combines the output of this deferred future with another deferred future and applies a transformation to their outputs.
    ///
    /// - Parameters:
    ///   - other: Another deferred future to combine with this one.
    ///   - transform: A closure that takes the outputs of this and the other deferred future and returns a transformed value.
    ///
    /// - Returns: A `DeferredFuture` that emits the transformed value from the closure.
    @_disfavoredOverload
    func combineLatest<P, T>(
        _ other: some DeferredFutureProtocol<P, Failure>,
        _ transform: @escaping (Self.Output, P) -> T
    ) -> DeferredFuture<T, Failure> {
        DeferredFuture { promise in
            let accumulator = CombineLatestAccumulator(promise, 2) {
                transform($0[0] as! Self.Output, $0[1] as! P)
            }
            accumulator.add(self)
            accumulator.add(other)
        }
    }

    /// Combines the output of this deferred future with two other deferred futures and emits a tuple of their outputs.
    ///
    /// - Parameters:
    ///   - publisher1: The first deferred future to combine with this one.
    ///   - publisher2: The second deferred future to combine with this one.
    ///
    /// - Returns: A `DeferredFuture` that emits a tuple of the outputs from this and the two other deferred futures.
    @_disfavoredOverload
    func combineLatest<P, Q>(
        _ publisher1: some DeferredFutureProtocol<P, Failure>,
        _ publisher2: some DeferredFutureProtocol<Q, Failure>
    ) -> DeferredFuture<(Self.Output, P, Q), Failure> {
        DeferredFuture { promise in
            let accumulator = CombineLatestAccumulator(promise, 3) {
                ($0[0] as! Self.Output, $0[1] as! P, $0[2] as! Q)
            }
            accumulator.add(self)
            accumulator.add(publisher1)
            accumulator.add(publisher2)
        }
    }

    /// Combines the output of this deferred future with two other deferred futures and applies a transformation to their outputs.
    ///
    /// - Parameters:
    ///   - publisher1: The first deferred future to combine with this one.
    ///   - publisher2: The second deferred future to combine with this one.
    ///   - transform: A closure that takes the outputs of this and the two other deferred futures and returns a transformed value.
    ///
    /// - Returns: A `DeferredFuture` that emits the transformed value from the closure.
    @_disfavoredOverload
    func combineLatest<P, Q, T>(
        _ publisher1: some DeferredFutureProtocol<P, Failure>,
        _ publisher2: some DeferredFutureProtocol<Q, Failure>,
        _ transform: @escaping (Self.Output, P, Q) -> T
    ) -> DeferredFuture<T, Failure> {
        DeferredFuture { promise in
            let accumulator = CombineLatestAccumulator(promise, 3) {
                transform($0[0] as! Self.Output, $0[1] as! P, $0[2] as! Q)
            }
            accumulator.add(self)
            accumulator.add(publisher1)
            accumulator.add(publisher2)
        }
    }

    /// Combines the output of this deferred future with three other deferred futures and emits a tuple of their outputs.
    ///
    /// - Parameters:
    ///   - publisher1: The first deferred future to combine with this one.
    ///   - publisher2: The second deferred future to combine with this one.
    ///   - publisher3: The third deferred future to combine with this one.
    ///
    /// - Returns: A `DeferredFuture` that emits a tuple of the outputs from this and the three other deferred futures.
    @_disfavoredOverload
    func combineLatest<P, Q, R>(
        _ publisher1: some DeferredFutureProtocol<P, Failure>,
        _ publisher2: some DeferredFutureProtocol<Q, Failure>,
        _ publisher3: some DeferredFutureProtocol<R, Failure>
    ) -> DeferredFuture<(Self.Output, P, Q, R), Failure> {
        DeferredFuture { promise in
            let accumulator = CombineLatestAccumulator(promise, 4) {
                ($0[0] as! Self.Output, $0[1] as! P, $0[2] as! Q, $0[3] as! R)
            }
            accumulator.add(self)
            accumulator.add(publisher1)
            accumulator.add(publisher2)
            accumulator.add(publisher3)
        }
    }

    /// Combines the output of this deferred future with three other deferred futures and applies a transformation to their outputs.
    ///
    /// - Parameters:
    ///   - publisher1: The first deferred future to combine with this one.
    ///   - publisher2: The second deferred future to combine with this one.
    ///   - publisher3: The third deferred future to combine with this one.
    ///   - transform: A closure that takes the outputs of this and the three other deferred futures and returns a transformed value.
    ///
    /// - Returns: A `DeferredFuture` that emits the transformed value from the closure.
    @_disfavoredOverload
    func combineLatest<P, Q, R, T>(
        _ publisher1: some DeferredFutureProtocol<P, Failure>,
        _ publisher2: some DeferredFutureProtocol<Q, Failure>,
        _ publisher3: some DeferredFutureProtocol<R, Failure>,
        _ transform: @escaping (Self.Output, P, Q, R) -> T
    ) -> DeferredFuture<T, Failure> {
        DeferredFuture { promise in
            let accumulator = CombineLatestAccumulator(promise, 4) {
                transform($0[0] as! Self.Output, $0[1] as! P, $0[2] as! Q, $0[3] as! R)
            }
            accumulator.add(self)
            accumulator.add(publisher1)
            accumulator.add(publisher2)
            accumulator.add(publisher3)
        }
    }
}

// MARK: - Array

public extension Array where Element: DeferredFutureProtocol {
    func combineLatest() -> DeferredFuture<[Element.Output], Element.Failure> {
        DeferredFuture { promise in
            let accumulator = CombineLatestAccumulator(promise, self.count) {
                $0 as! [Element.Output]
            }
            self.forEach { accumulator.add($0) }
        }
    }
}

public extension DeferredFutureProtocol {
    @_disfavoredOverload
    static func combineLatest(
        array: [some DeferredFutureProtocol<Output, Failure>]
    ) -> DeferredFuture<[Output], Failure> {
        array.combineLatest()
    }
}
