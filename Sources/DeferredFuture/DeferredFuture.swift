//
//  DeferredFuture.swift
//  Copyright © 2023 Jason Fieldman.
//

import Combine

public struct DeferredFuture<Output, Failure: Error>: DeferredFutureProtocol, DeferredPublisherProtocol {
  public typealias WrappedPublisher = AnyPublisher<Output, Failure>
  public let attemptToFulfill: (@escaping WrappedFuture.Promise) -> Void
  let wrappedDeferredFuture: Deferred<WrappedPublisher>

  public init(
    _ attemptToFulfill: @escaping (@escaping WrappedFuture.Promise) -> Void
  ) {
    self.attemptToFulfill = attemptToFulfill
    self.wrappedDeferredFuture = Deferred { Future(attemptToFulfill).eraseToAnyPublisher() }
  }

  public func receive<S>(
    subscriber: S
  ) where
    S: Subscriber,
    Failure == S.Failure,
    Output == S.Input
  {
    wrappedDeferredFuture.receive(subscriber: subscriber)
  }

  public var createPublisher: () -> WrappedPublisher {
    wrappedDeferredFuture.createPublisher
  }

  public func eraseToAnyPublisher() -> AnyDeferredFuture<Output, Failure> {
    AnyDeferredFuture(self)
  }

  public func eraseToAnyDeferredFuture() -> AnyDeferredFuture<Output, Failure> {
    AnyDeferredFuture(self)
  }
}
