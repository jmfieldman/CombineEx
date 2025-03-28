//
//  PromoteFailure.swift
//  Copyright © 2024 Jason Fieldman.
//

import Combine

public extension Publisher where Failure == Never {
    /// Wraps `setFailureType(to:)` in a way that forces the type checker to
    /// imply what the desired new failure type will be.
    ///
    /// - Parameter NewFailure: The new failure type to set for the publisher.
    /// - Returns: A `Publishers.SetFailureType<Self, NewFailure>` instance.
    func promoteFailure<NewFailure>() -> Publishers.SetFailureType<Self, NewFailure> {
        setFailureType(to: NewFailure.self)
    }
}

public extension DeferredPublisherProtocol where Failure == Never {
    /// Wraps `setFailureType(to:)` for a deferred publisher, allowing the type checker to
    /// imply what the desired new failure type will be.
    ///
    /// - Parameter NewFailure: The new failure type to set for the deferred publisher.
    /// - Returns: A `Deferred<Publishers.SetFailureType<WrappedPublisher, NewFailure>>` instance.
    @_disfavoredOverload
    func promoteFailure<NewFailure>() -> Deferred<Publishers.SetFailureType<WrappedPublisher, NewFailure>> where WrappedPublisher: Publisher {
        deferredLift { $0.setFailureType(to: NewFailure.self) }
    }
}

public extension DeferredFutureProtocol where Failure == Never {
    /// Wraps `setFailureType(to:)` for a deferred future, allowing the type checker to
    /// imply what the desired new failure type will be.
    ///
    /// - Parameter NewFailure: The new failure type to set for the deferred future.
    /// - Returns: A `DeferredFuture<Output, NewFailure>` instance.
    @_disfavoredOverload
    func promoteFailure<NewFailure>() -> DeferredFuture<Output, NewFailure> {
        // `futureLiftFailure` passes successes through implicitly; the parameter
        // block is only used to handle failures (which will never occur since
        // our Failure type is `Never`.)
        futureLiftFailure { _, _ in }
    }
}
