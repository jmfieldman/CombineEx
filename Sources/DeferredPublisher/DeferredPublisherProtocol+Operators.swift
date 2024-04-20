//
//  DeferredPublisherProtocol+Operators.swift
//  Copyright © 2023 Jason Fieldman.
//

import Combine

// MARK: Lift

public extension DeferredPublisherProtocol {
  /// A generic lift function that can operate on any DeferredPublisherProtocol
  /// implementation.
  ///
  /// Use this to transform the inner-wrapped publisher, and re-wrap it in a
  /// new Deferred publisher. This guarantees that transforms result in a new
  /// deferred publisher.
  func deferredLift<TargetPublisher: Publisher>(
    _ transform: @escaping (WrappedPublisher) -> TargetPublisher
  ) -> Deferred<TargetPublisher> {
    let innerCreatePublisher = createPublisher
    return Deferred<TargetPublisher> { transform(innerCreatePublisher()) }
  }
}

// MARK: Map

public extension DeferredPublisherProtocol {
  @_disfavoredOverload
  func map<T>(
    _ transform: @escaping (WrappedPublisher.Output) -> T
  ) -> Deferred<Publishers.Map<WrappedPublisher, T>> where WrappedPublisher.Failure == Failure {
    deferredLift { $0.map(transform) }
  }
}

// MARK: TryMap

public extension DeferredPublisherProtocol {
  @_disfavoredOverload
  func tryMap<T>(
    _ transform: @escaping (WrappedPublisher.Output) throws -> T
  ) -> Deferred<Publishers.TryMap<WrappedPublisher, T>> {
    deferredLift { $0.tryMap(transform) }
  }
}

// MARK: SetFailureType

public extension DeferredPublisherProtocol {
  @_disfavoredOverload
  func setFailureType<E>(
    to failureType: E.Type
  ) -> Deferred<Publishers.SetFailureType<WrappedPublisher, E>> where WrappedPublisher.Failure == Never, E: Error {
    deferredLift { $0.setFailureType(to: E.self) }
  }
}

// MARK: FlatMap

public extension DeferredPublisherProtocol {
  @_disfavoredOverload
  func flatMap<T, P>(
    maxPublishers: Subscribers.Demand = .unlimited,
    _ transform: @escaping (WrappedPublisher.Output) -> P
  ) -> Deferred<Publishers.FlatMap<P, WrappedPublisher>> where
    T == P.Output,
    P: Publisher,
    WrappedPublisher.Failure == P.Failure
  {
    deferredLift { $0.flatMap(maxPublishers: maxPublishers, transform) }
  }

  @_disfavoredOverload
  func flatMap<P>(
    maxPublishers: Subscribers.Demand = .unlimited,
    _ transform: @escaping (WrappedPublisher.Output) -> P
  ) -> Deferred<Publishers.FlatMap<P, Publishers.SetFailureType<WrappedPublisher, P.Failure>>> where
    P: Publisher
  {
    deferredLift { $0.flatMap(maxPublishers: maxPublishers, transform) }
  }

  @_disfavoredOverload
  func flatMap<P>(
    maxPublishers: Subscribers.Demand = .unlimited,
    _ transform: @escaping (WrappedPublisher.Output) -> P
  ) -> Deferred<Publishers.FlatMap<P, WrappedPublisher>> where
    P: Publisher,
    P.Failure == Never
  {
    deferredLift { $0.flatMap(maxPublishers: maxPublishers, transform) }
  }

  @_disfavoredOverload
  func flatMap<P>(
    maxPublishers: Subscribers.Demand = .unlimited,
    _ transform: @escaping (WrappedPublisher.Output) -> P
  ) -> Deferred<Publishers.FlatMap<Publishers.SetFailureType<P, Failure>, WrappedPublisher>> where
    P: Publisher,
    P.Failure == Never
  {
    deferredLift { $0.flatMap(maxPublishers: maxPublishers, transform) }
  }
}

// MARK: SwitchToLatest

public extension DeferredPublisherProtocol {
  @_disfavoredOverload
  func switchToLatest() -> Deferred<Publishers.SwitchToLatest<Output, WrappedPublisher>> where
    Output: Publisher,
    Output.Failure == Failure
  {
    deferredLift { $0.switchToLatest() }
  }

  @_disfavoredOverload
  func switchToLatest() -> Deferred<Publishers.SwitchToLatest<Output, Publishers.SetFailureType<WrappedPublisher, Output.Failure>>> where
    Output: Publisher,
    Failure == Never
  {
    deferredLift { $0.switchToLatest() }
  }

  @_disfavoredOverload
  func switchToLatest() -> Deferred<Publishers.SwitchToLatest<Publishers.SetFailureType<Output, Failure>, Publishers.Map<WrappedPublisher, Publishers.SetFailureType<WrappedPublisher.Output, Failure>>>> where
    Output: Publisher,
    Output.Failure == Never
  {
    deferredLift { $0.switchToLatest() }
  }

  @_disfavoredOverload
  func switchToLatest() -> Deferred<Publishers.SwitchToLatest<Output, WrappedPublisher>> where
    Output: Publisher,
    Failure == Never,
    Output.Failure == Never
  {
    deferredLift { $0.switchToLatest() }
  }
}
