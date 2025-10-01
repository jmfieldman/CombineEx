//
//  Publisher+SchedulerExtensions.swift
//  Copyright © 2025 Jason Fieldman.
//

import Combine
import Foundation

#if swift(>=6)
@preconcurrency import Dispatch
#else
import Dispatch
#endif

public extension Publisher {
    /// Configures the publisher to receive values on the main thread using `UIScheduler`.
    /// `UIScheduler` will receive synchronously on the main thread if the upstream publisher
    /// emits on the main thread, otherwise it will dispatch to main asynchronously.
    ///
    /// - Returns: A `Publishers.ReceiveOn` instance that receives values on the main UI thread.
    func receiveOnMain() -> Publishers.ReceiveOn<Self, UIScheduler> {
        receive(on: UIScheduler.shared)
    }

    /// Configures the publisher to receive values on the main thread using `DispatchQueue`.
    /// Unlike `receiveOnMain`, this will always dispatch asynchronously to the main queue,
    /// even if the upstream publisher emits on the main thread.
    ///
    /// - Returns: A `Publishers.ReceiveOn` instance that receives values on the main thread.
    func receiveOnMainAsync() -> Publishers.ReceiveOn<Self, DispatchQueue> {
        receive(on: DispatchQueue.main)
    }

    /// Configures the publisher to receive values on the main run loop using `RunLoop`.
    /// This will only schedule the publisher to receive events when the current RunLoop
    /// has finished processing (e.g. it will wait until the user finishes scrolling.)
    ///
    /// - Returns: A `Publishers.ReceiveOn` instance that receives values on the main run loop.
    func receiveOnMainRunLoop() -> Publishers.ReceiveOn<Self, RunLoop> {
        receive(on: RunLoop.main)
    }

    /// Configures the publisher to receive values on a background queue with the specified QoS.
    func receiveInBackground(qos: DispatchQoS.QoSClass = .default) -> Publishers.ReceiveOn<Self, DispatchQueue> {
        receive(on: DispatchQueue.global(qos: qos))
    }
}
