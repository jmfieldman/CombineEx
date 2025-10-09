//
//  AggregationTests.swift
//  Copyright © 2025 Jason Fieldman.
//

@testable import CombineEx
import XCTest

/// A generic error enum we can use for these test cases
private enum TestError: Error {
    case error1
}

final class AggregationTests: XCTestCase {
    func testCombineAnyPublisher() {
        let pub1 = TriggerablePublisher()
        let pub2 = TriggerablePublisher()
        let pub3 = TriggerablePublisher()
        let pub4 = TriggerablePublisher()
        let pub5 = TriggerablePublisher()

        let combined = AnyPublisher<Int, TestError>.combineLatest(
            pub1.publisher,
            pub2.publisher,
            pub3.publisher,
            pub4.publisher,
            pub5.publisher
        ).map { p1, p2, p3, p4, p5 in
            p1 + p2 + p3 + p4 + p5
        }

        let accumulator = TestAccumulator<Int>()
        let errors = TestAccumulator<Int>()

        combined
            .handleValue { accumulator.append($0) }
            .handleError { _ in errors.append(1) }
            .sink(duringLifetimeOf: self)

        XCTAssertEqual(accumulator.values, [])

        pub1.handler?.sendValue(1)
        pub2.handler?.sendValue(2)

        XCTAssertEqual(accumulator.values, [])

        pub3.handler?.sendValue(3)
        pub4.handler?.sendValue(4)

        XCTAssertEqual(accumulator.values, [])

        pub3.handler?.sendValue(3)
        pub4.handler?.sendValue(4)

        XCTAssertEqual(accumulator.values, [])

        pub5.handler?.sendValue(5)

        XCTAssertEqual(accumulator.values, [15])

        pub3.handler?.sendValue(3)
        pub4.handler?.sendValue(4)

        XCTAssertEqual(accumulator.values, [15, 15, 15])

        pub3.handler?.sendValue(13)
        pub4.handler?.sendValue(14)

        XCTAssertEqual(accumulator.values, [15, 15, 15, 25, 35])
        XCTAssertEqual(errors.values, [])

        pub3.handler?.sendCompletion(.failure(.error1))
        pub3.handler?.sendCompletion(.failure(.error1))
        pub4.handler?.sendValue(0)

        XCTAssertEqual(accumulator.values, [15, 15, 15, 25, 35])
        XCTAssertEqual(errors.values, [1])
    }
}

private class TriggerablePublisher {
    lazy var publisher: AnyDeferredPublisher<Int, TestError> = Deferred { [weak self] in
        Publishers.Custom { [weak self] handler in
            self?.handler = handler
        }
    }.eraseToAnyDeferredPublisher()

    var handler: (any Publishers.CustomSubscriptionHandler<Int, TestError>)?
}
