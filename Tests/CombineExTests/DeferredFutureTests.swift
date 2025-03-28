//
//  DeferredFutureTests.swift
//  Copyright © 2024 Jason Fieldman.
//

@testable import CombineEx
import XCTest

/// A generic error enum we can use for these test cases
private enum TestError: Error {
    case error1
}

final class DeferredFutureTests: XCTestCase {
    // MARK: - Compilation Tests

    func testCompilation() {
        let future = TestableDeferredFuture(emission: 1, delay: 0.1)

        /// Ensures that `map` can be used without compiler ambiguity warnings.
        /// The `untypedMapped` variable will be a normal Publisher.
        let t1 = future.map { $0 + 1 }
        let p1 = t1.eraseToAnyPublisher()
        XCTAssertNotNil(p1)

        /// Ensure that `map` can be used to explicitly return a `DeferredFuture`
        let t2: DeferredFuture<Int, TestError> = future.map { $0 + 1 }
        let p2 = t2.eraseToAnyPublisher()
        XCTAssertNotNil(p2)

        /// Ensure that using `eraseToAnyDeferredFuture` works after the ambiguous
        /// `map` call.
        let t4 = future.map { $0 + 1 }.eraseToAnyDeferredFuture()
        let p4 = t4.eraseToAnyPublisher()
        XCTAssertNotNil(p4)

        /// Ensure that ambiguous `map` can be used with eraseToAnyPublisher
        let t5: AnyPublisher = future.map { $0 + 1 }.eraseToAnyPublisher()
        let p5 = t5.eraseToAnyPublisher()
        XCTAssertNotNil(p5)
    }

    // MARK: - Basic

    func testBasic() {
        let future = TestableDeferredFuture(emission: 1, delay: 0.1)

        _testRig(
            expectedFailure: nil,
            outputExpectation: { $0 == 1 },
            future: future,
            attemptables: [future]
        ) {
            $0.eraseToAnyDeferredFuture()
        }
    }

    /// This test shows the general danger of Futures, in that they execute
    /// their internal promise closure immediately on construction, and then simply
    /// republish the result. They are neither warm or cold.
    func testUnderlyingPremise() {
        var futureCount = 0
        let future = Future<Int, TestError> { promise in
            futureCount += 1
            promise(.success(futureCount))
        }

        XCTAssertEqual(futureCount, 1)

        future
            .handleValue { XCTAssertEqual($0, 1) }
            .sink(duringLifetimeOf: self)
        future
            .handleValue { XCTAssertEqual($0, 1) }
            .sink(duringLifetimeOf: self)

        // The work inside the future is not triggered by the subscription
        XCTAssertEqual(futureCount, 1)
    }

    // MARK: - Mapping Elements

    func testMap() {
        let future = TestableDeferredFuture(emission: 1, delay: 0.1)

        _testRig(
            expectedFailure: nil,
            outputExpectation: { $0 == 2 },
            future: future,
            attemptables: [future]
        ) {
            $0.map { $0 + 1 }.eraseToAnyDeferredFuture()
        }
    }

    func testFlatMap() {
        let p1 = TestableDeferredFuture(emission: 1, delay: 0.1)
        let p2 = TestableDeferredFuture(emission: 2, delay: 0.1)
        let future = p1.flatMap { _ in p2 }.eraseToAnyDeferredFuture()

        _testRig(
            expectedFailure: nil,
            outputExpectation: { $0 == 2 },
            future: future,
            attemptables: [p1, p2]
        ) {
            $0.eraseToAnyDeferredFuture()
        }
    }

    func testFlatMapDynamic() {
        let future = TestableDeferredFuture(emission: 100, delay: 0.1)

        _testRig(
            expectedFailure: nil,
            outputExpectation: { $0 == 175 },
            future: future,
            attemptables: [future]
        ) {
            $0.flatMap { outer in
                TestableDeferredFuture(emission: outer * 2, delay: 0.1).flatMap { inner in
                    TestableDeferredFuture(emission: inner - 50, delay: 0.0).map { $0 + 25 }
                }
            }.eraseToAnyDeferredFuture()
        }
    }

    // MARK: - Filtering Elements

    func testReplaceError() {
        let future = TestableDeferredFuture<Int>(failure: .error1, delay: 0)

        _testRig(
            expectedFailure: nil,
            outputExpectation: { $0 == 3 },
            future: future,
            attemptables: [future]
        ) {
            $0.replaceError(with: 3).eraseToAnyDeferredFuture()
        }
    }

    // MARK: - Combining Elements

    func testCombineLatestP_Success() {
        let publisher1 = TestableDeferredFuture(emission: 1, delay: 0.1)
        let publisher2 = TestableDeferredFuture(emission: "Hello", delay: 0.1)
        let combined: DeferredFuture = publisher1.combineLatest(publisher2)

        _testRig(
            expectedFailure: nil,
            outputExpectation: { $0.0 == 1 && $0.1 == "Hello" },
            future: combined,
            attemptables: [publisher1, publisher2]
        ) {
            $0.eraseToAnyDeferredFuture()
        }
    }

    func testCombineLatestP_FailureSelf() {
        let publisher1 = TestableDeferredFuture<Int>(failure: .error1, delay: 0.1)
        let publisher2 = TestableDeferredFuture(emission: "Hello", delay: 0.1)
        let combined: DeferredFuture = publisher1.combineLatest(publisher2)

        _testRig(
            expectedFailure: .error1,
            outputExpectation: nil,
            future: combined,
            attemptables: [publisher1, publisher2]
        ) {
            $0.eraseToAnyDeferredFuture()
        }
    }

    func testCombineLatestP_FailureP() {
        let publisher1 = TestableDeferredFuture(emission: "Hello", delay: 0.1)
        let publisher2 = TestableDeferredFuture<Int>(failure: .error1, delay: 0.1)
        let combined: DeferredFuture = publisher1.combineLatest(publisher2)

        _testRig(
            expectedFailure: .error1,
            outputExpectation: nil,
            future: combined,
            attemptables: [publisher1, publisher2]
        ) {
            $0.eraseToAnyDeferredFuture()
        }
    }

    func testArrayCombineLatest_Success() {
        let publisher1 = TestableDeferredFuture<Int>(emission: 1, delay: 0.01)
        let publisher2 = TestableDeferredFuture<Int>(emission: 2, delay: 0.1)
        let publisher3 = TestableDeferredFuture<Int>(emission: 3, delay: 0)
        let combined = [publisher1, publisher2, publisher3].combineLatest().eraseToAnyDeferredFuture()

        _testRig(
            expectedFailure: nil,
            outputExpectation: { $0 == [1, 2, 3] },
            future: combined,
            attemptables: [publisher1, publisher2, publisher3]
        ) {
            $0.eraseToAnyDeferredFuture()
        }
    }

    func testArrayCombineLatest_Failure() {
        let publisher1 = TestableDeferredFuture<Int>(emission: 1, delay: 0.01)
        let publisher2 = TestableDeferredFuture<Int>(failure: .error1, delay: 0.1)
        let publisher3 = TestableDeferredFuture<Int>(emission: 3, delay: 0)
        let combined = [publisher1, publisher2, publisher3].combineLatest().eraseToAnyDeferredFuture()

        _testRig(
            expectedFailure: .error1,
            outputExpectation: nil,
            future: combined,
            attemptables: [publisher1, publisher2, publisher3]
        ) {
            $0.eraseToAnyDeferredFuture()
        }
    }

    // MARK: - Handling Events

    func testHandleValue() {
        let accumulation = TestBox(0)
        let future = TestableDeferredFuture(emission: 1, delay: 0.1)
        let operated: DeferredFuture = future
            .handleValue { accumulation.value += $0 }
            .handleError { _ in accumulation.value += 100 }
            .handleValue { accumulation.value += $0 }
            .handleError { _ in accumulation.value += 100 }
            .handleValue { accumulation.value += $0 }
            .handleError { _ in accumulation.value += 100 }

        _testRig(
            expectedFailure: nil,
            outputExpectation: { _ in accumulation.value == 3 },
            future: operated,
            attemptables: [future]
        ) {
            $0.eraseToAnyDeferredFuture()
        }
    }

    func testHandleError() {
        let accumulation = TestBox(0)
        let future = TestableDeferredFuture<Int>(failure: .error1, delay: 0.1)
        let operated: DeferredFuture = future
            .handleValue { _ in accumulation.value += 100 }
            .handleError { _ in accumulation.value += 1 }
            .handleValue { _ in accumulation.value += 100 }
            .handleError { _ in accumulation.value += 1 }
            .handleValue { _ in accumulation.value += 100 }
            .handleError { _ in accumulation.value += 1 }

        _testRig(
            expectedFailure: .error1,
            outputExpectation: nil,
            future: operated,
            attemptables: [future]
        ) {
            $0.eraseToAnyDeferredFuture()
        }

        XCTAssertEqual(accumulation.value, 3)
    }

    // MARK: - Retention

    /// Verify that the AnyDeferredFuture lifecycles do not affect the
    /// resolution of their subscribed inner publishers.
    func testRetention() {
        var capturedCancellable: AnyCancellable?

        weak var weakFuture1: AnyDeferredFuture<Int, Never>?
        weak var weakFuture2: AnyDeferredFuture<Int, Never>?

        var response1: Int? = nil
        var response2: Int? = nil

        let expectation = XCTestExpectation(description: "wait")

        autoreleasepool {
            let def1 = DeferredFuture<Int, Never> { promise in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    promise(.success(1))
                }
            }.eraseToAnyDeferredFuture()

            let def2 = DeferredFuture<Int, Never> { promise in
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    promise(.success(10))
                }
            }.eraseToAnyDeferredFuture()

            weakFuture1 = def1
            weakFuture2 = def2

            // This will be terminated because it has no surviving cancellable
            _ = weakFuture1?
                .map { $0 + 1 }
                .sink { response1 = $0 }

            // This will not be terminated because it has a surviving cancellable
            capturedCancellable = weakFuture2?
                .map { $0 + 1 }
                .sink {
                    response2 = $0
                    expectation.fulfill()
                }
        }

        XCTAssertNil(weakFuture1)
        XCTAssertNil(weakFuture2)

        wait(for: [expectation], timeout: 2)

        XCTAssertNotNil(capturedCancellable)
        XCTAssertNil(response1)
        XCTAssertEqual(response2, 11)
    }
}

// MARK: - Utils

private protocol Attemptable {
    var attempted: Bool { get }
}

private class TestableDeferredFuture<T>: AnyDeferredFuture<T, TestError>, Attemptable {
    var attempted: Bool = false

    init(emission: T, delay: TimeInterval) {
        var markAttempted: (() -> Void)? = nil
        super.init(DeferredFuture { promise in
            markAttempted?()
            if delay > 0 {
                DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                    promise(.success(emission))
                }
            } else {
                promise(.success(emission))
            }
        })

        markAttempted = { [weak self] in self?.attempted = true }
    }

    init(failure: TestError, delay: TimeInterval) {
        var markAttempted: (() -> Void)? = nil
        super.init(DeferredFuture { promise in
            markAttempted?()
            if delay > 0 {
                DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                    promise(.failure(failure))
                }
            } else {
                promise(.failure(failure))
            }
        })

        markAttempted = { [weak self] in self?.attempted = true }
    }
}

private extension DeferredFutureTests {
    func _testRig<T>(
        expectedFailure: TestError?,
        outputExpectation: ((T) -> Bool)?,
        future: some DeferredFutureProtocol<T, TestError>,
        attemptables: [Attemptable],
        futureOperation: (any DeferredFutureProtocol<T, TestError>) -> AnyDeferredFuture<T, TestError>
    ) {
        let operatedFuture = futureOperation(future)
        XCTAssert(attemptables.allSatisfy { !$0.attempted })

        var receivedFinish = false
        var receivedValue = false
        var receivedFailure: TestError?
        var output: T?
        let expectation = XCTestExpectation(description: "completion expected")

        let cancellable = operatedFuture.sink { completion in
            switch completion {
            case .finished:
                receivedFinish = true
                expectation.fulfill()
            case let .failure(failure):
                receivedFailure = failure
                expectation.fulfill()
            }
        } receiveValue: { value in
            receivedValue = true
            output = value
        }

        wait(for: [expectation], timeout: 3.0)
        if let expectedFailure {
            XCTAssertEqual(receivedFailure, expectedFailure)
        } else {
            XCTAssert(receivedFinish)
        }

        if let outputExpectation {
            XCTAssert(receivedValue)
            guard let output else {
                XCTFail("No output, but expected")
                return
            }
            XCTAssert(outputExpectation(output))
        } else {
            XCTAssert(!receivedValue)
        }

        XCTAssert(attemptables.allSatisfy(\.attempted))

        cancellable.cancel()
    }
}

class TestBox<T> {
    var value: T
    init(_ initial: T) { self.value = initial }
}
