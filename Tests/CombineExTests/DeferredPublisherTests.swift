//
//  DeferredPublisherTests.swift
//  Copyright © 2025 Jason Fieldman.
//

@testable import CombineEx
import XCTest

/// A generic error enum we can use for these test cases
private enum TestError: Error {
    case error1
}

final class DeferredPublisherTests: XCTestCase {
    func testBasicDeferredPublisher() {
        basicSingleFutureTest(input: 1, output: 1) { $0 }
    }

    /// This is just a compilation test to ensure that setFailureType works
    func testSetFailureType() {
        let anyDeferredPublisher: AnyDeferredPublisher<Int, TestError> =
            Deferred { Just(1) }
                .setFailureType(to: TestError.self)
                .eraseToAnyDeferredPublisher()

        XCTAssertNotNil(anyDeferredPublisher)
    }

    // MARK: Map

    /// Make sure there are no compiler issues type-checking multiple stacked functions
    /// that are potentially ambiguous between deferred or not.
    func testAmbiguousMap() {
        var t1 = 0
        let testDeferredCanMap1 = Deferred { Just(1) }
            .map { $0 + 1 }
            .map { $0 + 1 }
            .map { $0 + 1 }

        let _ = testDeferredCanMap1.sink(receiveValue: { t1 = $0 })
        XCTAssertEqual(t1, 4)

        var t2 = 0
        let testDeferredCanMap2 = Deferred { Just(1).setFailureType(to: TestError.self) }
            .map { $0 + 1 }
            .map { $0 + 1 }
            .map { $0 + 1 }
            .map { $0 + 1 }
            .map { $0 + 1 }
            .map { $0 + 1 }
            .eraseToAnyDeferredPublisher()

        let _ = testDeferredCanMap2.sink(receiveCompletion: { _ in }, receiveValue: { t2 = $0 })
        XCTAssertEqual(t2, 7)

        var t3 = 0
        let testDeferredCanMap3 = Deferred { Just(1).setFailureType(to: TestError.self) }
            .map { $0 + 1 }
            .map { $0 + 1 }
            .map { $0 + 1 }
            .map { $0 + 1 }
            .eraseToAnyPublisher()

        let _ = testDeferredCanMap3.sink(receiveCompletion: { _ in }, receiveValue: { t3 = $0 })
        XCTAssertEqual(t3, 5)
    }

    func testMapSingle() {
        basicSingleFutureTest(input: 1, output: 2) { $0.map { $0 + 1 }.eraseToAnyDeferredPublisher() }
        basicSingleFutureTest(input: "Hello", output: "HelloHello") { $0.map { $0 + $0 }.eraseToAnyDeferredPublisher() }
    }
}

// MARK: Test Helpers

private extension DeferredPublisherTests {
    func basicSingleFutureTest<Output: Equatable>(
        input: Output,
        output: Output,
        _ transform: @escaping (AnyDeferredPublisher<Output, TestError>) -> AnyDeferredPublisher<Output, TestError>
    ) {
        var countableInnerFire = 0
        var sinkResult: Output?
        let countableFuture = CountableFuture<Output, TestError> {
            countableInnerFire += 1
            $0(.success(input))
        }

        let anyDeferredPublisher: AnyDeferredPublisher<Output, TestError> =
            transform(Deferred { countableFuture }.eraseToAnyDeferredPublisher())

        XCTAssertEqual(countableInnerFire, 0)
        XCTAssertEqual(countableFuture.receiveCount, 0)

        _ = anyDeferredPublisher.assertSink { sinkResult = $0 }

        XCTAssertEqual(countableInnerFire, 1)
        XCTAssertEqual(sinkResult, output)
        XCTAssertEqual(countableFuture.receiveCount, 1)
    }
}
