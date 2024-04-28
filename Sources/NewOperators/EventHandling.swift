//
//  EventHandling.swift
//  Copyright © 2023 Jason Fieldman.
//

import Combine

// MARK: - Publisher

public extension Publisher {
  func handleSubscription(
    _ receiveSubscription: (() -> Void)? = nil
  ) -> Publishers.HandleEvents<Self> {
    handleEvents(receiveSubscription: { _ in receiveSubscription?() })
  }

  func handleValue(
    _ receiveValue: ((Output) -> Void)? = nil
  ) -> Publishers.HandleEvents<Self> {
    handleEvents(receiveOutput: { receiveValue?($0) })
  }

  func handleError(
    _ receiveError: ((Failure) -> Void)? = nil
  ) -> Publishers.HandleEvents<Self> {
    handleEvents(receiveCompletion: {
      switch $0 {
      case .finished:
        break
      case let .failure(error):
        receiveError?(error)
      }
    })
  }

  func handleFinished(
    _ receiveFinished: (() -> Void)? = nil
  ) -> Publishers.HandleEvents<Self> {
    handleEvents(receiveCompletion: {
      switch $0 {
      case .finished:
        receiveFinished?()
      case .failure:
        break
      }
    })
  }

  func handleCompletion(
    _ receiveCompletion: ((Subscribers.Completion<Failure>) -> Void)? = nil
  ) -> Publishers.HandleEvents<Self> {
    handleEvents(receiveCompletion: { receiveCompletion?($0) })
  }

  func handleCancel(
    _ receiveCancel: (() -> Void)? = nil
  ) -> Publishers.HandleEvents<Self> {
    handleEvents(receiveCancel: { receiveCancel?() })
  }
}

// MARK: - DeferredPublisherProtocol

public extension DeferredPublisherProtocol {
  @_disfavoredOverload
  func handleSubscription(
    _ receiveSubscription: (() -> Void)? = nil
  ) -> Deferred<Publishers.HandleEvents<WrappedPublisher>> where WrappedPublisher: Publisher {
    deferredLift { $0.handleSubscription(receiveSubscription) }
  }

  @_disfavoredOverload
  func handleValue(
    _ receiveValue: ((Output) -> Void)? = nil
  ) -> Deferred<Publishers.HandleEvents<WrappedPublisher>> where WrappedPublisher: Publisher, Output == WrappedPublisher.Output {
    deferredLift { $0.handleValue(receiveValue) }
  }

  @_disfavoredOverload
  func handleError(
    _ receiveError: ((Failure) -> Void)? = nil
  ) -> Deferred<Publishers.HandleEvents<WrappedPublisher>> where WrappedPublisher: Publisher, Failure == WrappedPublisher.Failure {
    deferredLift { $0.handleError(receiveError) }
  }

  @_disfavoredOverload
  func handleFinished(
    _ receiveFinished: (() -> Void)? = nil
  ) -> Deferred<Publishers.HandleEvents<WrappedPublisher>> where WrappedPublisher: Publisher {
    deferredLift { $0.handleFinished(receiveFinished) }
  }

  @_disfavoredOverload
  func handleCompletion(
    _ receiveCompletion: ((Subscribers.Completion<Failure>) -> Void)? = nil
  ) -> Deferred<Publishers.HandleEvents<WrappedPublisher>> where WrappedPublisher: Publisher, Failure == WrappedPublisher.Failure {
    deferredLift { $0.handleCompletion(receiveCompletion) }
  }

  @_disfavoredOverload
  func handleCancel(
    _ receiveCancel: (() -> Void)? = nil
  ) -> Deferred<Publishers.HandleEvents<WrappedPublisher>> where WrappedPublisher: Publisher {
    deferredLift { $0.handleCancel(receiveCancel) }
  }
}

// MARK: - DeferredFutureProtocol

public extension DeferredFutureProtocol {
  @_disfavoredOverload
  func handleSubscription(
    _ receiveSubscription: (() -> Void)? = nil
  ) -> DeferredFuture<Output, Failure> {
    let outerAttempt = attemptToFulfill
    return DeferredFuture<Output, Failure> { innerPromise in
      receiveSubscription?()
      outerAttempt { outerResult in
        innerPromise(outerResult)
      }
    }
  }

  @_disfavoredOverload
  func handleValue(
    _ receiveOutput: ((Output) -> Void)? = nil
  ) -> DeferredFuture<Output, Failure> {
    futureLiftOutput { outerValue, innerPromise in
      receiveOutput?(outerValue)
      innerPromise(.success(outerValue))
    }
  }

  @_disfavoredOverload
  func handleError(
    _ receiveError: ((Failure) -> Void)? = nil
  ) -> DeferredFuture<Output, Failure> {
    futureLiftFailure { outerError, innerPromise in
      receiveError?(outerError)
      innerPromise(.failure(outerError))
    }
  }

  @_disfavoredOverload
  func handleFinished(
    _ receiveFinished: (() -> Void)? = nil
  ) -> DeferredFuture<Output, Failure> {
    futureLiftResult { outerResult, innerPromise in
      innerPromise(outerResult)
      receiveFinished?()
    }
  }

  @_disfavoredOverload
  func handleCompletion(
    _ receiveCompletion: ((Result<Output, Failure>) -> Void)? = nil
  ) -> DeferredFuture<Output, Failure> {
    futureLiftResult { outerResult, innerPromise in
      innerPromise(outerResult)
      receiveCompletion?(outerResult)
    }
  }
}
