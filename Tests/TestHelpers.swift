//
//  TestHelpers.swift
//  Copyright © 2025 Jason Fieldman.
//

@testable import CombineEx
import XCTest

class CountableFuture<Output, Failure: Error>: Publisher {
    public private(set) var receiveCount: Int = 0
    let wrappedFuture: Deferred<Future<Output, Failure>>

    init(_ attemptToFulfill: @escaping (@escaping Future<Output, Failure>.Promise) -> Void) {
        self.wrappedFuture = Deferred {
            Future(attemptToFulfill)
        }
    }

    func receive<S>(subscriber: S) where S: Subscriber, Failure == S.Failure, Output == S.Input {
        receiveCount += 1
        wrappedFuture.receive(subscriber: subscriber)
    }
}

extension Publisher {
    func assertSink(_ receiveValue: @escaping (Output) -> Void) -> AnyCancellable {
        sink(receiveCompletion: { result in
            switch result {
            case .finished: break
            case let .failure(error): XCTAssert(false, "received error in assertSink: \(error)")
            }
        }, receiveValue: receiveValue)
    }
}

class Countable {
    var count: Int = 0
}
