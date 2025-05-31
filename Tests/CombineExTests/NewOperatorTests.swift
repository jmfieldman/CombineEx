//
//  NewOperatorTests.swift
//  Copyright © 2024 Jason Fieldman.
//

@testable import CombineEx
import XCTest

/// A generic error enum we can use for these test cases
private enum TestError: Error {
    case error1
}

final class NewOperatorTests: XCTestCase {
    func testPromoteFailure() {
        let justOne = Just(1)
        let withPromotedError: AnyPublisher<Int, TestError> = justOne
            .map { $0 + 1 }
            .promoteFailure()
            .map { $0 + 1 }
            .eraseToAnyPublisher()

        var testRan = false
        let _ = withPromotedError.sink { _ in
        } receiveValue: {
            testRan = true
            XCTAssertEqual($0, 3)
        }

        XCTAssertEqual(testRan, true)
    }

    func testDemoteFailure() {
        let failure = Fail(outputType: Int.self, failure: TestError.error1)

        var failed = false
        let _ = failure.sink { result in
            switch result {
            case .finished:
                XCTFail("Should not finish")
            case .failure:
                failed = true
            }
        } receiveValue: { _ in
            XCTFail("Should not emit output")
        }
        XCTAssert(failed)

        var finished = false
        let demoted: AnyPublisher<Int, Never> = failure.demoteFailure().eraseToAnyPublisher()
        let _ = demoted.sink { result in
            switch result {
            case .finished:
                finished = true
            case .failure:
                XCTFail("Should not fail")
            }
        } receiveValue: { _ in
            XCTFail("Should not emit output")
        }
        XCTAssert(finished)
    }

    func testIgnoreFailure() {
        let failure = Fail(outputType: Int.self, failure: TestError.error1)

        var failed = false
        let _ = failure.sink { result in
            switch result {
            case .finished:
                XCTFail("Should not finish")
            case .failure:
                failed = true
            }
        } receiveValue: { _ in
            XCTFail("Should not emit output")
        }
        XCTAssert(failed)

        var finished = false
        let ignored: AnyPublisher<Int, TestError> = failure.ignoreFailure().eraseToAnyPublisher()
        let _ = ignored.sink { result in
            switch result {
            case .finished:
                finished = true
            case .failure:
                XCTFail("Should not fail")
            }
        } receiveValue: { _ in
            XCTFail("Should not emit output")
        }
        XCTAssert(finished)
    }

    func testAttemptMap() {
        // Success
        let justOne = Just(1).setFailureType(to: TestError.self)
        let attemptSuccess = justOne.attemptMap { .success("\($0)") }
        var receivedValue: String? = nil
        var finished = false
        let _ = attemptSuccess.sink { result in
            switch result {
            case .finished:
                finished = true
            case .failure:
                XCTFail("Should not fail")
            }
        } receiveValue: {
            receivedValue = $0
        }
        XCTAssert(finished)
        XCTAssertEqual(receivedValue, "1")

        // Failure
        let attemptFail: AnyPublisher<String, TestError> = justOne.attemptMap { _ in .failure(.error1) }.eraseToAnyPublisher()
        receivedValue = nil
        var failed = false
        let _ = attemptFail.sink { result in
            switch result {
            case .finished:
                XCTFail("Should not finish")
            case let .failure(error):
                failed = true
                XCTAssertEqual(error, .error1)
            }
        } receiveValue: {
            receivedValue = $0
        }
        XCTAssert(failed)

        // Cancels
        let future = Future<Int, TestError> { promise in
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
                promise(.success(1))
            }
        }
        let mapped = future
            .attemptMap { .success($0 + 1) }

        finished = false
        var receivedInt = false
        let cancellable = mapped.sink { completion in
            switch completion {
            case .finished:
                finished = true
            case .failure:
                XCTFail("Should not fail")
            }
        } receiveValue: { _ in
            receivedInt = true
        }
        cancellable.cancel()
        Thread.sleep(forTimeInterval: 0.5)

        XCTAssertTrue(!finished)
        XCTAssertFalse(receivedInt)
    }

    func testPrependDynamic() {
        let p1 = Just(1).setFailureType(to: Never.self)
        let s = 10
        let p2 = p1.prependDynamic { s * 10 }
        var result: [Int] = []
        _ = p2.sink { result.append($0) }
        XCTAssertEqual(result, [100, 1])
    }

    func testPropertyCombineLatestSimple() {
        let p1 = Property<[String]>(value: ["a", "b"])
        let p2 = Property<Bool>(value: true)
        let p3 = Property<Set<String>>(value: ["a"])

        let combined = Property<Set<String>>
            .combineLatest(p1, p2, p3)
            .map { strings, allowed, match -> Set<String> in
                if allowed {
                    return Set(strings).intersection(match)
                } else {
                    return Set()
                }
            }

        XCTAssertEqual(Array(combined.value), ["a"])
    }

    func testPropertyCombineLatestMutate() {
        let mutator = MutableProperty<Bool>(true)

        let p1 = Property<[String]>(value: ["a", "b"])
        let p2 = Property<Bool>(mutator)
        let p3 = Property<Set<String>>(value: ["a"])

        let mapped = Property<Set<String>>
            .combineLatest(p1, p2, p3)
            .map { strings, allowed, match -> Set<String> in
                if allowed {
                    return Set(strings).intersection(match)
                } else {
                    return Set()
                }
            }

        XCTAssertEqual(Array(mapped.value), ["a"])

        mutator.value = false
        XCTAssertEqual(Array(mapped.value), [])
    }

    func testCombineLatestSelfPlus9() {
        let p1 = CurrentValueSubject<Int, TestError>(1)
        let p2 = CurrentValueSubject<Int, TestError>(2)
        let p3 = CurrentValueSubject<Int, TestError>(3)
        let p4 = CurrentValueSubject<Int, TestError>(4)
        let p5 = CurrentValueSubject<Int, TestError>(5)
        let p6 = CurrentValueSubject<Int, TestError>(6)
        let p7 = CurrentValueSubject<Int, TestError>(7)
        let p8 = CurrentValueSubject<Int, TestError>(8)
        let p9 = CurrentValueSubject<Int, TestError>(9)
        let p10 = CurrentValueSubject<Int, TestError>(10)

        var emissions: [(Int, Int, Int, Int, Int, Int, Int, Int, Int, Int)] = []
        var finished = false
        var cancellables: [AnyCancellable] = []
        let combined = p1.combineLatest(p2, p3, p4, p5, p6, p7, p8, p9, p10)
        combined.sink {
            switch $0 {
            case .finished:
                finished = true
            case .failure:
                XCTFail("Should not fail")
            }
        } receiveValue: {
            emissions.append($0)
        }.store(in: &cancellables)

        XCTAssertFalse(finished)
        XCTAssertEqual(emissions.count, 1)
        XCTAssertEqual(emissions[0].0, 1)
        XCTAssertEqual(emissions[0].1, 2)
        XCTAssertEqual(emissions[0].2, 3)
        XCTAssertEqual(emissions[0].3, 4)
        XCTAssertEqual(emissions[0].4, 5)
        XCTAssertEqual(emissions[0].5, 6)
        XCTAssertEqual(emissions[0].6, 7)
        XCTAssertEqual(emissions[0].7, 8)
        XCTAssertEqual(emissions[0].8, 9)
        XCTAssertEqual(emissions[0].9, 10)

        p5.send(100)
        XCTAssertEqual(emissions.count, 2)
        XCTAssertEqual(emissions[1].0, 1)
        XCTAssertEqual(emissions[1].1, 2)
        XCTAssertEqual(emissions[1].2, 3)
        XCTAssertEqual(emissions[1].3, 4)
        XCTAssertEqual(emissions[1].4, 100)
        XCTAssertEqual(emissions[1].5, 6)
        XCTAssertEqual(emissions[1].6, 7)
        XCTAssertEqual(emissions[1].7, 8)
        XCTAssertEqual(emissions[1].8, 9)
        XCTAssertEqual(emissions[1].9, 10)
    }
}
