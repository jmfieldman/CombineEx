//
//  AttemptMap.swift
//  Copyright © 2025 Jason Fieldman.
//

import Combine

public extension Publishers {
    struct AttemptMap<Upstream: Publisher, NewOutput>: Publisher {
        public typealias Output = NewOutput
        public typealias Failure = Upstream.Failure

        let upstream: Upstream
        let transform: (Upstream.Output) -> Result<NewOutput, Failure>

        public func receive<S: Subscriber>(subscriber: S) where S.Input == NewOutput, S.Failure == Failure {
            let subscription = AttemptMapSubscription(transform: transform, subscriber: subscriber)
            upstream.subscribe(subscription)
        }
    }
}

private extension Publishers.AttemptMap {
    private final class AttemptMapSubscription<S: Subscriber>: Subscriber where S.Input == NewOutput, S.Failure == Upstream.Failure {
        typealias Input = Upstream.Output
        typealias Failure = Upstream.Failure

        let transform: ((Upstream.Output) -> Result<NewOutput, Upstream.Failure>)?
        let subscriber: S?

        init(transform: @escaping (Upstream.Output) -> Result<NewOutput, Upstream.Failure>, subscriber: S) {
            self.transform = transform
            self.subscriber = subscriber
        }

        func receive(subscription: Subscription) {
            subscriber?.receive(subscription: subscription)
        }

        func receive(completion: Subscribers.Completion<Upstream.Failure>) {
            subscriber?.receive(completion: completion)
        }

        func receive(_ input: Upstream.Output) -> Subscribers.Demand {
            if let transform {
                switch transform(input) {
                case let .success(value):
                    _ = subscriber?.receive(value)
                case let .failure(error):
                    subscriber?.receive(completion: .failure(error))
                }
            }
            return .unlimited
        }
    }
}

public extension Publisher {
    func attemptMap<NewOutput>(
        _ transform: @escaping (Output) -> Result<NewOutput, Failure>
    ) -> Publishers.AttemptMap<Self, NewOutput> {
        Publishers.AttemptMap(upstream: self, transform: transform)
    }
}
