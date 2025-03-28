//
//  PrependDynamic.swift
//  Copyright © 2024 Jason Fieldman.
//

import Combine

public extension Publishers {
    /// A publisher that prepends a dynamically generated initial value to the output of an upstream publisher.
    struct PrependDynamic<Upstream: Publisher>: Publisher {
        public typealias Output = Upstream.Output
        public typealias Failure = Upstream.Failure

        let upstream: Upstream
        let initialValue: () -> Output

        /// Attaches a subscriber to the publisher by first emitting the initial value and then subscribing to the upstream publisher.
        ///
        /// - Parameter subscriber: The subscriber to attach to this publisher.
        public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
            upstream.prepend(initialValue()).subscribe(subscriber)
        }
    }
}

public extension Publisher {
    /// Prepends a dynamically generated initial value to the output of this publisher.
    ///
    /// - Parameter initialValue: A closure that generates the initial value to prepend.
    /// - Returns: A new publisher that emits the initial value followed by values from the upstream publisher.
    func prependDynamic(
        _ initialValue: @escaping () -> Output
    ) -> Publishers.PrependDynamic<Self> {
        Publishers.PrependDynamic(upstream: self, initialValue: initialValue)
    }
}

public extension DeferredPublisherProtocol {
    /// Prepends a dynamically generated initial value to the output of this publisher.
    ///
    /// - Parameter initialValue: A closure that generates the initial value to prepend.
    /// - Returns: A new publisher that emits the initial value followed by values from the upstream publisher.
    @_disfavoredOverload
    func prependDynamic(
        _ initialValue: @escaping () -> WrappedPublisher.Output
    ) -> Deferred<Publishers.PrependDynamic<WrappedPublisher>> where WrappedPublisher.Failure == Failure {
        deferredLift { $0.prependDynamic(initialValue) }
    }
}
