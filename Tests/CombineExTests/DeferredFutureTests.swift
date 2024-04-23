//
//  DeferredFutureTests.swift
//  Copyright © 2023 Jason Fieldman.
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

    /// Ensure that `mapDeferredFuture` can be chained into `eraseToAnyPublisher` to
    /// explicitly return an `AnyDeferredFuture`.
    let t3: AnyDeferredFuture = future.mapDeferredFuture { $0 + 1 }.eraseToAnyPublisher()
    let p3 = t3.eraseToAnyPublisher()
    XCTAssertNotNil(p3)

    /// Ensure that using `eraseToAnyDeferredFuture` works after the ambiguous
    /// `map` call.
    let t4 = future.map { $0 + 1 }.eraseToAnyDeferredFuture()
    let p4 = t4.eraseToAnyPublisher()
    XCTAssertNotNil(p4)
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
