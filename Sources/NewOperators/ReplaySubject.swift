//
//  ReplaySubject.swift
//  Copyright © 2025 Jason Fieldman.
//

import Combine
import Foundation

// The follow implementation comes from https://github.com/CombineCommunity/CombineExt
// We require a ReplaySubject in the Property(initial:then:) initializer, because using
// a normal CurrentValueSubject in the multicast will stop republishing if 'then:' completes.

/// A `ReplaySubject` is a subject that can buffer one or more values. It stores value events, up to its `bufferSize` in a
/// first-in-first-out manner and then replays it to
/// future subscribers and also forwards completion events.
///
/// The implementation borrows heavily from [Entwine’s](https://github.com/tcldr/Entwine/blob/b839c9fcc7466878d6a823677ce608da998b95b9/Sources/Entwine/Operators/ReplaySubject.swift).
@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public final class ReplaySubject<Output, Failure: Error>: Subject {
    public typealias Output = Output
    public typealias Failure = Failure

    private let bufferSize: Int
    private var buffer = [Output]()

    // Keeping track of all live subscriptions, so `send` events can be forwarded to them.
    private(set) var subscriptions = [Subscription<AnySubscriber<Output, Failure>>]()

    private var completion: Subscribers.Completion<Failure>?
    private var isActive: Bool { completion == nil }

    private let lock = NSRecursiveLock()

    /// Create a `ReplaySubject`, buffering up to `bufferSize` values and replaying them to new subscribers
    /// - Parameter bufferSize: The maximum number of value events to buffer and replay to all future subscribers.
    public init(bufferSize: Int) {
        self.bufferSize = bufferSize
    }

    public func send(_ value: Output) {
        let subscriptions: [Subscription<AnySubscriber<Output, Failure>>]

        do {
            lock.lock()
            defer { lock.unlock() }

            guard isActive else { return }

            buffer.append(value)
            if buffer.count > bufferSize {
                buffer.removeFirst()
            }

            subscriptions = self.subscriptions
        }

        subscriptions.forEach { $0.forwardValueToBuffer(value) }
    }

    public func send(completion: Subscribers.Completion<Failure>) {
        let subscriptions: [Subscription<AnySubscriber<Output, Failure>>]

        do {
            lock.lock()
            defer { lock.unlock() }

            guard isActive else { return }

            self.completion = completion

            subscriptions = self.subscriptions
        }

        subscriptions.forEach { $0.forwardCompletionToBuffer(completion) }

        lock.lock()
        defer { self.lock.unlock() }
        self.subscriptions.removeAll()
    }

    public func send(subscription: Combine.Subscription) {
        subscription.request(.unlimited)
    }

    public func receive<Subscriber: Combine.Subscriber>(subscriber: Subscriber) where Failure == Subscriber.Failure, Output == Subscriber.Input {
        let subscriberIdentifier = subscriber.combineIdentifier

        let subscription = Subscription(downstream: AnySubscriber(subscriber)) { [weak self] in
            self?.completeSubscriber(withIdentifier: subscriberIdentifier)
        }

        do {
            lock.lock()
            defer { lock.unlock() }

            subscription.replay(buffer, completion: completion)
            subscriptions.append(subscription)
        }

        subscriber.receive(subscription: subscription)
    }

    private func completeSubscriber(withIdentifier subscriberIdentifier: CombineIdentifier) {
        lock.lock()
        defer { self.lock.unlock() }

        subscriptions.removeAll { $0.innerSubscriberIdentifier == subscriberIdentifier }
    }
}

@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension ReplaySubject {
    final class Subscription<Downstream: Subscriber>: Combine.Subscription where Output == Downstream.Input, Failure == Downstream.Failure {
        private var demandBuffer: DemandBuffer<Downstream>?
        private var cancellationHandler: (() -> Void)?

        fileprivate let innerSubscriberIdentifier: CombineIdentifier

        init(downstream: Downstream, cancellationHandler: (() -> Void)?) {
            self.demandBuffer = DemandBuffer(subscriber: downstream)
            self.innerSubscriberIdentifier = downstream.combineIdentifier
            self.cancellationHandler = cancellationHandler
        }

        func replay(_ buffer: [Output], completion: Subscribers.Completion<Failure>?) {
            buffer.forEach(forwardValueToBuffer)

            if let completion {
                forwardCompletionToBuffer(completion)
            }
        }

        func forwardValueToBuffer(_ value: Output) {
            _ = demandBuffer?.buffer(value: value)
        }

        func forwardCompletionToBuffer(_ completion: Subscribers.Completion<Failure>) {
            demandBuffer?.complete(completion: completion)
        }

        func request(_ demand: Subscribers.Demand) {
            _ = demandBuffer?.demand(demand)
        }

        func cancel() {
            cancellationHandler?()
            cancellationHandler = nil

            demandBuffer = nil
        }
    }
}

/// A buffer responsible for managing the demand of a downstream
/// subscriber for an upstream publisher
///
/// It buffers values and completion events and forwards them dynamically
/// according to the demand requested by the downstream
///
/// In a sense, the subscription only relays the requests for demand, as well
/// the events emitted by the upstream — to this buffer, which manages
/// the entire behavior and backpressure contract
@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
class DemandBuffer<S: Subscriber> {
    private let lock = NSRecursiveLock()
    private var buffer = [S.Input]()
    private let subscriber: S
    private var completion: Subscribers.Completion<S.Failure>?
    private var demandState = Demand()

    /// Initialize a new demand buffer for a provided downstream subscriber
    ///
    /// - parameter subscriber: The downstream subscriber demanding events
    init(subscriber: S) {
        self.subscriber = subscriber
    }

    /// Buffer an upstream value to later be forwarded to
    /// the downstream subscriber, once it demands it
    ///
    /// - parameter value: Upstream value to buffer
    ///
    /// - returns: The demand fulfilled by the bufferr
    func buffer(value: S.Input) -> Subscribers.Demand {
        precondition(
            completion == nil,
            "How could a completed publisher sent values?! Beats me 🤷‍♂️"
        )
        lock.lock()
        defer { lock.unlock() }

        switch demandState.requested {
        case .unlimited:
            return subscriber.receive(value)
        default:
            buffer.append(value)
            return flush()
        }
    }

    /// Complete the demand buffer with an upstream completion event
    ///
    /// This method will deplete the buffer immediately,
    /// based on the currently accumulated demand, and relay the
    /// completion event down as soon as demand is fulfilled
    ///
    /// - parameter completion: Completion event
    func complete(completion: Subscribers.Completion<S.Failure>) {
        precondition(
            self.completion == nil,
            "Completion have already occured, which is quite awkward 🥺"
        )

        self.completion = completion
        _ = flush()
    }

    /// Signal to the buffer that the downstream requested new demand
    ///
    /// - note: The buffer will attempt to flush as many events rqeuested
    ///         by the downstream at this point
    func demand(_ demand: Subscribers.Demand) -> Subscribers.Demand {
        flush(adding: demand)
    }

    /// Flush buffered events to the downstream based on the current
    /// state of the downstream's demand
    ///
    /// - parameter newDemand: The new demand to add. If `nil`, the flush isn't the
    ///                        result of an explicit demand change
    ///
    /// - note: After fulfilling the downstream's request, if completion
    ///         has already occured, the buffer will be cleared and the
    ///         completion event will be sent to the downstream subscriber
    private func flush(adding newDemand: Subscribers.Demand? = nil) -> Subscribers.Demand {
        lock.lock()
        defer { lock.unlock() }

        if let newDemand {
            demandState.requested += newDemand
        }

        // If buffer isn't ready for flushing, return immediately
        guard demandState.requested > 0 || newDemand == Subscribers.Demand.none else { return .none }

        while !buffer.isEmpty, demandState.processed < demandState.requested {
            demandState.requested += subscriber.receive(buffer.remove(at: 0))
            demandState.processed += 1
        }

        if let completion {
            // Completion event was already sent
            buffer = []
            demandState = .init()
            self.completion = nil
            subscriber.receive(completion: completion)
            return .none
        }

        let sentDemand = demandState.requested - demandState.sent
        demandState.sent += sentDemand
        return sentDemand
    }
}

// MARK: - Private Helpers

@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
private extension DemandBuffer {
    /// A model that tracks the downstream's
    /// accumulated demand state
    struct Demand {
        var processed: Subscribers.Demand = .none
        var requested: Subscribers.Demand = .none
        var sent: Subscribers.Demand = .none
    }
}

// MARK: - Internally-scoped helpers

@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension Subscription {
    /// Reqeust demand if it's not empty
    ///
    /// - parameter demand: Requested demand
    func requestIfNeeded(_ demand: Subscribers.Demand) {
        guard demand > .none else { return }
        request(demand)
    }
}

@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension Subscription? {
    /// Cancel the Optional subscription and nullify it
    mutating func kill() {
        self?.cancel()
        self = nil
    }
}
