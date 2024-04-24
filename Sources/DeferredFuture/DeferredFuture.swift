//
//  DeferredFuture.swift
//  Copyright © 2024 Jason Fieldman.
//

import Combine

public struct DeferredFuture<Output, Failure: Error>: DeferredFutureProtocol, DeferredPublisherProtocol {
  public typealias WrappedFuture = Future<Output, Failure>
  public let attemptToFulfill: (@escaping WrappedFuture.Promise) -> Void
  let wrappedDeferredFuture: Deferred<WrappedFuture>

  public init(
    _ attemptToFulfill: @escaping (@escaping WrappedFuture.Promise) -> Void
  ) {
    self.attemptToFulfill = attemptToFulfill
    self.wrappedDeferredFuture = Deferred {
      Future(attemptToFulfill)
    }
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

  public var createPublisher: () -> WrappedFuture {
    wrappedDeferredFuture.createPublisher
  }

  public func eraseToAnyPublisher() -> AnyDeferredFuture<Output, Failure> {
    AnyDeferredFuture(self)
  }

  public func eraseToAnyDeferredFuture() -> AnyDeferredFuture<Output, Failure> {
    AnyDeferredFuture(self)
  }
}

public extension DeferredFuture {
  static func just(_ value: Output) -> DeferredFuture<Output, Failure> {
    DeferredFuture { $0(.success(value)) }
  }

  static func fail(_ error: Failure) -> DeferredFuture<Output, Failure> {
    DeferredFuture { $0(.failure(error)) }
  }
}
