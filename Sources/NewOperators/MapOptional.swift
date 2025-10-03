//
//  MapOptional.swift
//  Copyright © 2025 Jason Fieldman.
//

import Combine

public extension Publisher {
    /// Maps the output of this publisher to an optional version of itself.
    ///
    /// - Returns: A publisher that emits `Output?` values.
    func mapOptional() -> Publishers.Map<Self, Output?> {
        map { $0 }
    }
}

public extension DeferredPublisherProtocol {
    /// Maps the output of this publisher to an optional version of itself.
    ///
    /// - Returns: A deferred publisher that emits `Output?` values.
    @_disfavoredOverload
    func mapOptional() -> Deferred<Publishers.Map<WrappedPublisher, WrappedPublisher.Output?>> where WrappedPublisher: Publisher {
        deferredLift { $0.mapOptional() }
    }
}

public extension DeferredFutureProtocol {
    /// Maps the output of this publisher to an optional version of itself.
    ///
    /// - Returns: A deferred future that produces `Output?` values.
    @_disfavoredOverload
    func mapOptional() -> DeferredFuture<Output?, Failure> {
        map { $0 }
    }
}
