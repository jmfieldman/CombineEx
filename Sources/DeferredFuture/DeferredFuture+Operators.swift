//
//  DeferredFuture+Operators.swift
//  Copyright © 2024 Jason Fieldman.
//

import Combine
import Foundation
import os

public extension DeferredFutureProtocol {
    /// Maps an output from the receiving DeferredFuture into the `lift` tuple.
    /// This allows the caller to transform the output type/value of the receiver.
    /// Failures are piped through without change.
    @inlinable func futureLiftOutput<NewOutput>(
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
    @inlinable func futureLiftFailure<NewFailure: Error>(
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

    /// Maps a result from the receiving DeferredFuture into the `lift` tuple.
    /// This allows the caller to act on the result of the receiver.
    @inlinable func futureLiftResult<Output>(
        _ lift: @escaping (Result<Self.Output, Failure>, @escaping Future<Output, Failure>.Promise) -> Void
    ) -> DeferredFuture<Output, Failure> {
        let outerAttempt = attemptToFulfill
        return DeferredFuture<Output, Failure> { innerPromise in
            outerAttempt { outerResult in
                lift(outerResult, innerPromise)
            }
        }
    }

    /// Maps a failure from the receiving DeferredFuture into the `lift` tuple.
    /// This allows the caller to transform the failure of the receiver into a new output.
    /// Successes are piped through without change.
    @inlinable func futureLiftFailureToOutput(
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

// MARK: - Mapping Elements

public extension DeferredFutureProtocol {
    /// Transforms the output of this `DeferredFuture` using a given transformation function.
    ///
    /// - Parameter transform: The transformation function to apply to the output.
    /// - Returns: A new `DeferredFuture` that contains the transformed output.
    @_disfavoredOverload
    func map<NewOutput>(
        _ transform: @escaping (Output) -> NewOutput
    ) -> DeferredFuture<NewOutput, Failure> {
        futureLiftOutput { outerOutput, innerPromise in
            innerPromise(.success(transform(outerOutput)))
        }
    }

    /// Transforms the output of this `DeferredFuture` using a given throwing transformation function.
    ///
    /// - Parameter transform: The transformation function to apply to the output, which may throw.
    /// - Returns: A new `DeferredFuture` that contains the transformed output or an error if thrown.
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

    /// Transforms the failure of this `DeferredFuture` using a given transformation function.
    ///
    /// - Parameter transform: The transformation function to apply to the failure.
    /// - Returns: A new `DeferredFuture` that contains the transformed failure.
    @_disfavoredOverload
    func mapError<NewFailure: Error>(
        _ transform: @escaping (Failure) -> NewFailure
    ) -> DeferredFuture<Output, NewFailure> {
        futureLiftFailure { outerFailure, innerPromise in
            innerPromise(.failure(transform(outerFailure)))
        }
    }

    /// Replaces `nil` output with a specified value.
    ///
    /// - Parameter output: The value to use in place of `nil`.
    /// - Returns: A new `DeferredFuture` that contains the specified value if the output is `nil`.
    @_disfavoredOverload
    func replaceNil<NewOutput>(
        with output: NewOutput
    ) -> DeferredFuture<NewOutput, Failure> where Self.Output == NewOutput? {
        map { $0 ?? output }
    }

    /// Transforms the output of this `DeferredFuture` using a given transformation function that returns another `DeferredFuture`.
    ///
    /// - Parameter transform: The transformation function to apply to the output, which returns a new `DeferredFuture`.
    /// - Returns: A new `DeferredFuture` that contains the output of the transformed `DeferredFuture`.
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

    /// Transforms the failure of this `DeferredFuture` using a given transformation function that returns another `DeferredFuture`.
    ///
    /// - Parameter transform: The transformation function to apply to the failure, which returns a new `DeferredFuture`.
    /// - Returns: A new `DeferredFuture` that contains the output of the transformed `DeferredFuture`.
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

    /// Sets a new failure type for this `DeferredFuture` that never fails.
    ///
    /// - Parameter failureType: The type of the new failure.
    /// - Returns: A new `DeferredFuture` with the specified failure type.
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

// MARK: - Handling Errors

public extension DeferredFutureProtocol {
    /// Catches errors emitted by the publisher and attempts to fulfill the promise using a transformed deferred future.
    ///
    /// - Parameters:
    ///   - transform: A closure that takes a failure and returns a new deferred future.
    ///
    /// - Returns: A `DeferredFuture` that attempts to fulfill based on the transformed deferred future.
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

    /// Catches errors emitted by the publisher and attempts to fulfill the promise using a transformed deferred future, with error handling.
    ///
    /// - Parameters:
    ///   - transform: A throwing closure that takes a failure and returns a new deferred future.
    ///
    /// - Returns: A `DeferredFuture` that attempts to fulfill based on the transformed deferred future.
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

    /// Retries the deferred future a specified number of times upon failure.
    ///
    /// - Parameters:
    ///   - retries: The maximum number of retry attempts.
    ///
    /// - Returns: A `DeferredFuture` that retries the operation up to the specified number of times.
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

// MARK: - Handling Timing

public extension DeferredFutureProtocol {
    /// Delays the fulfillment of this `DeferredFuture` by a specified interval.
    ///
    /// - Parameters:
    ///   - interval: The time interval to delay the fulfillment.
    ///   - tolerance: The allowed tolerance for the delay. Defaults to `nil`.
    ///   - scheduler: The scheduler on which to perform the delay.
    ///   - options: Scheduler-specific options. Defaults to `nil`.
    /// - Returns: A new `DeferredFuture` that is fulfilled after the specified delay.
    @_disfavoredOverload
    func delay<S>(
        for interval: S.SchedulerTimeType,
        tolerance: S.SchedulerTimeType.Stride? = nil,
        scheduler: S,
        options: S.SchedulerOptions? = nil
    ) -> DeferredFuture<Output, Failure> where S: Scheduler {
        futureLiftResult { outerResult, innerPromise in
            scheduler.schedule(
                after: interval,
                tolerance: tolerance ?? scheduler.minimumTolerance,
                options: options
            ) {
                innerPromise(outerResult)
            }
        }
    }

    /// Times out the fulfillment of this `DeferredFuture` if it takes longer than a specified interval.
    ///
    /// - Parameters:
    ///   - interval: The time interval after which the fulfillment times out.
    ///   - scheduler: The scheduler on which to perform the timeout check.
    ///   - options: Scheduler-specific options. Defaults to `nil`.
    ///   - customError: A closure that returns a custom error if the fulfillment times out. Defaults to `nil`.
    /// - Returns: A new `DeferredFuture` that fails with a timeout error if the fulfillment takes too long.
    func timeout<S>(
        _ interval: S.SchedulerTimeType,
        scheduler: S,
        options: S.SchedulerOptions? = nil,
        customError: (() -> Self.Failure)? = nil
    ) -> DeferredFuture<Output, Failure> where S: Scheduler {
        let outerAttempt = attemptToFulfill
        return DeferredFuture { innerPromise in
            let lock = OSAllocatedUnfairLock(initialState: false)
            scheduler.schedule(
                after: interval,
                tolerance: scheduler.minimumTolerance,
                options: options
            ) {
                lock.withLock { hasFinished in
                    if !hasFinished, let error = customError?() {
                        hasFinished = true
                        innerPromise(.failure(error))
                    }
                }
            }
            outerAttempt { outerResult in
                lock.withLock { hasFinished in
                    if !hasFinished {
                        hasFinished = true
                        innerPromise(outerResult)
                    }
                }
            }
        }
    }
}

// MARK: - Encoding and Decoding

public extension DeferredFutureProtocol {
    /// Encodes the output of this `DeferredFuture` using a given encoder.
    ///
    /// - Parameter encoder: The encoder to use for encoding the output.
    /// - Returns: A new `DeferredFuture` that contains the encoded data.
    @_disfavoredOverload
    func encode<Coder: TopLevelEncoder>(
        encoder: Coder
    ) -> DeferredFuture<Coder.Output, Failure> where Failure == Error, Output: Encodable {
        futureLiftOutput { outerOutput, innerPromise in
            do {
                let attemptEncoding = try encoder.encode(outerOutput)
                innerPromise(.success(attemptEncoding))
            } catch {
                innerPromise(.failure(error))
            }
        }
    }

    /// Decodes the output of this `DeferredFuture` into a specified type using a given decoder.
    ///
    /// - Parameters:
    ///   - item: The type to which the output should be decoded.
    ///   - decoder: The decoder to use for decoding the output.
    /// - Returns: A new `DeferredFuture` that contains the decoded item.
    @_disfavoredOverload
    func decode<Item: Decodable, Coder: TopLevelDecoder>(
        item: Item.Type,
        decoder: Coder
    ) -> DeferredFuture<Item, Failure> where Failure == Error, Output == Coder.Input {
        futureLiftOutput { outerOutput, innerPromise in
            do {
                let attemptDecoding = try decoder.decode(item, from: outerOutput)
                innerPromise(.success(attemptDecoding))
            } catch {
                innerPromise(.failure(error))
            }
        }
    }
}

// MARK: - Keypath Mapping

public extension DeferredFutureProtocol {
    /// Maps the result of this `DeferredFuture` using a given key path.
    ///
    /// - Parameter keyPath: The key path to extract the desired value from the output.
    /// - Returns: A new `DeferredFuture` that contains the extracted value.
    func map<T>(
        _ keyPath: KeyPath<Output, T>
    ) -> DeferredFuture<T, Failure> {
        map { $0[keyPath: keyPath] }
    }

    /// Maps the result of this `DeferredFuture` using two given key paths.
    ///
    /// - Parameters:
    ///   - keyPath0: The first key path to extract a value from the output.
    ///   - keyPath1: The second key path to extract another value from the output.
    /// - Returns: A new `DeferredFuture` that contains a tuple of the extracted values.
    func map<T0, T1>(
        _ keyPath0: KeyPath<Self.Output, T0>,
        _ keyPath1: KeyPath<Self.Output, T1>
    ) -> DeferredFuture<(T0, T1), Failure> {
        map { ($0[keyPath: keyPath0], $0[keyPath: keyPath1]) }
    }

    /// Maps the result of this `DeferredFuture` using three given key paths.
    ///
    /// - Parameters:
    ///   - keyPath0: The first key path to extract a value from the output.
    ///   - keyPath1: The second key path to extract another value from the output.
    ///   - keyPath2: The third key path to extract yet another value from the output.
    /// - Returns: A new `DeferredFuture` that contains a tuple of the extracted values.
    func map<T0, T1, T2>(
        _ keyPath0: KeyPath<Self.Output, T0>,
        _ keyPath1: KeyPath<Self.Output, T1>,
        _ keyPath2: KeyPath<Self.Output, T2>
    ) -> DeferredFuture<(T0, T1, T2), Failure> {
        map { ($0[keyPath: keyPath0], $0[keyPath: keyPath1], $0[keyPath: keyPath2]) }
    }
}

// MARK: - Specifying Schedulers

public extension DeferredFutureProtocol {
    /// Subscribes to the fulfillment of this `DeferredFuture` on a specified scheduler.
    ///
    /// - Parameters:
    ///   - scheduler: The scheduler on which to perform the subscription.
    ///   - options: Scheduler-specific options. Defaults to `nil`.
    /// - Returns: A new `DeferredFuture` that is fulfilled on the specified scheduler.
    @_disfavoredOverload
    func subscribe<S>(
        on scheduler: S,
        options: S.SchedulerOptions? = nil
    ) -> DeferredFuture<Output, Failure> where S: Scheduler {
        let outerAttempt = attemptToFulfill
        return DeferredFuture { innerPromise in
            scheduler.schedule(options: options) {
                outerAttempt { outerResult in
                    innerPromise(outerResult)
                }
            }
        }
    }

    /// Receives the result of this `DeferredFuture` on a specified scheduler.
    ///
    /// - Parameters:
    ///   - scheduler: The scheduler on which to receive the result.
    ///   - options: Scheduler-specific options. Defaults to `nil`.
    /// - Returns: A new `DeferredFuture` that receives the result on the specified scheduler.
    @_disfavoredOverload
    func receive<S>(
        on scheduler: S,
        options: S.SchedulerOptions? = nil
    ) -> DeferredFuture<Output, Failure> where S: Scheduler {
        futureLiftResult { outerResult, innerPromise in
            scheduler.schedule(options: options) {
                innerPromise(outerResult)
            }
        }
    }

    /// Configures the future to receive values on the main thread using `UIScheduler`.
    /// `UIScheduler` will receive synchronously on the main thread if the upstream publisher
    /// emits on the main thread, otherwise it will dispatch to main asynchronously.
    ///
    /// - Returns: A `DeferredFuture` instance that receives values on the main UI thread.
    @_disfavoredOverload
    func receiveOnMain() -> DeferredFuture<Output, Failure> {
        futureLiftResult { outerResult, innerPromise in
            guard UIScheduler.shared.onMainThread() else {
                DispatchQueue.main.async {
                    innerPromise(outerResult)
                }
                return
            }

            innerPromise(outerResult)
        }
    }

    /// Configures the future to receive values on the main thread using `DispatchQueue`.
    /// Unlike `receiveOnMain`, this will always dispatch asynchronously to the main queue,
    /// even if the upstream future emits on the main thread.
    ///
    /// - Returns: A `DeferredFuture` instance that receives values on the main thread.
    @_disfavoredOverload
    func receiveOnMainAsync() -> DeferredFuture<Output, Failure> {
        futureLiftResult { outerResult, innerPromise in
            DispatchQueue.main.async {
                innerPromise(outerResult)
            }
        }
    }

    /// Configures the future to receive values on the main run loop using `RunLoop`.
    /// This will only schedule the future to receive events when the current RunLoop
    /// has finished processing (e.g. it will wait until the user finishes scrolling.)
    ///
    /// - Returns: A `DeferredFuture` instance that receives values on the main run loop.
    @_disfavoredOverload
    func receiveOnMainRunLoop() -> DeferredFuture<Output, Failure> {
        futureLiftResult { outerResult, innerPromise in
            RunLoop.main.schedule {
                innerPromise(outerResult)
            }
        }
    }
}
