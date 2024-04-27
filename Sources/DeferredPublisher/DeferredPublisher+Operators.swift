//
//  DeferredPublisher+Operators.swift
//  Copyright © 2024 Jason Fieldman.
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

// MARK: Mapping Elements

public extension DeferredPublisherProtocol {
  @_disfavoredOverload
  func map<T>(
    _ transform: @escaping (WrappedPublisher.Output) -> T
  ) -> Deferred<Publishers.Map<WrappedPublisher, T>> where WrappedPublisher.Failure == Failure {
    deferredLift { $0.map(transform) }
  }

  @_disfavoredOverload
  func tryMap<T>(
    _ transform: @escaping (WrappedPublisher.Output) throws -> T
  ) -> Deferred<Publishers.TryMap<WrappedPublisher, T>> {
    deferredLift { $0.tryMap(transform) }
  }

  @_disfavoredOverload
  func mapError<E>(
    _ transform: @escaping (WrappedPublisher.Failure) -> E
  ) -> Deferred<Publishers.MapError<WrappedPublisher, E>> where E: Error {
    deferredLift { $0.mapError(transform) }
  }

  @_disfavoredOverload
  func replaceNil<T>(
    with output: T
  ) -> Deferred<Publishers.Map<WrappedPublisher, T>> where WrappedPublisher.Output == T? {
    deferredLift { $0.replaceNil(with: output) }
  }

  @_disfavoredOverload
  func scan<T>(
    _ initialResult: T,
    _ nextPartialResult: @escaping (T, WrappedPublisher.Output) -> T
  ) -> Deferred<Publishers.Scan<WrappedPublisher, T>> {
    deferredLift { $0.scan(initialResult, nextPartialResult) }
  }

  @_disfavoredOverload
  func tryScan<T>(
    _ initialResult: T,
    _ nextPartialResult: @escaping (T, WrappedPublisher.Output) throws -> T
  ) -> Deferred<Publishers.TryScan<WrappedPublisher, T>> {
    deferredLift { $0.tryScan(initialResult, nextPartialResult) }
  }

  @_disfavoredOverload
  func setFailureType<E>(
    to failureType: E.Type
  ) -> Deferred<Publishers.SetFailureType<WrappedPublisher, E>> where WrappedPublisher.Failure == Never, E: Error {
    deferredLift { $0.setFailureType(to: E.self) }
  }
}

// MARK: Republishing Elements by Subscribing to New Publishers

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
