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
  // MARK: - Basic

  func testBasic() {
    let future = TestableDeferredFuture(emission: 1, delay: 0.1)
    XCTAssert(!future.attempted)
    XCTAssertEqual(future.sinkAndWait(in: self), 1)
    XCTAssert(future.attempted)
  }

  // MARK: - Map

  private func _testMapUtility(_ futureBlock: (TestableDeferredFuture, @escaping (Int) -> Int) -> AnyPublisher<Int, TestError>) {
    let future = TestableDeferredFuture(emission: 1, delay: 0.1)
    XCTAssert(!future.attempted)

    let sut = futureBlock(future) { $0 + 4 }
    XCTAssert(!future.attempted)
    XCTAssertEqual(sut.sinkAndWait(in: self), 5)
    XCTAssert(future.attempted)
  }

  /// Ensures that `map` can be used without compiler ambiguity warnings.
  /// The `untypedMapped` variable will be a normal Publisher.
  func testUntypedMap() {
    _testMapUtility { future, transform in
      let sut = future.map(transform)
      return sut.eraseToAnyPublisher()
    }
  }

  /// Ensure that `map` can be used to explicitly return a `DeferredFuture`
  func testTypedMap() {
    _testMapUtility { future, transform in
      let sut: DeferredFuture<Int, TestError> = future.map(transform)
      return sut.eraseToAnyPublisher()
    }
  }

  /// Ensure that `mapDeferred` can be chained into `eraseToAnyPublisher` to
  /// explicitly return an `AnyDeferredFuture`.
  func testMapDeferred() {
    _testMapUtility { future, transform in
      let sut: AnyDeferredFuture = future.mapDeferred(transform).eraseToAnyPublisher()
      return sut.eraseToAnyPublisher()
    }
  }

  /// Ensure that using `eraseToAnyDeferredFuture` works after the ambiguous
  /// `map` call.
  func testMapErasedToDeferredFuture() {
    _testMapUtility { future, transform in
      let sut = future.map(transform).eraseToAnyDeferredFuture()
      return sut.eraseToAnyPublisher()
    }
  }
}

// MARK: - Utils

private class TestableDeferredFuture: AnyDeferredFuture<Int, TestError> {
  var attempted: Bool = false
  var cancellable: AnyCancellable?

  init(emission: Int, delay: TimeInterval) {
    var markAttempted: (() -> Void)? = nil
    super.init(DeferredFuture { promise in
      markAttempted?()
      DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
        promise(.success(emission))
      }
    })

    markAttempted = { [weak self] in self?.attempted = true }
  }
}

private extension Publisher where Output == Int {
  func sinkAndWait(in testCase: XCTestCase) -> Int {
    let expectation = XCTestExpectation(description: "sink expected")
    var result: Int = -1
    let cancellable = sink { _ in
    } receiveValue: {
      expectation.fulfill()
      result = $0
    }

    testCase.wait(for: [expectation], timeout: 3.0)
    cancellable.cancel()
    return result
  }
}
