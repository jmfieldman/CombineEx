//
//  DeferredFutureProtocol+Operators.swift
//  Copyright © 2023 Jason Fieldman.
//

import Combine

public extension DeferredFutureProtocol {
  /// Maps an output from the receiving DeferredFuture into the `lift` tuple.
  /// This allows the caller to transform the output type/value of the receiver.
  /// Failures are piped through without change.
  func futureLiftOutput<NewOutput>(
    _ lift: @escaping (Output, @escaping Future<NewOutput, Failure>.Promise) -> Void
  ) -> DeferredFuture<NewOutput, Failure> {
    let outerAttempt = attemptToFulfill
    return DeferredFuture<NewOutput, Failure> { innerPromise in
      outerAttempt { outerResult in
        switch outerResult {
        case let .success(outerOutput):
          lift(outerOutput, innerPromise)
        case let .failure(outerFailure):
          innerPromise(.failure(outerFailure))
        }
      }
    }
  }

  /// Maps a failure from the receiving DeferredFuture into the `lift` tuple.
  /// This allows the caller to transform the failure type/value of the receiver.
  /// Successes are piped through without change.
  func futureLiftFailure<NewFailure: Error>(
    _ lift: @escaping (Failure, @escaping Future<Output, NewFailure>.Promise) -> Void
  ) -> DeferredFuture<Output, NewFailure> {
    let outerAttempt = attemptToFulfill
    return DeferredFuture<Output, NewFailure> { innerPromise in
      outerAttempt { outerResult in
        switch outerResult {
        case let .success(outerOutput):
          innerPromise(.success(outerOutput))
        case let .failure(outerFailure):
          lift(outerFailure, innerPromise)
        }
      }
    }
  }
}

public extension DeferredFutureProtocol {
  @_disfavoredOverload
  func map<NewOutput>(
    _ transform: @escaping (Output) -> NewOutput
  ) -> DeferredFuture<NewOutput, Failure> {
    futureLiftOutput { outerOutput, innerPromise in
      innerPromise(.success(transform(outerOutput)))
    }
  }

  @_disfavoredOverload
  func tryMap<NewOutput>(
    _ transform: @escaping (Output) throws -> NewOutput
  ) -> DeferredFuture<NewOutput, Failure> where Failure == Error {
    futureLiftOutput { outerOutput, innerPromise in
      do {
        let attemptedMap = try transform(outerOutput)
        innerPromise(.success(attemptedMap))
      } catch {
        innerPromise(.failure(error))
      }
    }
  }

  @_disfavoredOverload
  func mapError<NewFailure: Error>(
    _ transform: @escaping (Failure) -> NewFailure
  ) -> DeferredFuture<Output, NewFailure> {
    futureLiftFailure { outerFailure, innerPromise in
      innerPromise(.failure(transform(outerFailure)))
    }
  }

  @_disfavoredOverload
  func replaceNil<NewOutput>(
    with output: NewOutput
  ) -> DeferredFuture<NewOutput, Failure> where Self.Output == NewOutput? {
    map { $0 ?? output }
  }

  @_disfavoredOverload
  func flatMap<NewOutput>(
    _ transform: @escaping (Output) -> DeferredFuture<NewOutput, Failure>
  ) -> DeferredFuture<NewOutput, Failure> {
    futureLiftOutput { outerOutput, innerPromise in
      transform(outerOutput).attemptToFulfill { innerResult in
        switch innerResult {
        case let .success(innerOutput):
          innerPromise(.success(innerOutput))
        case let .failure(innerFailure):
          innerPromise(.failure(innerFailure))
        }
      }
    }
  }

  @_disfavoredOverload
  func flatMapError<NewFailure>(
    _ transform: @escaping (Failure) -> DeferredFuture<Output, NewFailure>
  ) -> DeferredFuture<Output, NewFailure> {
    futureLiftFailure { outerOutput, innerPromise in
      transform(outerOutput).attemptToFulfill { innerResult in
        switch innerResult {
        case let .success(innerOutput):
          innerPromise(.success(innerOutput))
        case let .failure(innerFailure):
          innerPromise(.failure(innerFailure))
        }
      }
    }
  }

  @_disfavoredOverload
  func setFailureType<NewFailure>(
    to failureType: NewFailure.Type
  ) -> DeferredFuture<Output, NewFailure> where Failure == Never, NewFailure: Error {
    futureLiftFailure { _, _ in }
  }
}

// MARK: - Deferred Operator Aliases

// These can be used to return DeferredFutures in a non-ambiguous manner.

public extension DeferredFutureProtocol {
  func mapDeferred<NewOutput>(
    _ transform: @escaping (Output) -> NewOutput
  ) -> DeferredFuture<NewOutput, Failure> {
    map(transform)
  }

  func tryMapDeferred<NewOutput>(
    _ transform: @escaping (Output) throws -> NewOutput
  ) -> DeferredFuture<NewOutput, Failure> where Failure == Error {
    tryMap(transform)
  }

  func mapErrorDeferred<NewError: Error>(
    _ transform: @escaping (Failure) -> NewError
  ) -> DeferredFuture<Output, NewError> {
    mapError(transform)
  }

  func replaceNilDeferred<NewOutput>(
    with output: NewOutput
  ) -> DeferredFuture<NewOutput, Failure> where Self.Output == NewOutput? {
    replaceNil(with: output)
  }

  func flatMapDeferred<NewOutput>(
    _ transform: @escaping (Output) -> DeferredFuture<NewOutput, Failure>
  ) -> DeferredFuture<NewOutput, Failure> {
    flatMap(transform)
  }

  func flatMapErrorDeferred<NewFailure>(
    _ transform: @escaping (Failure) -> DeferredFuture<Output, NewFailure>
  ) -> DeferredFuture<Output, NewFailure> {
    flatMapError(transform)
  }

  func setFailureTypeDeferred<NewFailure>(
    to failureType: NewFailure.Type
  ) -> DeferredFuture<Output, NewFailure> where Failure == Never, NewFailure: Error {
    setFailureType(to: failureType)
  }
}
