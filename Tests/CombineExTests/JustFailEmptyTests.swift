//
//  JustFailEmptyTests.swift
//  Copyright © 2025 Jason Fieldman.
//

@testable import CombineEx
import XCTest

/// A generic error enum we can use for these test cases
private enum TestError: Error {
    case error1
    case error2
}

final class JustFailEmptyTests: XCTestCase {
    func testJustEmitsValueAndFinishes() {
        let expectation = XCTestExpectation(description: "Publisher should emit value and finish")

        var emittedValue: String?
        var finished = false

        // Test with a string value
        AnyPublisher<String, TestError>.just("Hello")
            .sink(
                receiveCompletion: { completion in
                    if case .finished = completion {
                        finished = true
                        expectation.fulfill()
                    }
                },
                receiveValue: { value in
                    emittedValue = value
                }
            )
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 1.0)

        XCTAssertEqual(emittedValue, "Hello")
        XCTAssertTrue(finished)
    }

    func testJustWithIntValue() {
        let expectation = XCTestExpectation(description: "Publisher should emit int value and finish")

        var emittedValue: Int?
        var finished = false

        // Test with an int value
        AnyPublisher<Int, TestError>.just(42)
            .sink(
                receiveCompletion: { completion in
                    if case .finished = completion {
                        finished = true
                        expectation.fulfill()
                    }
                },
                receiveValue: { value in
                    emittedValue = value
                }
            )
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 1.0)

        XCTAssertEqual(emittedValue, 42)
        XCTAssertTrue(finished)
    }

    func testFailEmitsError() {
        let expectation = XCTestExpectation(description: "Publisher should emit error and finish")

        var receivedError: TestError?

        // Test with a specific error
        AnyPublisher<String, TestError>.fail(.error1)
            .sink(
                receiveCompletion: { completion in
                    if case let .failure(error) = completion {
                        receivedError = error
                        expectation.fulfill()
                    }
                },
                receiveValue: { _ in
                    XCTFail("Should not receive a value")
                }
            )
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 1.0)

        XCTAssertEqual(receivedError, TestError.error1)
    }

    func testFailWithDifferentError() {
        let expectation = XCTestExpectation(description: "Publisher should emit different error and finish")

        var receivedError: TestError?

        // Test with a different error
        AnyPublisher<String, TestError>.fail(.error2)
            .sink(
                receiveCompletion: { completion in
                    if case let .failure(error) = completion {
                        receivedError = error
                        expectation.fulfill()
                    }
                },
                receiveValue: { _ in
                    XCTFail("Should not receive a value")
                }
            )
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 1.0)

        XCTAssertEqual(receivedError, TestError.error2)
    }

    func testEmptyFinishesWithoutEmitting() {
        let expectation = XCTestExpectation(description: "Publisher should finish without emitting any values")

        var finished = false
        var receivedValue: String?

        // Test empty publisher
        AnyPublisher<String, TestError>.empty()
            .sink(
                receiveCompletion: { completion in
                    if case .finished = completion {
                        finished = true
                        expectation.fulfill()
                    }
                },
                receiveValue: { value in
                    receivedValue = value
                }
            )
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 1.0)

        XCTAssertNil(receivedValue)
        XCTAssertTrue(finished)
    }

    func testJustTypeErasure() {
        // Test that just returns AnyPublisher
        let publisher = AnyPublisher<String, TestError>.just("test")
        XCTAssertTrue(type(of: publisher) == AnyPublisher<String, TestError>.self)
    }

    func testFailTypeErasure() {
        // Test that fail returns AnyPublisher
        let publisher = AnyPublisher<String, TestError>.fail(.error1)
        XCTAssertTrue(type(of: publisher) == AnyPublisher<String, TestError>.self)
    }

    func testEmptyTypeErasure() {
        // Test that empty returns AnyPublisher
        let publisher = AnyPublisher<String, TestError>.empty()
        XCTAssertTrue(type(of: publisher) == AnyPublisher<String, TestError>.self)
    }

    private var cancellables = Set<AnyCancellable>()
}
