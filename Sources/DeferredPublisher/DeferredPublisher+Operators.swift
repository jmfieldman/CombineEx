//
//  DeferredPublisher+Operators.swift
//  Copyright © 2025 Jason Fieldman.
//

import Combine
import Foundation

#if swift(>=6)
@preconcurrency import Dispatch
#else
import Dispatch
#endif

// MARK: Lift

public extension DeferredPublisherProtocol {
    /// A generic lift function that can operate on any DeferredPublisherProtocol
    /// implementation.
    ///
    /// Use this to transform the inner-wrapped publisher, and re-wrap it in a
    /// new Deferred publisher. This guarantees that transforms result in a new
    /// deferred publisher.
    @inlinable func deferredLift<TargetPublisher: Publisher>(
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

// MARK: Handling Errors

public extension DeferredPublisherProtocol {
    func `catch`<P>(
        _ handler: @escaping (WrappedPublisher.Failure) -> P
    ) -> Deferred<Publishers.Catch<WrappedPublisher, P>> where P: Publisher, WrappedPublisher.Output == P.Output {
        deferredLift { $0.catch(handler) }
    }
}

// MARK: Controlling Timing

public extension DeferredPublisherProtocol {
    /// Measures the interval between elements emitted by the publisher, using the specified scheduler and options.
    ///
    /// - Parameters:
    ///   - scheduler: The scheduler to use for measuring the interval.
    ///   - options: Optional scheduler-specific options.
    /// - Returns: A `Deferred` publisher that wraps a `Publishers.MeasureInterval` operator.
    @_disfavoredOverload
    func measureInterval<S>(
        using scheduler: S,
        options: S.SchedulerOptions? = nil
    ) -> Deferred<Publishers.MeasureInterval<WrappedPublisher, S>> where S: Scheduler {
        deferredLift { $0.measureInterval(using: scheduler, options: options) }
    }

    /// Debounces the publisher, delaying delivery of elements until a specified time interval has passed with no new elements.
    ///
    /// - Parameters:
    ///   - dueTime: The time interval to wait for new elements before delivering the last received element.
    ///   - scheduler: The scheduler to use for managing the due time.
    ///   - options: Optional scheduler-specific options.
    /// - Returns: A `Deferred` publisher that wraps a `Publishers.Debounce` operator.
    @_disfavoredOverload
    func debounce<S>(
        for dueTime: S.SchedulerTimeType.Stride,
        scheduler: S,
        options: S.SchedulerOptions? = nil
    ) -> Deferred<Publishers.Debounce<WrappedPublisher, S>> where S: Scheduler {
        deferredLift { $0.debounce(for: dueTime, scheduler: scheduler, options: options) }
    }

    /// Delays the delivery of elements by a specified time interval.
    ///
    /// - Parameters:
    ///   - interval: The time interval to delay the delivery of each element.
    ///   - tolerance: An optional amount of variability, in seconds, that is acceptable either side of the specified interval.
    ///   - scheduler: The scheduler to use for managing the delay.
    ///   - options: Optional scheduler-specific options.
    /// - Returns: A `Deferred` publisher that wraps a `Publishers.Delay` operator.
    @_disfavoredOverload
    func delay<S>(
        for interval: S.SchedulerTimeType.Stride,
        tolerance: S.SchedulerTimeType.Stride? = nil,
        scheduler: S,
        options: S.SchedulerOptions? = nil
    ) -> Deferred<Publishers.Delay<WrappedPublisher, S>> where S: Scheduler {
        deferredLift { $0.delay(for: interval, tolerance: tolerance, scheduler: scheduler, options: options) }
    }

    /// Throttles the publisher, ensuring that no more than one element is emitted in a specified time interval.
    ///
    /// - Parameters:
    ///   - interval: The maximum interval at which to emit elements.
    ///   - scheduler: The scheduler to use for managing the throttle interval.
    ///   - latest: A Boolean value indicating whether the latest element should be emitted if multiple elements are received during the interval.
    /// - Returns: A `Deferred` publisher that wraps a `Publishers.Throttle` operator.
    @_disfavoredOverload
    func throttle<S>(
        for interval: S.SchedulerTimeType.Stride,
        scheduler: S,
        latest: Bool
    ) -> Deferred<Publishers.Throttle<WrappedPublisher, S>> where S: Scheduler {
        deferredLift { $0.throttle(for: interval, scheduler: scheduler, latest: latest) }
    }

    /// Terminates the publisher if it does not receive an element within a specified time interval.
    ///
    /// - Parameters:
    ///   - interval: The maximum interval to wait for an element before terminating the publisher.
    ///   - scheduler: The scheduler to use for managing the timeout interval.
    ///   - options: Optional scheduler-specific options.
    ///   - customError: A closure that returns a custom error to emit if the timeout occurs.
    /// - Returns: A `Deferred` publisher that wraps a `Publishers.Timeout` operator.
    @_disfavoredOverload
    func timeout<S>(
        _ interval: S.SchedulerTimeType.Stride,
        scheduler: S,
        options: S.SchedulerOptions? = nil,
        customError: (() -> WrappedPublisher.Failure)? = nil
    ) -> Deferred<Publishers.Timeout<WrappedPublisher, S>> where S: Scheduler {
        deferredLift { $0.timeout(interval, scheduler: scheduler, options: options, customError: customError) }
    }
}

// MARK: Specifying Schedulers

public extension DeferredPublisherProtocol {
    /// Subscribes to the deferred publisher on a specified scheduler.
    ///
    /// - Parameters:
    ///   - scheduler: The scheduler on which to subscribe the publisher.
    ///   - options: Scheduler options used during subscription, such as `SchedulerOptions.Tracking`.
    /// - Returns: A `Deferred` publisher that subscribes on the specified scheduler.
    @_disfavoredOverload
    func subscribe<S: Scheduler>(
        on scheduler: S,
        options: S.SchedulerOptions? = nil
    ) -> Deferred<Publishers.SubscribeOn<WrappedPublisher, S>> where WrappedPublisher.Failure == Failure {
        // Lift the deferred publisher and apply the `subscribe(on:options:)` transformation.
        deferredLift { $0.subscribe(on: scheduler, options: options) }
    }

    /// Receives output from the deferred publisher on a specified scheduler.
    ///
    /// - Parameters:
    ///   - scheduler: The scheduler on which to receive output from the publisher.
    ///   - options: Scheduler options used during reception, such as `SchedulerOptions.Tracking`.
    /// - Returns: A `Deferred` publisher that receives output on the specified scheduler.
    @_disfavoredOverload
    func receive<S: Scheduler>(
        on scheduler: S,
        options: S.SchedulerOptions? = nil
    ) -> Deferred<Publishers.ReceiveOn<WrappedPublisher, S>> where WrappedPublisher.Failure == Failure {
        // Lift the deferred publisher and apply the `receive(on:options:)` transformation.
        deferredLift { $0.receive(on: scheduler, options: options) }
    }

    /// Configures the publisher to receive values on the main thread using `UIScheduler`.
    /// `UIScheduler` will receive synchronously on the main thread if the upstream publisher
    /// emits on the main thread, otherwise it will dispatch to main asynchronously.
    ///
    /// - Returns: A `Publishers.ReceiveOn` instance that receives values on the main UI thread.
    @_disfavoredOverload
    func receiveOnMain() -> Deferred<Publishers.ReceiveOn<WrappedPublisher, UIScheduler>> where WrappedPublisher.Failure == Failure {
        deferredLift { $0.receive(on: UIScheduler.shared) }
    }

    /// Configures the publisher to receive values on the main thread using `DispatchQueue`.
    /// Unlike `receiveOnMain`, this will always dispatch asynchronously to the main queue,
    /// even if the upstream publisher emits on the main thread.
    ///
    /// - Returns: A `Publishers.ReceiveOn` instance that receives values on the main thread.
    @_disfavoredOverload
    func receiveOnMainAsync() -> Deferred<Publishers.ReceiveOn<WrappedPublisher, DispatchQueue>> where WrappedPublisher.Failure == Failure {
        deferredLift { $0.receive(on: DispatchQueue.main) }
    }

    /// Configures the publisher to receive values on the main run loop using `RunLoop`.
    /// This will only schedule the publisher to receive events when the current RunLoop
    /// has finished processing (e.g. it will wait until the user finishes scrolling.)
    ///
    /// - Returns: A `Publishers.ReceiveOn` instance that receives values on the main run loop.
    @_disfavoredOverload
    func receiveOnMainRunLoop() -> Deferred<Publishers.ReceiveOn<WrappedPublisher, RunLoop>> where WrappedPublisher.Failure == Failure {
        deferredLift { $0.receive(on: RunLoop.main) }
    }
}

// MARK: Debugging

public extension DeferredPublisherProtocol {
    func handleEvents(
        receiveSubscription: ((any Subscription) -> Void)? = nil,
        receiveOutput: ((WrappedPublisher.Output) -> Void)? = nil,
        receiveCompletion: ((Subscribers.Completion<WrappedPublisher.Failure>) -> Void)? = nil,
        receiveCancel: (() -> Void)? = nil,
        receiveRequest: ((Subscribers.Demand) -> Void)? = nil
    ) -> Deferred<Publishers.HandleEvents<WrappedPublisher>> where WrappedPublisher: Publisher {
        deferredLift {
            $0.handleEvents(
                receiveSubscription: receiveSubscription,
                receiveOutput: receiveOutput,
                receiveCompletion: receiveCompletion,
                receiveCancel: receiveCancel,
                receiveRequest: receiveRequest
            )
        }
    }
}
