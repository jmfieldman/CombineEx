//
//  EventHandling.swift
//  Copyright © 2023 Jason Fieldman.
//

import Combine

// MARK: - DeferredFutureProtocol

public extension DeferredFutureProtocol {
  @_disfavoredOverload
  func onSubscription(
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
  func onValue(
    _ receiveOutput: ((Output) -> Void)? = nil
  ) -> DeferredFuture<Output, Failure> {
    futureLiftOutput { outerValue, innerPromise in
      receiveOutput?(outerValue)
      innerPromise(.success(outerValue))
    }
  }

  @_disfavoredOverload
  func onError(
    _ receiveError: ((Failure) -> Void)? = nil
  ) -> DeferredFuture<Output, Failure> {
    futureLiftFailure { outerError, innerPromise in
      receiveError?(outerError)
      innerPromise(.failure(outerError))
    }
  }

  @_disfavoredOverload
  func onFinished(
    _ receiveFinished: (() -> Void)? = nil
  ) -> DeferredFuture<Output, Failure> {
    futureLiftResult { outerResult, innerPromise in
      innerPromise(outerResult)
      receiveFinished?()
    }
  }

  @_disfavoredOverload
  func onCompletion(
    _ receiveCompletion: ((Result<Output, Failure>) -> Void)? = nil
  ) -> DeferredFuture<Output, Failure> {
    futureLiftResult { outerResult, innerPromise in
      innerPromise(outerResult)
      receiveCompletion?(outerResult)
    }
  }
}
