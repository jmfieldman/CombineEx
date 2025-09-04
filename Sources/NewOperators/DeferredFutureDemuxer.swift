//
//  DeferredFutureDemuxer.swift
//  Copyright © 2025 Jason Fieldman.
//

import Combine
import Foundation

public final class DeferredFutureDemuxer<Key: Hashable, Output, Failure: Error> {
    /// The operation we are initialized with
    private let operation: (Key) -> AnyDeferredFuture<Output, Failure>

    /// Queue to begin execution of internal futures.
    private let promiseQueue: DispatchQueue

    /// Lookup of unresolved open promises
    private var openPromises: [Key: [Future<Output, Failure>.Promise]] = [:]

    /// Ensure our operations are synchronized properly
    private let operationLock = NSLock()

    /// Initialize the builder with the given key -> future operation.
    ///
    /// The operation block takes an input key and returns an AnyDeferredFuture.
    /// When any of these deferred futures (with the same key) are executed in parallel:
    ///  - Only one of them will perform work
    ///  - The result of that one future will be broadcast to all promises
    ///
    /// You can decide which DispatchQueue to initiate the future's work.
    /// If you pass nil it will use the global default background queue.
    public init(_ operation: @escaping (Key) -> AnyDeferredFuture<Output, Failure>, promiseQueue: DispatchQueue? = nil) {
        self.operation = operation
        self.promiseQueue = promiseQueue ?? .global(qos: .default)
    }

    /// Build a deferred future for the given input key.
    ///
    /// The returned future retains `self` for its lifetime, since it needs
    /// `self` to coordinate its response value. There should be no retain
    /// cycle unless you explicitly retain the DeferredFutureDemuxer as a side
    /// effect of this future's emission.
    ///
    /// Note that any in-flight future work execution will not be stopped if outer
    /// cancellables are cancelled. The promise output will simply be ignored.
    public func build(key: Key) -> AnyDeferredFuture<Output, Failure> {
        DeferredFuture<Output, Failure> { [self] promise in
            operationLock.lock()
            defer { operationLock.unlock() }

            let isAlreadyOperating = openPromises[key] != nil
            openPromises[key, default: []].append(promise)

            // If we're already operating then we can break early without
            // starting more work.
            guard !isAlreadyOperating else {
                return
            }

            // Otherwise kick off work for our key
            promiseQueue.async { [self] in
                operation(key)
                    .sink(
                        duringLifetimeOf: self,
                        receiveValue: { [self] value in
                            resolve(key, result: .success(value))
                        },
                        receiveCompletion: { [self] completion in
                            switch completion {
                            case .finished: break
                            case let .failure(failure):
                                resolve(key, result: .failure(failure))
                            }
                        }
                    )
            }
        }.eraseToAnyDeferredFuture()
    }

    /// Dispatch the resolution to all promises and wipe promises for that key.
    private func resolve(_ key: Key, result: Result<Output, Failure>) {
        operationLock.lock()
        defer { operationLock.unlock() }

        openPromises[key]?.forEach { $0(result) }
        openPromises[key] = nil
    }
}
