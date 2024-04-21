//
//  AnyDeferredFuture.swift
//  Copyright © 2023 Jason Fieldman.
//

import Combine

public class AnyDeferredFuture<Output, Failure: Error>: AnyDeferredPublisher<Output, Failure>, DeferredFutureProtocol {
  public typealias WrappedDeferredFuture = DeferredFuture<Output, Failure>
  private let wrappedDeferredFuture: DeferredFuture<Output, Failure>

  public init(
    _ deferredFuture: DeferredFuture<Output, Failure>
  ) {
    self.wrappedDeferredFuture = deferredFuture
    super.init(wrappedDeferredFuture.wrappedDeferredFuture)
  }

  public convenience init(
    attemptToFulfill: @escaping (@escaping WrappedFuture.Promise) -> Void
  ) {
    self.init(DeferredFuture(attemptToFulfill))
  }

  override public func receive<S>(
    subscriber: S
  ) where
    S: Subscriber,
    Failure == S.Failure,
    Output == S.Input
  {
    wrappedDeferredFuture.receive(subscriber: subscriber)
  }

  public var attemptToFulfill: (@escaping Future<Output, Failure>.Promise) -> Void {
    wrappedDeferredFuture.attemptToFulfill
  }

  override public var createPublisher: () -> AnyDeferredPublisher<Output, Failure>.WrappedPublisher {
    let wrapped = wrappedDeferredFuture
    return {
      wrapped.createPublisher().eraseToAnyPublisher()
    }
  }
}
