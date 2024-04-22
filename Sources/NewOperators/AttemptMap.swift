//
//  AttemptMap.swift
//  Copyright © 2023 Jason Fieldman.
//

import Combine

public extension Publishers {
  struct AttemptMap<Upstream: Publisher, NewOutput>: Publisher {
    public typealias Output = NewOutput
    public typealias Failure = Upstream.Failure

    let upstream: Upstream
    let transform: (Upstream.Output) -> Result<NewOutput, Failure>

    public func receive<S: Subscriber>(subscriber: S) where S.Input == NewOutput, S.Failure == Failure {
      let subscription = AttemptMapSubscription(upstream: upstream, transform: transform, subscriber: subscriber)
      upstream.subscribe(subscription)
    }
  }
}

private extension Publishers.AttemptMap {
  private final class AttemptMapSubscription<S: Subscriber>: Subscriber where S.Input == NewOutput, S.Failure == Upstream.Failure {
    typealias Input = Upstream.Output
    typealias Failure = Upstream.Failure

    var transform: ((Upstream.Output) -> Result<NewOutput, Upstream.Failure>)?
    var subscriber: S?

    init(upstream: Upstream, transform: @escaping (Upstream.Output) -> Result<NewOutput, Upstream.Failure>, subscriber: S) {
      self.transform = transform
      self.subscriber = subscriber
    }

    func cancel() {
      transform = nil
      subscriber = nil
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
  /// Wraps `setFailureType(to:)` in a way that forces the type checker to
  /// imply what the desired new failure type will be.
  func attemptMap<NewOutput>(
    _ transform: @escaping (Output) -> Result<NewOutput, Failure>
  ) -> Publishers.AttemptMap<Self, NewOutput> {
    Publishers.AttemptMap(upstream: self, transform: transform)
  }
}
