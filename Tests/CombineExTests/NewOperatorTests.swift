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
}