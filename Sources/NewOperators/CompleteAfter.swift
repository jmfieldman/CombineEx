//
//  CompleteAfter.swift
//  Copyright © 2025 Jason Fieldman.
//

import Combine
import Foundation

public extension Publisher {
    func complete(
        after: TimeInterval
    ) -> Publishers.PrefixUntilOutput<Self, Publishers.Delay<Just<Void>, DispatchQueue>> {
        prefix(untilOutputFrom: Just(()).delay(for: .seconds(after), scheduler: DispatchQueue.main))
    }

    func complete<S>(
        after stride: S.SchedulerTimeType.Stride,
        tolerance: S.SchedulerTimeType.Stride? = nil,
        scheduler: S,
        options: S.SchedulerOptions? = nil
    ) -> Publishers.PrefixUntilOutput<Self, Publishers.Delay<Just<Void>, S>> where S: Scheduler {
        prefix(untilOutputFrom: Just(()).delay(for: stride, tolerance: tolerance, scheduler: scheduler, options: options))
    }
}

public extension DeferredPublisherProtocol {
    @_disfavoredOverload
    func complete(
        after: TimeInterval
    ) -> Deferred<Publishers.PrefixUntilOutput<WrappedPublisher, Publishers.Delay<Just<Void>, DispatchQueue>>> where WrappedPublisher.Output == Output, WrappedPublisher.Failure == Failure {
        deferredLift { $0.prefix(untilOutputFrom: Just(()).delay(for: .seconds(after), scheduler: DispatchQueue.main)) }
    }

    @_disfavoredOverload
    func complete<S>(
        after stride: S.SchedulerTimeType.Stride,
        tolerance: S.SchedulerTimeType.Stride? = nil,
        scheduler: S,
        options: S.SchedulerOptions? = nil
    ) -> Deferred<Publishers.PrefixUntilOutput<WrappedPublisher, Publishers.Delay<Just<Void>, S>>> where S: Scheduler, WrappedPublisher.Output == Output, WrappedPublisher.Failure == Failure {
        deferredLift { $0.prefix(untilOutputFrom: Just(()).delay(for: stride, tolerance: tolerance, scheduler: scheduler, options: options)) }
    }
}
