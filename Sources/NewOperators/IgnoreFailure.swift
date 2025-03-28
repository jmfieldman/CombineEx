//
//  IgnoreFailure.swift
//  Copyright © 2024 Jason Fieldman.
//

import Combine

public extension Publisher {
    /// Convenience wrapper to ignore failures by replacing them with an empty publisher.
    ///
    /// - Returns: A `Publishers.Catch<Self, Empty<Output, Failure>>` instance that ignores failures.
    func ignoreFailure() -> Publishers.Catch<Self, Empty<Output, Failure>> {
        self.catch { _ in
            Empty(outputType: Output.self, failureType: Failure.self)
        }
    }
}

public extension DeferredPublisherProtocol {
    /// Convenience wrapper to ignore failures for a deferred publisher by replacing them with an empty publisher.
    ///
    /// - Returns: A `Deferred<Publishers.Catch<WrappedPublisher, Empty<Output, Failure>>>` instance that ignores failures.
    @_disfavoredOverload
    func ignoreFailure() -> Deferred<Publishers.Catch<WrappedPublisher, Empty<Output, Failure>>> where WrappedPublisher: Publisher, WrappedPublisher.Failure == Failure {
        deferredLift { $0.ignoreFailure() }
    }
}
