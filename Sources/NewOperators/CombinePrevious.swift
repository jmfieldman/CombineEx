//
//  CombinePrevious.swift
//  Copyright © 2024 Jason Fieldman.
//

import Combine

public extension Publisher {
    /// Combines each element with the previous one, returning a tuple of `(previousValue, currentValue)`.
    /// The first element will not have a previous value and is omitted from the output.
    ///
    /// - Returns: A publisher that emits tuples of `(previousValue, currentValue)`.
    func combinePrevious() -> Publishers.CompactMap<Publishers.Scan<Self, (Output?, Output)?>, (Output?, Output)> {
        scan((Output?, Output)?.none) { ($0?.1, $1) }
            .compactMap { $0 }
    }

    /// Combines each element with the previous one, using an initial value for the first element's previous value.
    ///
    /// - Parameter initialValue: The initial value to use for the first element's previous value.
    /// - Returns: A publisher that emits tuples of `(previousValue, currentValue)`.
    func combinePrevious(
        _ initialValue: Output
    ) -> Publishers.Scan<Self, (Output, Output)> {
        scan((initialValue, initialValue)) { ($0.1, $1) }
    }

    /// Combines each element with the previous one for optional types, returning a tuple of `(previousValue, currentValue)`.
    /// The first element will not have a previous value and is omitted from the output.
    ///
    /// - Returns: A publisher that emits tuples of `(previousValue, currentValue)`.
    func combinePrevious<T>() -> Publishers.CompactMap<Publishers.Scan<Self, (Output, Output)?>, (Output, Output)> where Output == T? {
        scan((Output, Output)?.none) { ($0?.1, $1) }
            .compactMap { $0 }
    }
}

public extension DeferredPublisherProtocol {
    /// Combines each element with the previous one, returning a tuple of `(previousValue, currentValue)`.
    /// The first element will not have a previous value and is omitted from the output.
    ///
    /// - Returns: A `Deferred` publisher that emits tuples of `(previousValue, currentValue)`.
    @_disfavoredOverload
    func combinePrevious() -> Deferred<Publishers.CompactMap<Publishers.Scan<WrappedPublisher, (Output?, Output)?>, (Output?, Output)>> where WrappedPublisher.Output == Output, WrappedPublisher.Failure == Failure {
        deferredLift { $0.combinePrevious() }
    }

    /// Combines each element with the previous one, using an initial value for the first element's previous value.
    ///
    /// - Parameter initialValue: The initial value to use for the first element's previous value.
    /// - Returns: A `Deferred` publisher that emits tuples of `(previousValue, currentValue)`.
    @_disfavoredOverload
    func combinePrevious(
        _ initialValue: WrappedPublisher.Output
    ) -> Deferred<Publishers.Scan<WrappedPublisher, (WrappedPublisher.Output, WrappedPublisher.Output)>> where WrappedPublisher.Failure == Failure {
        deferredLift { $0.combinePrevious(initialValue) }
    }

    /// Combines each element with the previous one for optional types, returning a tuple of `(previousValue, currentValue)`.
    /// The first element will not have a previous value and is omitted from the output.
    ///
    /// - Returns: A `Deferred` publisher that emits tuples of `(previousValue, currentValue)`.
    @_disfavoredOverload
    func combinePrevious<T>() -> Deferred<Publishers.CompactMap<Publishers.Scan<WrappedPublisher, (WrappedPublisher.Output, WrappedPublisher.Output)?>, (WrappedPublisher.Output, WrappedPublisher.Output)>> where WrappedPublisher.Failure == Failure, WrappedPublisher.Output == T? {
        deferredLift { $0.combinePrevious() }
    }
}
