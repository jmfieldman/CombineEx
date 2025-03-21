//
//  FlatMapLatest.swift
//  Copyright © 2025 Jason Fieldman.
//

import Combine

public extension Publisher {
    /// Transforms each element of the publisher into a new publisher and emits elements from the latest inner publisher.
    ///
    /// - Parameter transform: A closure that takes an element of the current publisher and returns a new publisher.
    /// - Returns: A `Publishers.SwitchToLatest` instance that emits elements from the latest inner publisher.
    func flatMapLatest<P: Publisher>(
        _ transform: @escaping (Output) -> P
    ) -> Publishers.SwitchToLatest<P, Publishers.Map<Self, P>> {
        map(transform).switchToLatest()
    }
}

public extension DeferredPublisherProtocol {
    /// Transforms each element of the deferred publisher into a new publisher and emits elements from the latest inner publisher.
    ///
    /// - Parameter transform: A closure that takes an element of the wrapped publisher and returns a new publisher.
    /// - Returns: A `Deferred<Publishers.SwitchToLatest>` instance that emits elements from the latest inner publisher.
    @_disfavoredOverload
    func flatMapLatest<P: Publisher>(
        _ transform: @escaping (WrappedPublisher.Output) -> P
    ) -> Deferred<Publishers.SwitchToLatest<P, Publishers.Map<WrappedPublisher, P>>> where WrappedPublisher: Publisher {
        deferredLift { $0.map(transform).switchToLatest() }
    }
}
