//
//  AsyncFuture.swift
//  Copyright © 2025 Jason Fieldman.
//

import Combine
import Foundation

private final class FutureBox<Output, Failure: Error> {
    let future: any DeferredFutureProtocol<Output, Failure>
    var cancellable: AnyCancellable?
    init(_ future: any DeferredFutureProtocol<Output, Failure>) {
        self.future = future as? AnyDeferredFuture<Output, Failure> ?? future.eraseToAnyDeferredFuture()
    }
}

public extension DeferredFutureProtocol {
    /// Allows a DeferredFuture to be used in the context of structured concurrency
    /// as a typical async function. It will either return its Output or throw its Failure.
    ///
    /// This function captures the future until it emits an output or failure.
    func asyncThrowing() async throws(Failure) -> Output {
        let result: Result<Output, Failure> = await withUnsafeContinuation { [self] continuation in
            var futureBox: FutureBox? = FutureBox(self)
            futureBox?.cancellable = sink(receiveCompletion: { result in
                switch result {
                case let .failure(error):
                    continuation.resume(returning: .failure(error))
                case .finished:
                    break
                }
                futureBox = nil
            }, receiveValue: { value in
                continuation.resume(returning: .success(value))
                futureBox = nil
            })
        }

        switch result {
        case let .success(output):
            return output
        case let .failure(failure):
            throw failure
        }
    }

    /// Allows a DeferredFuture to be used in the context of structured concurrency
    /// as a typical async function. use `asyncThrowing` for futures that can return
    /// a non-Never failure.
    ///
    /// This function captures the future until it emits an output or failure.
    func async() async -> Output where Failure == Never {
        await withUnsafeContinuation { [self] continuation in
            var futureBox: FutureBox? = FutureBox(self)
            futureBox?.cancellable = sink(receiveValue: { value in
                continuation.resume(returning: value)
                futureBox = nil
            })
        }
    }
}
