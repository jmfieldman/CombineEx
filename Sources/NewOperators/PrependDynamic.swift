//
//  PrependDynamic.swift
//  Copyright © 2025 Jason Fieldman.
//

import Combine

public extension Publishers {
    struct PrependDynamic<Upstream: Publisher>: Publisher {
        public typealias Output = Upstream.Output
        public typealias Failure = Upstream.Failure

        let upstream: Upstream
        let initialValue: () -> Output

        public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
            upstream.prepend(initialValue()).subscribe(subscriber)
        }
    }
}

public extension Publisher {
    func prependDynamic(
        _ initialValue: @escaping () -> Output
    ) -> Publishers.PrependDynamic<Self> {
        Publishers.PrependDynamic(upstream: self, initialValue: initialValue)
    }
}
