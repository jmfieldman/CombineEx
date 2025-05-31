//
//  CustomTests.swift
//  Copyright © 2025 Jason Fieldman.
//

@testable import CombineEx
import XCTest

/// A generic error enum we can use for these test cases
private enum TestError: Error {
    case error1
}

final class CustomTests: XCTestCase {
    func testCustom_BasicValues() {
        let expectation = XCTestExpectation(description: "wait")
        let custom = DeferredCustom<Int, TestError> { handler in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                handler.sendValue(1)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                    handler.sendValue(2)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                        handler.sendCompletion(.finished)
                    }
                }
            }
        }

        var values: [Int] = []
        custom
            .handleValue { values.append($0) }
            .handleFinished { expectation.fulfill() }
            .handleError { XCTFail("unexpected error: \($0)") }
            .sink(duringLifetimeOf: self)

        wait(for: [expectation], timeout: 3)
        XCTAssertEqual(values, [1, 2])
    }

    func testCustom_BasicValues_ErasedToAny() {
        let expectation = XCTestExpectation(description: "wait")
        let custom: AnyDeferredPublisher = DeferredCustom<Int, TestError> { handler in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                handler.sendValue(1)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                    handler.sendValue(2)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                        handler.sendCompletion(.finished)
                    }
                }
            }
        }.eraseToAnyDeferredPublisher()

        var values: [Int] = []
        custom
            .handleValue { values.append($0) }
            .handleFinished { expectation.fulfill() }
            .handleError { XCTFail("unexpected error: \($0)") }
            .sink(duringLifetimeOf: self)

        wait(for: [expectation], timeout: 3)
        XCTAssertEqual(values, [1, 2])
    }

    func testCustom_BasicValues_ActuallyDeferred() {
        var deferredTest = 0
        let custom = DeferredCustom<Int, TestError> { handler in
            deferredTest += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                handler.sendValue(1)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                    handler.sendValue(2)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                        handler.sendCompletion(.finished)
                    }
                }
            }
        }

        autoreleasepool {
            let expectation = XCTestExpectation(description: "wait")
            XCTAssertEqual(deferredTest, 0)
            var values: [Int] = []
            custom
                .handleValue { values.append($0) }
                .handleFinished { expectation.fulfill() }
                .handleError { XCTFail("unexpected error: \($0)") }
                .sink(duringLifetimeOf: self)

            XCTAssertEqual(deferredTest, 1)
            wait(for: [expectation], timeout: 3)
            XCTAssertEqual(values, [1, 2])
        }

        autoreleasepool {
            let expectation = XCTestExpectation(description: "wait")
            XCTAssertEqual(deferredTest, 1)
            var values: [Int] = []
            custom
                .handleValue { values.append($0) }
                .handleFinished { expectation.fulfill() }
                .handleError { XCTFail("unexpected error: \($0)") }
                .sink(duringLifetimeOf: self)

            XCTAssertEqual(deferredTest, 2)
            wait(for: [expectation], timeout: 3)
            XCTAssertEqual(values, [1, 2])
        }
    }

    func testCustom_Failure() {
        let expectation = XCTestExpectation(description: "wait")
        let custom = DeferredCustom<Int, TestError> { handler in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                handler.sendValue(1)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                    handler.sendValue(2)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                        handler.sendCompletion(.failure(TestError.error1))
                    }
                }
            }
        }

        var values: [Int] = []
        custom
            .handleValue { values.append($0) }
            .handleFinished {
                XCTFail("Should not finish")
            }
            .handleError {
                XCTAssertTrue($0 == TestError.error1)
                expectation.fulfill()
            }
            .sink(duringLifetimeOf: self)

        wait(for: [expectation], timeout: 3)
        XCTAssertEqual(values, [1, 2])
    }

    func testCustom_NoValuesAfterCompletion() {
        let expectation = XCTestExpectation(description: "wait")
        let custom = DeferredCustom<Int, TestError> { handler in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                handler.sendValue(1)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                    handler.sendCompletion(.finished)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                        handler.sendValue(2)
                        expectation.fulfill()
                    }
                }
            }
        }

        var values: [Int] = []
        var didFinish = false
        custom
            .handleValue { values.append($0) }
            .handleFinished { didFinish = true }
            .handleError { XCTFail("unexpected error: \($0)") }
            .sink(duringLifetimeOf: self)

        wait(for: [expectation], timeout: 3)
        XCTAssertEqual(values, [1])
        XCTAssertEqual(didFinish, true)
    }

    func testCustom_CancelledEmitsProperly() {
        let expectation = XCTestExpectation(description: "wait")
        let custom = DeferredCustom<Int, TestError> { handler in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                handler.sendValue(1)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                    handler.sendValue(2)
                }
            }

            handler.cancelled
                .handleValue { if $0 { expectation.fulfill() } }
                .sink(duringLifetimeOf: self)
        }

        let cancellable = custom.sink(duringLifetimeOf: self)
        cancellable.cancel()

        wait(for: [expectation], timeout: 3)
    }

    func testCustom_DemandEmitsProperly() {
        let expectation = XCTestExpectation(description: "wait")
        let custom = DeferredCustom<Int, TestError> { handler in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                handler.sendValue(1)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                    handler.sendValue(2)
                }
            }

            handler.demand
                .handleValue { if $0 == .max(1) { expectation.fulfill() } }
                .sink(duringLifetimeOf: self)
        }

        custom
            .flatMap(maxPublishers: .max(1)) {
                Just($0)
            }
            .sink(duringLifetimeOf: self)

        wait(for: [expectation], timeout: 3)
    }
}
