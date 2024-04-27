//
//  DeferredPublisher.swift
//  Copyright © 2024 Jason Fieldman.
//

import Combine

// MARK: DeferredPublisherProtocol

/// `DeferredPublisherProtocol` allow both `Deferred` and `AnyDeferredPublisher`
/// to conform and inherit the new deferred operators.
public protocol DeferredPublisherProtocol<Output, Failure>: Publisher {
  associatedtype WrappedPublisher = any Publisher<Output, Failure>
  var createPublisher: () -> WrappedPublisher { get }
}

// MARK: Deferred Extension

extension Deferred: DeferredPublisherProtocol {
  public func eraseToAnyDeferredPublisher() -> AnyDeferredPublisher<Output, Failure> {
    AnyDeferredPublisher(self)
  }
}

// MARK: AnyDeferredPublisher

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
