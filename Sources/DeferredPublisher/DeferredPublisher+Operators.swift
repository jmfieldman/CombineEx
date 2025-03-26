//
//  DeferredPublisher+Operators.swift
//  Copyright © 2025 Jason Fieldman.
//

import Combine
import Foundation

#if swift(>=6)
@preconcurrency import Dispatch
#else
import Dispatch
#endif

// MARK: Lift

public extension DeferredPublisherProtocol {
    /// A generic lift function that can operate on any DeferredPublisherProtocol
    /// implementation.
    ///
    /// Use this to transform the inner-wrapped publisher, and re-wrap it in a
    /// new Deferred publisher. This guarantees that transforms result in a new
    /// deferred publisher.
    @inlinable func deferredLift<TargetPublisher: Publisher>(
        _ transform: @escaping (WrappedPublisher) -> TargetPublisher
    ) -> Deferred<TargetPublisher> {
        let innerCreatePublisher = createPublisher
        return Deferred<TargetPublisher> { transform(innerCreatePublisher()) }
    }
}

// MARK: Mapping Elements

public extension DeferredPublisherProtocol {
    /// Transforms the output of the upstream publisher using the provided closure.
    ///
    /// - Parameter transform: A closure that takes the upstream publisher's output and returns a new value.
    /// - Returns: A deferred publisher that emits the transformed values.
    @_disfavoredOverload
    func map<T>(
        _ transform: @escaping (WrappedPublisher.Output) -> T
    ) -> Deferred<Publishers.Map<WrappedPublisher, T>> where WrappedPublisher.Failure == Failure {
        deferredLift { $0.map(transform) }
    }

    /// Transforms the output of the upstream publisher using the provided throwing closure.
    ///
    /// - Parameter transform: A throwing closure that takes the upstream publisher's output and returns a new value.
    /// - Returns: A deferred publisher that emits the transformed values or fails if an error is thrown.
    @_disfavoredOverload
    func tryMap<T>(
        _ transform: @escaping (WrappedPublisher.Output) throws -> T
    ) -> Deferred<Publishers.TryMap<WrappedPublisher, T>> {
        deferredLift { $0.tryMap(transform) }
    }

    /// Transforms the failure of the upstream publisher using the provided closure.
    ///
    /// - Parameter transform: A closure that takes the upstream publisher's failure and returns a new error.
    /// - Returns: A deferred publisher that emits errors transformed by the provided closure.
    @_disfavoredOverload
    func mapError<E>(
        _ transform: @escaping (WrappedPublisher.Failure) -> E
    ) -> Deferred<Publishers.MapError<WrappedPublisher, E>> where E: Error {
        deferredLift { $0.mapError(transform) }
    }

    /// Replaces nil values from the upstream publisher with a specified output value.
    ///
    /// - Parameter output: The output value to replace nil values with.
    /// - Returns: A deferred publisher that emits non-nil values or the specified output value in place of nil.
    @_disfavoredOverload
    func replaceNil<T>(
        with output: T
    ) -> Deferred<Publishers.Map<WrappedPublisher, T>> where WrappedPublisher.Output == T? {
        deferredLift { $0.replaceNil(with: output) }
    }

    /// Accumulates the output of the upstream publisher using the provided closure.
    ///
    /// - Parameters:
    ///   - initialResult: The initial result to start the accumulation.
    ///   - nextPartialResult: A closure that combines the current accumulated value and a new upstream element.
    /// - Returns: A deferred publisher that emits the accumulated values.
    @_disfavoredOverload
    func scan<T>(
        _ initialResult: T,
        _ nextPartialResult: @escaping (T, WrappedPublisher.Output) -> T
    ) -> Deferred<Publishers.Scan<WrappedPublisher, T>> {
        deferredLift { $0.scan(initialResult, nextPartialResult) }
    }

    /// Accumulates the output of the upstream publisher using the provided throwing closure.
    ///
    /// - Parameters:
    ///   - initialResult: The initial result to start the accumulation.
    ///   - nextPartialResult: A throwing closure that combines the current accumulated value and a new upstream element.
    /// - Returns: A deferred publisher that emits the accumulated values or fails if an error is thrown.
    @_disfavoredOverload
    func tryScan<T>(
        _ initialResult: T,
        _ nextPartialResult: @escaping (T, WrappedPublisher.Output) throws -> T
    ) -> Deferred<Publishers.TryScan<WrappedPublisher, T>> {
        deferredLift { $0.tryScan(initialResult, nextPartialResult) }
    }

    /// Sets the failure type of a publisher that never fails to a specified error type.
    ///
    /// - Parameter failureType: The new failure type.
    /// - Returns: A deferred publisher with the updated failure type.
    @_disfavoredOverload
    func setFailureType<E>(
        to failureType: E.Type
    ) -> Deferred<Publishers.SetFailureType<WrappedPublisher, E>> where WrappedPublisher.Failure == Never, E: Error {
        deferredLift { $0.setFailureType(to: E.self) }
    }
}

// MARK: Applying Mathematical Operations on Elements

public extension DeferredPublisherProtocol {
    /// Returns a publisher that emits the total count of elements received from the upstream publisher.
    /// This version is deferred and will not subscribe to the upstream publisher until it is itself subscribed to.
    ///
    /// - Returns: A deferred publisher that emits the total count of elements.
    @_disfavoredOverload
    func count() -> Deferred<Publishers.Count<WrappedPublisher>> where WrappedPublisher.Failure == Failure {
        deferredLift { $0.count() }
    }

    /// Returns a publisher that emits the maximum element received from the upstream publisher.
    /// This version is deferred and will not subscribe to the upstream publisher until it is itself subscribed to.
    ///
    /// - Returns: A deferred publisher that emits the maximum element.
    @_disfavoredOverload
    func max() -> Deferred<Publishers.Comparison<WrappedPublisher>> where WrappedPublisher.Failure == Failure, WrappedPublisher.Output: Comparable {
        deferredLift { $0.max() }
    }

    /// Returns a publisher that emits the maximum element received from the upstream publisher, using the specified comparison predicate.
    /// This version is deferred and will not subscribe to the upstream publisher until it is itself subscribed to.
    ///
    /// - Parameter areInIncreasingOrder: A closure that returns true if its first argument should be ordered before the second.
    /// - Returns: A deferred publisher that emits the maximum element based on the specified predicate.
    @_disfavoredOverload
    func max(
        by areInIncreasingOrder: @escaping (WrappedPublisher.Output, WrappedPublisher.Output) -> Bool
    ) -> Deferred<Publishers.Comparison<WrappedPublisher>> where WrappedPublisher.Failure == Failure {
        deferredLift { $0.max(by: areInIncreasingOrder) }
    }

    /// Returns a publisher that emits the maximum element received from the upstream publisher, using the specified throwing comparison predicate.
    /// This version is deferred and will not subscribe to the upstream publisher until it is itself subscribed to.
    ///
    /// - Parameter areInIncreasingOrder: A throwing closure that returns true if its first argument should be ordered before the second.
    /// - Returns: A deferred publisher that emits the maximum element based on the specified predicate, or fails if an error is thrown.
    @_disfavoredOverload
    func tryMax(
        by areInIncreasingOrder: @escaping (WrappedPublisher.Output, WrappedPublisher.Output) throws(Failure) -> Bool
    ) -> Deferred<Publishers.TryComparison<WrappedPublisher>> where WrappedPublisher.Failure == Failure {
        deferredLift { $0.tryMax(by: areInIncreasingOrder) }
    }

    /// Returns a publisher that emits the minimum element received from the upstream publisher.
    /// This version is deferred and will not subscribe to the upstream publisher until it is itself subscribed to.
    ///
    /// - Returns: A deferred publisher that emits the minimum element.
    @_disfavoredOverload
    func min() -> Deferred<Publishers.Comparison<WrappedPublisher>> where WrappedPublisher.Failure == Failure, WrappedPublisher.Output: Comparable {
        deferredLift { $0.min() }
    }

    /// Returns a publisher that emits the minimum element received from the upstream publisher, using the specified comparison predicate.
    /// This version is deferred and will not subscribe to the upstream publisher until it is itself subscribed to.
    ///
    /// - Parameter areInIncreasingOrder: A closure that returns true if its first argument should be ordered before the second.
    /// - Returns: A deferred publisher that emits the minimum element based on the specified predicate.
    @_disfavoredOverload
    func min(
        by areInIncreasingOrder: @escaping (WrappedPublisher.Output, WrappedPublisher.Output) -> Bool
    ) -> Deferred<Publishers.Comparison<WrappedPublisher>> where WrappedPublisher.Failure == Failure {
        deferredLift { $0.min(by: areInIncreasingOrder) }
    }

    /// Returns a publisher that emits the minimum element received from the upstream publisher, using the specified throwing comparison predicate.
    /// This version is deferred and will not subscribe to the upstream publisher until it is itself subscribed to.
    ///
    /// - Parameter areInIncreasingOrder: A throwing closure that returns true if its first argument should be ordered before the second.
    /// - Returns: A deferred publisher that emits the minimum element based on the specified predicate, or fails if an error is thrown.
    @_disfavoredOverload
    func tryMin(
        by areInIncreasingOrder: @escaping (WrappedPublisher.Output, WrappedPublisher.Output) throws(Failure) -> Bool
    ) -> Deferred<Publishers.TryComparison<WrappedPublisher>> where WrappedPublisher.Failure == Failure {
        deferredLift { $0.tryMin(by: areInIncreasingOrder) }
    }
}

// MARK: Applying Matching Criteria to Elements

public extension DeferredPublisherProtocol {
    /// Returns a publisher that emits a single true Boolean value if the upstream publisher contains an element equal to the specified output, or false otherwise.
    /// This version is deferred and will not subscribe to the upstream publisher until it is itself subscribed to.
    ///
    /// - Parameter output: The element to search for in the upstream publisher's elements.
    /// - Returns: A deferred publisher that emits a Boolean value indicating whether the specified output was found.
    @_disfavoredOverload
    func contains(
        _ output: WrappedPublisher.Output
    ) -> Deferred<Publishers.Contains<WrappedPublisher>> where WrappedPublisher.Failure == Failure {
        deferredLift { $0.contains(output) }
    }

    /// Returns a publisher that emits a single true Boolean value if the upstream publisher contains an element that satisfies the specified predicate, or false otherwise.
    /// This version is deferred and will not subscribe to the upstream publisher until it is itself subscribed to.
    ///
    /// - Parameter predicate: A closure that takes an element of the upstream publisher and returns a Boolean value.
    /// - Returns: A deferred publisher that emits a Boolean value indicating whether any element satisfied the predicate.
    @_disfavoredOverload
    func contains(
        where predicate: @escaping (WrappedPublisher.Output) -> Bool
    ) -> Deferred<Publishers.ContainsWhere<WrappedPublisher>> where WrappedPublisher.Failure == Failure {
        deferredLift { $0.contains(where: predicate) }
    }

    /// Returns a publisher that emits a single true Boolean value if the upstream publisher contains an element that satisfies the specified predicate, or false otherwise.
    /// This version is deferred and will not subscribe to the upstream publisher until it is itself subscribed to. The predicate can throw an error.
    ///
    /// - Parameter predicate: A closure that takes an element of the upstream publisher and returns a Boolean value, or throws an error.
    /// - Returns: A deferred publisher that emits a Boolean value indicating whether any element satisfied the predicate, or fails if an error is thrown.
    @_disfavoredOverload
    func tryContains(
        where predicate: @escaping (WrappedPublisher.Output) throws -> Bool
    ) -> Deferred<Publishers.TryContainsWhere<WrappedPublisher>> where WrappedPublisher.Failure == Error {
        deferredLift { $0.tryContains(where: predicate) }
    }

    /// Returns a publisher that emits a single true Boolean value if all elements received from the upstream publisher satisfy the specified predicate, or false otherwise.
    /// This version is deferred and will not subscribe to the upstream publisher until it is itself subscribed to.
    ///
    /// - Parameter predicate: A closure that takes an element of the upstream publisher and returns a Boolean value.
    /// - Returns: A deferred publisher that emits a Boolean value indicating whether all elements satisfied the predicate.
    @_disfavoredOverload
    func allSatisfy(
        _ predicate: @escaping (WrappedPublisher.Output) -> Bool
    ) -> Deferred<Publishers.AllSatisfy<WrappedPublisher>> where WrappedPublisher.Failure == Failure {
        deferredLift { $0.allSatisfy(predicate) }
    }

    /// Returns a publisher that emits a single true Boolean value if all elements received from the upstream publisher satisfy the specified predicate, or false otherwise.
    /// This version is deferred and will not subscribe to the upstream publisher until it is itself subscribed to. The predicate can throw an error.
    ///
    /// - Parameter predicate: A closure that takes an element of the upstream publisher and returns a Boolean value, or throws an error.
    /// - Returns: A deferred publisher that emits a Boolean value indicating whether all elements satisfied the predicate, or fails if an error is thrown.
    @_disfavoredOverload
    func tryAllSatisfy(
        _ predicate: @escaping (WrappedPublisher.Output) throws -> Bool
    ) -> Deferred<Publishers.TryAllSatisfy<WrappedPublisher>> where WrappedPublisher.Failure == Error {
        deferredLift { $0.tryAllSatisfy(predicate) }
    }
}

// MARK: Applying Sequence Operations to Elements

public extension DeferredPublisherProtocol {
    /// Drops elements from the upstream publisher until an element is received from another publisher.
    ///
    /// - Parameter publisher: A publisher that signals when to stop dropping elements.
    /// - Returns: A deferred publisher that drops the initial elements until an element is received from the provided publisher.
    @_disfavoredOverload
    func drop<P>(
        untilOutputFrom publisher: P
    ) -> Deferred<Publishers.DropUntilOutput<WrappedPublisher, P>> where P: Publisher, WrappedPublisher.Failure == P.Failure {
        deferredLift { $0.drop(untilOutputFrom: publisher) }
    }

    /// Drops the first `count` elements of the upstream publisher.
    ///
    /// - Parameter count: The number of elements to drop at the start of the upstream publisher’s output.
    /// - Returns: A deferred publisher that skips the first `count` elements and delivers all subsequent elements.
    @_disfavoredOverload
    func dropFirst(
        _ count: Int = 1
    ) -> Deferred<Publishers.Drop<WrappedPublisher>> where WrappedPublisher.Failure == Failure {
        deferredLift { $0.dropFirst(count) }
    }

    /// Drops elements from the upstream publisher, until an element fails to satisfy a predicate.
    ///
    /// - Parameter predicate: A closure that determines whether the elements should be dropped.
    /// - Returns: A deferred publisher that drops initial elements until an element fails the predicate test.
    @_disfavoredOverload
    func drop(
        while predicate: @escaping (WrappedPublisher.Output) -> Bool
    ) -> Deferred<Publishers.DropWhile<WrappedPublisher>> where WrappedPublisher.Failure == Failure {
        deferredLift { $0.drop(while: predicate) }
    }

    /// Drops elements from the upstream publisher, until an element fails to satisfy a throwing predicate.
    ///
    /// - Parameter predicate: A throwing closure that determines whether the elements should be dropped.
    /// - Returns: A deferred publisher that drops initial elements until an element fails the predicate test, throwing if the predicate throws.
    @_disfavoredOverload
    func tryDrop(
        while predicate: @escaping (WrappedPublisher.Output) throws(WrappedPublisher.Failure) -> Bool
    ) -> Deferred<Publishers.TryDropWhile<WrappedPublisher>> where WrappedPublisher.Failure == Failure {
        deferredLift { $0.tryDrop(while: predicate) }
    }

    /// Appends the specified elements to the output of this publisher.
    ///
    /// - Parameter elements: Elements to append at the end of the upstream publisher’s output.
    /// - Returns: A deferred publisher that appends the specified elements after the upstream publisher finishes.
    @_disfavoredOverload
    func append(
        _ elements: WrappedPublisher.Output...
    ) -> Deferred<Publishers.Concatenate<WrappedPublisher, Publishers.Sequence<[WrappedPublisher.Output], WrappedPublisher.Failure>>> where WrappedPublisher.Failure == Failure {
        deferredLift { $0.append(elements) }
    }

    /// Appends the specified sequence of elements to the output of this publisher.
    ///
    /// - Parameter elements: A sequence of elements to append at the end of the upstream publisher’s output.
    /// - Returns: A deferred publisher that appends the specified sequence of elements after the upstream publisher finishes.
    @_disfavoredOverload
    func append<S>(
        _ elements: S
    ) -> Deferred<Publishers.Concatenate<WrappedPublisher, Publishers.Sequence<S, WrappedPublisher.Failure>>> where S: Sequence, WrappedPublisher.Output == S.Element {
        deferredLift { $0.append(elements) }
    }

    /// Appends the elements of another publisher to this publisher.
    ///
    /// - Parameter publisher: Another publisher whose output is appended after the upstream publisher finishes.
    /// - Returns: A deferred publisher that appends the elements of another publisher after the upstream publisher finishes.
    @_disfavoredOverload
    func append<P>(
        _ publisher: P
    ) -> Deferred<Publishers.Concatenate<WrappedPublisher, P>> where P: Publisher, WrappedPublisher.Failure == P.Failure, WrappedPublisher.Output == P.Output {
        deferredLift { $0.append(publisher) }
    }

    /// Prepends the specified elements to the output of this publisher.
    ///
    /// - Parameter elements: Elements to prepend at the start of the upstream publisher’s output.
    /// - Returns: A deferred publisher that prepends the specified elements before the upstream publisher starts emitting.
    @_disfavoredOverload
    func prepend(
        _ elements: WrappedPublisher.Output...
    ) -> Deferred<Publishers.Concatenate<Publishers.Sequence<[WrappedPublisher.Output], WrappedPublisher.Failure>, WrappedPublisher>> where WrappedPublisher.Failure == Failure {
        deferredLift { $0.prepend(elements) }
    }

    /// Prepends the specified sequence of elements to the output of this publisher.
    ///
    /// - Parameter elements: A sequence of elements to prepend at the start of the upstream publisher’s output.
    /// - Returns: A deferred publisher that prepends the specified sequence of elements before the upstream publisher starts emitting.
    @_disfavoredOverload
    func prepend<S>(
        _ elements: S
    ) -> Deferred<Publishers.Concatenate<Publishers.Sequence<S, WrappedPublisher.Failure>, WrappedPublisher>> where S: Sequence, WrappedPublisher.Output == S.Element {
        deferredLift { $0.prepend(elements) }
    }

    /// Prepends the elements of another publisher to this publisher.
    ///
    /// - Parameter publisher: Another publisher whose output is prepended before the upstream publisher starts emitting.
    /// - Returns: A deferred publisher that prepends the elements of another publisher before the upstream publisher starts emitting.
    @_disfavoredOverload
    func prepend<P>(
        _ publisher: P
    ) -> Deferred<Publishers.Concatenate<P, WrappedPublisher>> where P: Publisher, WrappedPublisher.Failure == P.Failure, WrappedPublisher.Output == P.Output {
        deferredLift { $0.prepend(publisher) }
    }

    /// Emits a specified number of elements from the start, then finishes.
    ///
    /// - Parameter maxLength: The maximum number of elements to emit from the start.
    /// - Returns: A deferred publisher that emits a specified number of elements from the upstream publisher’s output, then finishes.
    @_disfavoredOverload
    func prefix(
        _ maxLength: Int
    ) -> Deferred<Publishers.Output<WrappedPublisher>> where WrappedPublisher.Failure == Failure {
        deferredLift { $0.prefix(maxLength) }
    }

    /// Emits elements from the upstream publisher until an element fails to satisfy a predicate.
    ///
    /// - Parameter predicate: A closure that determines whether the elements should be emitted.
    /// - Returns: A deferred publisher that emits initial elements while they satisfy the predicate test, then finishes.
    @_disfavoredOverload
    func prefix(
        while predicate: @escaping (WrappedPublisher.Output) -> Bool
    ) -> Deferred<Publishers.PrefixWhile<WrappedPublisher>> where WrappedPublisher.Failure == Failure {
        deferredLift { $0.prefix(while: predicate) }
    }

    /// Emits elements from the upstream publisher until an element fails to satisfy a throwing predicate.
    ///
    /// - Parameter predicate: A throwing closure that determines whether the elements should be emitted.
    /// - Returns: A deferred publisher that emits initial elements while they satisfy the predicate test, throwing if the predicate throws, then finishes.
    @_disfavoredOverload
    func tryPrefix(
        while predicate: @escaping (WrappedPublisher.Output) throws(WrappedPublisher.Failure) -> Bool
    ) -> Deferred<Publishers.TryPrefixWhile<WrappedPublisher>> where WrappedPublisher.Failure == Failure {
        deferredLift { $0.tryPrefix(while: predicate) }
    }

    /// Returns a publisher that republishes elements until the specified publisher emits an element.
    ///
    /// - Parameters:
    ///   - publisher: A publisher that, when it emits an element, causes the prefix publisher to finish.
    ///
    /// - Returns: A `Deferred` publisher that wraps a `Publishers.PrefixUntilOutput` instance.
    @_disfavoredOverload
    func prefix<P>(
        untilOutputFrom publisher: P
    ) -> Deferred<Publishers.PrefixUntilOutput<WrappedPublisher, P>> where P: Publisher {
        deferredLift { $0.prefix(untilOutputFrom: publisher) }
    }
}

// MARK: Selecting Specific Elements

public extension DeferredPublisherProtocol {
    /// Returns a publisher that emits the first element of the upstream publisher,
    /// if it exists.
    @_disfavoredOverload
    func first() -> Deferred<Publishers.First<WrappedPublisher>> where WrappedPublisher.Failure == Failure {
        deferredLift { $0.first() }
    }

    /// Returns a publisher that emits the first element of the upstream publisher
    /// that satisfies the predicate.
    @_disfavoredOverload
    func first(
        where predicate: @escaping (WrappedPublisher.Output) -> Bool
    ) -> Deferred<Publishers.FirstWhere<WrappedPublisher>> where WrappedPublisher.Failure == Failure {
        deferredLift { $0.first(where: predicate) }
    }

    /// Returns a publisher that emits the first element of the upstream publisher that
    /// satisfies the predicate, throwing an error if the predicate throws.
    @_disfavoredOverload
    func tryFirst(
        where predicate: @escaping (WrappedPublisher.Output) throws(WrappedPublisher.Failure) -> Bool
    ) -> Deferred<Publishers.TryFirstWhere<WrappedPublisher>> where WrappedPublisher.Failure == Failure {
        deferredLift { $0.tryFirst(where: predicate) }
    }

    /// Returns a publisher that emits the last element of the upstream publisher, if
    /// it exists.
    @_disfavoredOverload
    func last() -> Deferred<Publishers.Last<WrappedPublisher>> where WrappedPublisher.Failure == Failure {
        deferredLift { $0.last() }
    }

    /// Returns a publisher that emits the last element of the upstream publisher that
    /// satisfies the predicate.
    @_disfavoredOverload
    func last(
        where predicate: @escaping (WrappedPublisher.Output) -> Bool
    ) -> Deferred<Publishers.LastWhere<WrappedPublisher>> where WrappedPublisher.Failure == Failure {
        deferredLift { $0.last(where: predicate) }
    }

    /// Returns a publisher that emits the last element of the upstream publisher that
    /// satisfies the predicate, throwing an error if the predicate throws.
    @_disfavoredOverload
    func tryLast(
        where predicate: @escaping (WrappedPublisher.Output) throws(WrappedPublisher.Failure) -> Bool
    ) -> Deferred<Publishers.TryLastWhere<WrappedPublisher>> where WrappedPublisher.Failure == Failure {
        deferredLift { $0.tryLast(where: predicate) }
    }

    /// Returns a publisher that emits the element at the specified index of the
    /// upstream publisher.
    @_disfavoredOverload
    func output(
        at index: Int
    ) -> Deferred<Publishers.Output<WrappedPublisher>> where WrappedPublisher.Failure == Failure {
        deferredLift { $0.output(at: index) }
    }

    /// Returns a publisher that emits the elements at the specified range of indices
    /// from the upstream publisher.
    @_disfavoredOverload
    func output<R>(
        in range: R
    ) -> Deferred<Publishers.Output<WrappedPublisher>> where WrappedPublisher.Failure == Failure, R: RangeExpression, R.Bound == Int {
        deferredLift { $0.output(in: range) }
    }
}

// MARK: Republishing Elements by Subscribing to New Publishers

public extension DeferredPublisherProtocol {
    @_disfavoredOverload
    func flatMap<T, P>(
        maxPublishers: Subscribers.Demand = .unlimited,
        _ transform: @escaping (WrappedPublisher.Output) -> P
    ) -> Deferred<Publishers.FlatMap<P, WrappedPublisher>> where
        T == P.Output,
        P: Publisher,
        WrappedPublisher.Failure == P.Failure
    {
        deferredLift { $0.flatMap(maxPublishers: maxPublishers, transform) }
    }

    @_disfavoredOverload
    func flatMap<P>(
        maxPublishers: Subscribers.Demand = .unlimited,
        _ transform: @escaping (WrappedPublisher.Output) -> P
    ) -> Deferred<Publishers.FlatMap<P, Publishers.SetFailureType<WrappedPublisher, P.Failure>>> where
        P: Publisher
    {
        deferredLift { $0.flatMap(maxPublishers: maxPublishers, transform) }
    }

    @_disfavoredOverload
    func flatMap<P>(
        maxPublishers: Subscribers.Demand = .unlimited,
        _ transform: @escaping (WrappedPublisher.Output) -> P
    ) -> Deferred<Publishers.FlatMap<P, WrappedPublisher>> where
        P: Publisher,
        P.Failure == Never
    {
        deferredLift { $0.flatMap(maxPublishers: maxPublishers, transform) }
    }

    @_disfavoredOverload
    func flatMap<P>(
        maxPublishers: Subscribers.Demand = .unlimited,
        _ transform: @escaping (WrappedPublisher.Output) -> P
    ) -> Deferred<Publishers.FlatMap<Publishers.SetFailureType<P, Failure>, WrappedPublisher>> where
        P: Publisher,
        P.Failure == Never
    {
        deferredLift { $0.flatMap(maxPublishers: maxPublishers, transform) }
    }

    @_disfavoredOverload
    func switchToLatest() -> Deferred<Publishers.SwitchToLatest<Output, WrappedPublisher>> where
        Output: Publisher,
        Output.Failure == Failure
    {
        deferredLift { $0.switchToLatest() }
    }

    @_disfavoredOverload
    func switchToLatest() -> Deferred<Publishers.SwitchToLatest<Output, Publishers.SetFailureType<WrappedPublisher, Output.Failure>>> where
        Output: Publisher,
        Failure == Never
    {
        deferredLift { $0.switchToLatest() }
    }

    @_disfavoredOverload
    func switchToLatest() -> Deferred<Publishers.SwitchToLatest<Publishers.SetFailureType<Output, Failure>, Publishers.Map<WrappedPublisher, Publishers.SetFailureType<WrappedPublisher.Output, Failure>>>> where
        Output: Publisher,
        Output.Failure == Never
    {
        deferredLift { $0.switchToLatest() }
    }

    @_disfavoredOverload
    func switchToLatest() -> Deferred<Publishers.SwitchToLatest<Output, WrappedPublisher>> where
        Output: Publisher,
        Failure == Never,
        Output.Failure == Never
    {
        deferredLift { $0.switchToLatest() }
    }
}

// MARK: Encoding and Decoding

public extension DeferredPublisherProtocol {
    /// Encodes the elements of the publisher into a specific format using the provided encoder.
    ///
    /// - Parameter encoder: The encoder to use for encoding the elements of the publisher.
    /// - Returns: A `Deferred` publisher that wraps a `Publishers.Encode` operator.
    @_disfavoredOverload
    func encode<Coder>(encoder: Coder) -> Deferred<Publishers.Encode<WrappedPublisher, Coder>> where Coder: TopLevelEncoder {
        deferredLift { $0.encode(encoder: encoder) }
    }

    /// Decodes the elements of the publisher from a specific format using the provided decoder.
    ///
    /// - Parameters:
    ///   - type: The type to decode the elements into.
    ///   - decoder: The decoder to use for decoding the elements of the publisher.
    /// - Returns: A `Deferred` publisher that wraps a `Publishers.Decode` operator.
    @_disfavoredOverload
    func decode<Item, Coder>(
        type: Item.Type,
        decoder: Coder
    ) -> Deferred<Publishers.Decode<WrappedPublisher, Item, Coder>> where Item: Decodable, Coder: TopLevelDecoder, WrappedPublisher.Output == Coder.Input {
        deferredLift { $0.decode(type: type, decoder: decoder) }
    }
}

// MARK: Handling Errors

public extension DeferredPublisherProtocol {
    @_disfavoredOverload
    func `catch`<P>(
        _ handler: @escaping (WrappedPublisher.Failure) -> P
    ) -> Deferred<Publishers.Catch<WrappedPublisher, P>> where P: Publisher, WrappedPublisher.Output == P.Output {
        deferredLift { $0.catch(handler) }
    }
}

// MARK: Controlling Timing

public extension DeferredPublisherProtocol {
    /// Measures the interval between elements emitted by the publisher, using the specified scheduler and options.
    ///
    /// - Parameters:
    ///   - scheduler: The scheduler to use for measuring the interval.
    ///   - options: Optional scheduler-specific options.
    /// - Returns: A `Deferred` publisher that wraps a `Publishers.MeasureInterval` operator.
    @_disfavoredOverload
    func measureInterval<S>(
        using scheduler: S,
        options: S.SchedulerOptions? = nil
    ) -> Deferred<Publishers.MeasureInterval<WrappedPublisher, S>> where S: Scheduler {
        deferredLift { $0.measureInterval(using: scheduler, options: options) }
    }

    /// Debounces the publisher, delaying delivery of elements until a specified time interval has passed with no new elements.
    ///
    /// - Parameters:
    ///   - dueTime: The time interval to wait for new elements before delivering the last received element.
    ///   - scheduler: The scheduler to use for managing the due time.
    ///   - options: Optional scheduler-specific options.
    /// - Returns: A `Deferred` publisher that wraps a `Publishers.Debounce` operator.
    @_disfavoredOverload
    func debounce<S>(
        for dueTime: S.SchedulerTimeType.Stride,
        scheduler: S,
        options: S.SchedulerOptions? = nil
    ) -> Deferred<Publishers.Debounce<WrappedPublisher, S>> where S: Scheduler {
        deferredLift { $0.debounce(for: dueTime, scheduler: scheduler, options: options) }
    }

    /// Delays the delivery of elements by a specified time interval.
    ///
    /// - Parameters:
    ///   - interval: The time interval to delay the delivery of each element.
    ///   - tolerance: An optional amount of variability, in seconds, that is acceptable either side of the specified interval.
    ///   - scheduler: The scheduler to use for managing the delay.
    ///   - options: Optional scheduler-specific options.
    /// - Returns: A `Deferred` publisher that wraps a `Publishers.Delay` operator.
    @_disfavoredOverload
    func delay<S>(
        for interval: S.SchedulerTimeType.Stride,
        tolerance: S.SchedulerTimeType.Stride? = nil,
        scheduler: S,
        options: S.SchedulerOptions? = nil
    ) -> Deferred<Publishers.Delay<WrappedPublisher, S>> where S: Scheduler {
        deferredLift { $0.delay(for: interval, tolerance: tolerance, scheduler: scheduler, options: options) }
    }

    /// Throttles the publisher, ensuring that no more than one element is emitted in a specified time interval.
    ///
    /// - Parameters:
    ///   - interval: The maximum interval at which to emit elements.
    ///   - scheduler: The scheduler to use for managing the throttle interval.
    ///   - latest: A Boolean value indicating whether the latest element should be emitted if multiple elements are received during the interval.
    /// - Returns: A `Deferred` publisher that wraps a `Publishers.Throttle` operator.
    @_disfavoredOverload
    func throttle<S>(
        for interval: S.SchedulerTimeType.Stride,
        scheduler: S,
        latest: Bool
    ) -> Deferred<Publishers.Throttle<WrappedPublisher, S>> where S: Scheduler {
        deferredLift { $0.throttle(for: interval, scheduler: scheduler, latest: latest) }
    }

    /// Terminates the publisher if it does not receive an element within a specified time interval.
    ///
    /// - Parameters:
    ///   - interval: The maximum interval to wait for an element before terminating the publisher.
    ///   - scheduler: The scheduler to use for managing the timeout interval.
    ///   - options: Optional scheduler-specific options.
    ///   - customError: A closure that returns a custom error to emit if the timeout occurs.
    /// - Returns: A `Deferred` publisher that wraps a `Publishers.Timeout` operator.
    @_disfavoredOverload
    func timeout<S>(
        _ interval: S.SchedulerTimeType.Stride,
        scheduler: S,
        options: S.SchedulerOptions? = nil,
        customError: (() -> WrappedPublisher.Failure)? = nil
    ) -> Deferred<Publishers.Timeout<WrappedPublisher, S>> where S: Scheduler {
        deferredLift { $0.timeout(interval, scheduler: scheduler, options: options, customError: customError) }
    }
}

// MARK: Specifying Schedulers

public extension DeferredPublisherProtocol {
    /// Subscribes to the deferred publisher on a specified scheduler.
    ///
    /// - Parameters:
    ///   - scheduler: The scheduler on which to subscribe the publisher.
    ///   - options: Scheduler options used during subscription, such as `SchedulerOptions.Tracking`.
    /// - Returns: A `Deferred` publisher that subscribes on the specified scheduler.
    @_disfavoredOverload
    func subscribe<S: Scheduler>(
        on scheduler: S,
        options: S.SchedulerOptions? = nil
    ) -> Deferred<Publishers.SubscribeOn<WrappedPublisher, S>> where WrappedPublisher.Failure == Failure {
        // Lift the deferred publisher and apply the `subscribe(on:options:)` transformation.
        deferredLift { $0.subscribe(on: scheduler, options: options) }
    }

    /// Receives output from the deferred publisher on a specified scheduler.
    ///
    /// - Parameters:
    ///   - scheduler: The scheduler on which to receive output from the publisher.
    ///   - options: Scheduler options used during reception, such as `SchedulerOptions.Tracking`.
    /// - Returns: A `Deferred` publisher that receives output on the specified scheduler.
    @_disfavoredOverload
    func receive<S: Scheduler>(
        on scheduler: S,
        options: S.SchedulerOptions? = nil
    ) -> Deferred<Publishers.ReceiveOn<WrappedPublisher, S>> where WrappedPublisher.Failure == Failure {
        // Lift the deferred publisher and apply the `receive(on:options:)` transformation.
        deferredLift { $0.receive(on: scheduler, options: options) }
    }

    /// Configures the publisher to receive values on the main thread using `UIScheduler`.
    /// `UIScheduler` will receive synchronously on the main thread if the upstream publisher
    /// emits on the main thread, otherwise it will dispatch to main asynchronously.
    ///
    /// - Returns: A `Publishers.ReceiveOn` instance that receives values on the main UI thread.
    @_disfavoredOverload
    func receiveOnMain() -> Deferred<Publishers.ReceiveOn<WrappedPublisher, UIScheduler>> where WrappedPublisher.Failure == Failure {
        deferredLift { $0.receive(on: UIScheduler.shared) }
    }

    /// Configures the publisher to receive values on the main thread using `DispatchQueue`.
    /// Unlike `receiveOnMain`, this will always dispatch asynchronously to the main queue,
    /// even if the upstream publisher emits on the main thread.
    ///
    /// - Returns: A `Publishers.ReceiveOn` instance that receives values on the main thread.
    @_disfavoredOverload
    func receiveOnMainAsync() -> Deferred<Publishers.ReceiveOn<WrappedPublisher, DispatchQueue>> where WrappedPublisher.Failure == Failure {
        deferredLift { $0.receive(on: DispatchQueue.main) }
    }

    /// Configures the publisher to receive values on the main run loop using `RunLoop`.
    /// This will only schedule the publisher to receive events when the current RunLoop
    /// has finished processing (e.g. it will wait until the user finishes scrolling.)
    ///
    /// - Returns: A `Publishers.ReceiveOn` instance that receives values on the main run loop.
    @_disfavoredOverload
    func receiveOnMainRunLoop() -> Deferred<Publishers.ReceiveOn<WrappedPublisher, RunLoop>> where WrappedPublisher.Failure == Failure {
        deferredLift { $0.receive(on: RunLoop.main) }
    }
}

// MARK: Debugging

public extension DeferredPublisherProtocol {
    func handleEvents(
        receiveSubscription: ((any Subscription) -> Void)? = nil,
        receiveOutput: ((WrappedPublisher.Output) -> Void)? = nil,
        receiveCompletion: ((Subscribers.Completion<WrappedPublisher.Failure>) -> Void)? = nil,
        receiveCancel: (() -> Void)? = nil,
        receiveRequest: ((Subscribers.Demand) -> Void)? = nil
    ) -> Deferred<Publishers.HandleEvents<WrappedPublisher>> where WrappedPublisher: Publisher {
        deferredLift {
            $0.handleEvents(
                receiveSubscription: receiveSubscription,
                receiveOutput: receiveOutput,
                receiveCompletion: receiveCompletion,
                receiveCancel: receiveCancel,
                receiveRequest: receiveRequest
            )
        }
    }
}
