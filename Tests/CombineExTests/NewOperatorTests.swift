//
//  NewOperatorTests.swift
//  Copyright © 2023 Jason Fieldman.
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
}
