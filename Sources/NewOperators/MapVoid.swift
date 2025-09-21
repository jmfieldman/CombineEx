//
//  MapVoid.swift
//  Copyright © 2025 Jason Fieldman.
//

import Combine

public extension Publisher {
    /// Maps the output of this publisher to `Void`, discarding the original value.
    ///
    /// - Returns: A publisher that emits `Void` values.
    func mapVoid() -> Publishers.Map<Self, Void> {
        map { _ in () }
    }
}

public extension DeferredPublisherProtocol {
    /// Maps the output of this deferred publisher to `Void`, discarding the original value.
    ///
    /// - Returns: A deferred publisher that emits `Void` values.
    @_disfavoredOverload
    func mapVoid() -> Deferred<Publishers.Map<WrappedPublisher, Void>> where WrappedPublisher: Publisher {
        deferredLift { $0.mapVoid() }
    }
}

public extension DeferredFutureProtocol {
    /// Maps the output of this deferred future to `Void`, discarding the original value.
    ///
    /// - Returns: A deferred future that produces `Void` values.
    @_disfavoredOverload
    func mapVoid() -> DeferredFuture<Void, Failure> {
        futureLiftOutput { _, innerPromise in
            innerPromise(.success(()))
        }
    }
}
