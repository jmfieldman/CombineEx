//
//  AttemptMapTests.swift
//  Copyright © 2025 Jason Fieldman.
//

@testable import CombineEx
import XCTest

/// A generic error enum we can use for these test cases
private enum TestError: Error {
    case error1
}

final class AttemptMapTests: XCTestCase {
    func testAttemptMap_TransformsOutputSuccessfully() {
        let publisher = PassthroughSubject<Int, TestError>()
        let results = TestAccumulator<String?>()

        publisher
            .attemptMap { value -> Result<String, TestError> in
                .success("\(value)")
            }
            .handleValue {
                results.append($0)
            }
            .handleCompletion {
                if case .finished = $0 {
                    results.append(nil)
                }
            }
            .sink(duringLifetimeOf: self)

        publisher.send(1)
        publisher.send(2)
        publisher.send(completion: .finished)

        XCTAssertEqual(results.values, ["1", "2", nil])
    }

    func testAttemptMap_TransformsOutputWithError() {
        let publisher = PassthroughSubject<Int, TestError>()
        let results = TestAccumulator<String?>()

        publisher
            .attemptMap { value -> Result<String, TestError> in
                if value == 2 { return .failure(TestError.error1) }
                return .success("\(value)")
            }
            .handleValue {
                results.append($0)
            }
            .handleCompletion {
                if case .failure = $0 {
                    results.append("fail")
                }
            }
            .sink(duringLifetimeOf: self)

        publisher.send(1)
        publisher.send(2)
        publisher.send(completion: .finished)

        XCTAssertEqual(results.values, ["1", "fail"])
    }
}
