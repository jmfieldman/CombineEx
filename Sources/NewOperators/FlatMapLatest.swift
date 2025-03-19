//
//  FlatMapLatest.swift
//  Copyright © 2025 Jason Fieldman.
//

import Combine

public extension Publisher {
    func flatMapLatest<P: Publisher>(
        _ transform: @escaping (Output) -> P
    ) -> Publishers.SwitchToLatest<P, Publishers.Map<Self, P>> {
        map(transform).switchToLatest()
    }
}

public extension DeferredPublisherProtocol {
    @_disfavoredOverload
    func flatMapLatest<P: Publisher>(
        _ transform: @escaping (WrappedPublisher.Output) -> P
    ) -> Deferred<Publishers.SwitchToLatest<P, Publishers.Map<WrappedPublisher, P>>> where WrappedPublisher: Publisher {
        deferredLift { $0.map(transform).switchToLatest() }
    }
}
