//
//  MapOnMainActor.swift
//  Copyright © 2025 Jason Fieldman.
//

import Combine
import Foundation

public extension Publisher {
    /// Transforms the output of the upstream publisher using the provided closure on the main actor.
    ///
    /// - Parameter transform: A closure that takes the upstream publisher's output and returns a new value.
    /// - Returns: A publisher that emits the transformed values.
    func mapOnMainActor<NewOutput>(
        _ transform: @escaping @MainActor (Output) -> NewOutput
    ) -> Publishers.SwitchToLatest<AnyDeferredFuture<NewOutput, Self.Failure>, Publishers.Map<Self, AnyDeferredFuture<NewOutput, Self.Failure>>> {
        map { incomingValue -> AnyDeferredFuture<NewOutput, Failure> in
            AnyDeferredFuture<NewOutput, Failure>.withTaskOnMainActor {
                transform(incomingValue)
            }
        }
        .switchToLatest()
    }
}

public extension DeferredPublisherProtocol {
    /// Transforms the output of the upstream publisher using the provided closure on the main actor.
    ///
    /// - Parameter transform: A closure that takes the upstream publisher's output and returns a new value.
    /// - Returns: A deferred publisher that emits the transformed values.
    @_disfavoredOverload
    func mapOnMainActor<NewOutput>(
        _ transform: @escaping @MainActor (WrappedPublisher.Output) -> NewOutput
    ) -> Deferred<Publishers.SwitchToLatest<AnyDeferredFuture<NewOutput, WrappedPublisher.Failure>, Publishers.Map<WrappedPublisher, AnyDeferredFuture<NewOutput, WrappedPublisher.Failure>>>> {
        deferredLift { $0.mapOnMainActor(transform) }
    }
}

public extension DeferredFutureProtocol {
    /// Transforms the output of this `DeferredFuture` using a given transformation function on the main actor.
    ///
    /// - Parameter transform: The transformation function to apply to the output.
    /// - Returns: A new `DeferredFuture` that contains the transformed output.
    @_disfavoredOverload
    func mapOnMainActor<NewOutput>(
        _ transform: @escaping @MainActor (Output) -> NewOutput
    ) -> DeferredFuture<NewOutput, Failure> {
        futureLiftOutput { outerOutput, innerPromise in
            DispatchQueue.main.async {
                innerPromise(.success(transform(outerOutput)))
            }
        }
    }
}
