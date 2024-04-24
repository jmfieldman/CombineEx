//
//  DeferredFutureProtocol+Operators.swift
//  Copyright © 2023 Jason Fieldman.
//

import Combine
import Foundation

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

  /// Maps a failure from the receiving DeferredFuture into the `lift` tuple.
  /// This allows the caller to transform the failure of the receiver into a new output.
  /// Successes are piped through without change.
  func futureLiftFailureToOutput(
    _ lift: @escaping (Failure, @escaping Future<Output, Failure>.Promise) -> Void
  ) -> DeferredFuture<Output, Failure> {
    let outerAttempt = attemptToFulfill
    return DeferredFuture<Output, Failure> { innerPromise in
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

/// A private class that helps us accumuate N promises. The class
/// retains itself until the outer promise is executed.
private class CombineLatestAccumulator<Output, Failure: Error> {
  private var values: [Any]
  private var nextIndex = 0
  private let lock = NSLock()
  private var onAccumulated: (([Any]) -> Output)?
  private var outerPromise: (Future<Output, Failure>.Promise)?
  private var retainer: CombineLatestAccumulator?
  private var remaining: Int

  init(
    _ outerPromise: @escaping Future<Output, Failure>.Promise,
    _ count: Int,
    onAccumulated: @escaping ([Any]) -> Output
  ) {
    self.values = [Any](repeating: 0, count: count)
    self.outerPromise = outerPromise
    self.onAccumulated = onAccumulated
    self.remaining = count
    self.retainer = self
  }

  private func notify() {
    guard let onAccumulated else { return }
    outerPromise?(.success(onAccumulated(values)))
    retainer = nil
  }

  func add(_ future: some DeferredFutureProtocol<some Any, Failure>) {
    let index = nextIndex
    nextIndex += 1
    future.attemptToFulfill { [weak self] result in
      guard let self else { return }
      lock.withLock {
        switch result {
        case let .success(value):
          self.values[index] = value
          self.remaining -= 1
          if self.remaining == 0 {
            self.notify()
          }
        case let .failure(error):
          self.outerPromise?(.failure(error))
          self.onAccumulated = nil
          self.outerPromise = nil
          self.retainer = nil
        }
      }
    }
  }
}

// MARK: - Mapping Elements

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
    _ transform: @escaping (Output) -> some DeferredFutureProtocol<NewOutput, Failure>
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
    _ transform: @escaping (Failure) -> some DeferredFutureProtocol<Output, NewFailure>
  ) -> DeferredFuture<Output, NewFailure> {
    futureLiftFailure { outerFailure, innerPromise in
      transform(outerFailure).attemptToFulfill { innerResult in
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

// MARK: - Filtering Elements

public extension DeferredFutureProtocol {
  @_disfavoredOverload
  func replaceError(
    with output: Output
  ) -> DeferredFuture<Output, Failure> {
    futureLiftFailure { _, innerPromise in
      innerPromise(.success(output))
    }
  }
}

// MARK: - Combining Elements

public extension DeferredFutureProtocol {
  @_disfavoredOverload
  func combineLatest<P>(
    _ other: some DeferredFutureProtocol<P, Failure>
  ) -> DeferredFuture<(Self.Output, P), Failure> {
    DeferredFuture { promise in
      let accumulator = CombineLatestAccumulator(promise, 2) {
        ($0[0] as! Self.Output, $0[1] as! P)
      }
      accumulator.add(self)
      accumulator.add(other)
    }
  }

  @_disfavoredOverload
  func combineLatest<P, T>(
    _ other: some DeferredFutureProtocol<P, Failure>,
    _ transform: @escaping (Self.Output, P) -> T
  ) -> DeferredFuture<T, Failure> {
    DeferredFuture { promise in
      let accumulator = CombineLatestAccumulator(promise, 2) {
        transform($0[0] as! Self.Output, $0[1] as! P)
      }
      accumulator.add(self)
      accumulator.add(other)
    }
  }

  @_disfavoredOverload
  func combineLatest<P, Q>(
    _ publisher1: some DeferredFutureProtocol<P, Failure>,
    _ publisher2: some DeferredFutureProtocol<Q, Failure>
  ) -> DeferredFuture<(Self.Output, P, Q), Failure> {
    DeferredFuture { promise in
      let accumulator = CombineLatestAccumulator(promise, 3) {
        ($0[0] as! Self.Output, $0[1] as! P, $0[2] as! Q)
      }
      accumulator.add(self)
      accumulator.add(publisher1)
      accumulator.add(publisher2)
    }
  }

  @_disfavoredOverload
  func combineLatest<P, Q, T>(
    _ publisher1: some DeferredFutureProtocol<P, Failure>,
    _ publisher2: some DeferredFutureProtocol<Q, Failure>,
    _ transform: @escaping (Self.Output, P, Q) -> T
  ) -> DeferredFuture<T, Failure> {
    DeferredFuture { promise in
      let accumulator = CombineLatestAccumulator(promise, 3) {
        transform($0[0] as! Self.Output, $0[1] as! P, $0[2] as! Q)
      }
      accumulator.add(self)
      accumulator.add(publisher1)
      accumulator.add(publisher2)
    }
  }
}

// MARK: - Handling Errors

public extension DeferredFutureProtocol {
  @_disfavoredOverload
  func `catch`(
    _ transform: @escaping (Failure) -> some DeferredFutureProtocol<Output, Failure>
  ) -> DeferredFuture<Output, Failure> {
    futureLiftFailureToOutput { outerFailure, innerPromise in
      transform(outerFailure).attemptToFulfill { innerResult in
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
  func tryCatch(
    _ transform: @escaping (Failure) throws -> some DeferredFutureProtocol<Output, Failure>
  ) -> DeferredFuture<Output, Failure> where Failure == Error {
    futureLiftFailureToOutput { outerFailure, innerPromise in
      do {
        try transform(outerFailure).attemptToFulfill { innerResult in
          switch innerResult {
          case let .success(innerOutput):
            innerPromise(.success(innerOutput))
          case let .failure(innerFailure):
            innerPromise(.failure(innerFailure))
          }
        }
      } catch {
        innerPromise(.failure(error))
      }
    }
  }

  @_disfavoredOverload
  func retry(
    _ retries: Int
  ) -> DeferredFuture<Output, Failure> {
    `catch` { [attemptToFulfill] error -> DeferredFuture<Output, Failure> in
      if retries <= 0 {
        return .fail(error)
      } else {
        return DeferredFuture(attemptToFulfill).retry(retries - 1)
      }
    }
  }
}

// MARK: - Deferred Operator Aliases

// These can be used to return DeferredFutures in a non-ambiguous manner.

public extension DeferredFutureProtocol {
  // Mapping

  @inlinable func mapDeferredFuture<NewOutput>(
    _ transform: @escaping (Output) -> NewOutput
  ) -> DeferredFuture<NewOutput, Failure> {
    map(transform)
  }

  @inlinable func tryMapDeferredFuture<NewOutput>(
    _ transform: @escaping (Output) throws -> NewOutput
  ) -> DeferredFuture<NewOutput, Failure> where Failure == Error {
    tryMap(transform)
  }

  @inlinable func mapErrorDeferredFuture<NewError: Error>(
    _ transform: @escaping (Failure) -> NewError
  ) -> DeferredFuture<Output, NewError> {
    mapError(transform)
  }

  @inlinable func replaceNilDeferredFuture<NewOutput>(
    with output: NewOutput
  ) -> DeferredFuture<NewOutput, Failure> where Self.Output == NewOutput? {
    replaceNil(with: output)
  }

  @inlinable func flatMapDeferredFuture<NewOutput>(
    _ transform: @escaping (Output) -> DeferredFuture<NewOutput, Failure>
  ) -> DeferredFuture<NewOutput, Failure> {
    flatMap(transform)
  }

  @inlinable func flatMapErrorDeferredFuture<NewFailure>(
    _ transform: @escaping (Failure) -> DeferredFuture<Output, NewFailure>
  ) -> DeferredFuture<Output, NewFailure> {
    flatMapError(transform)
  }

  @inlinable func setFailureTypeDeferredFuture<NewFailure>(
    to failureType: NewFailure.Type
  ) -> DeferredFuture<Output, NewFailure> where Failure == Never, NewFailure: Error {
    setFailureType(to: failureType)
  }

  // Filtering

  @inlinable func replaceErrorDeferredFuture(
    with output: Output
  ) -> DeferredFuture<Output, Failure> {
    replaceError(with: output)
  }

  // Handling Errors

  @inlinable func catchDeferredFuture(
    _ transform: @escaping (Failure) -> some DeferredFutureProtocol<Output, Failure>
  ) -> DeferredFuture<Output, Failure> {
    `catch`(transform)
  }

  @inlinable func tryCatchDeferredFuture(
    _ transform: @escaping (Failure) throws -> some DeferredFutureProtocol<Output, Failure>
  ) -> DeferredFuture<Output, Failure> where Failure == Error {
    tryCatch(transform)
  }
}
