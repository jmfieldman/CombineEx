//
//  DeferredFuture.swift
//  Copyright © 2024 Jason Fieldman.
//

import Combine

// MARK: DeferredFutureProtocol

public protocol DeferredFutureProtocol<Output, Failure>: Publisher {
  associatedtype WrappedFuture = Future<Output, Failure>
  var attemptToFulfill: (@escaping Future<Output, Failure>.Promise) -> Void { get }
  func eraseToAnyDeferredFuture() -> AnyDeferredFuture<Output, Failure>
}

// MARK: DeferredFuture

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

// MARK: AnyDeferredFuture

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

  public func eraseToAnyDeferredFuture() -> AnyDeferredFuture<Output, Failure> {
    self
  }
}
