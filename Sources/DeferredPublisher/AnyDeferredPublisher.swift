//
//  AnyDeferredPublisher.swift
//  Copyright © 2023 Jason Fieldman.
//

import Combine

/// Define a AnyDeferredPublisher concrete class that guarantees it only
/// wraps deferred publishers.
public class AnyDeferredPublisher<Output, Failure: Error>: DeferredPublisherProtocol {
  public typealias WrappedPublisher = AnyPublisher<Output, Failure>
  private let deferredPublisher: Deferred<WrappedPublisher>

  public init(
    _ deferredPublisher: Deferred<some Publisher<Output, Failure>>
  ) {
    self.deferredPublisher = Deferred { deferredPublisher.createPublisher().eraseToAnyPublisher() }
  }

  public convenience init(
    createPublisher: @escaping () -> WrappedPublisher
  ) {
    self.init(Deferred(createPublisher: createPublisher))
  }

  public func receive<S>(
    subscriber: S
  ) where
    S: Subscriber,
    Failure == S.Failure,
    Output == S.Input
  {
    deferredPublisher.receive(subscriber: subscriber)
  }

  public var createPublisher: () -> WrappedPublisher {
    deferredPublisher.createPublisher
  }
}

public extension AnyDeferredPublisher {
  /// `eraseToAnyPublisher` can be overwritten to ensure that the response
  /// maintains its subclass.
  func eraseToAnyPublisher() -> Self {
    self
  }
}
