//
//  DeferredPublisherTests.swift
//  Copyright © 2023 Jason Fieldman.
//

@testable import CombineEx
import XCTest

/// A generic error enum we can use for these test cases
private enum TestError: Error {
  case error1
}

final class DeferredPublisherTests: XCTestCase {
  func testBasicDeferredPublisher() {
    basicSingleFutureTest(input: 1, output: 1) { $0 }
  }

  func testEraseReturnsSelf() {
    let anyDeferredPublisher: AnyDeferredPublisher<Int, Never> =
      Deferred { Just(1) }.eraseToAnyPublisher()

    XCTAssert(anyDeferredPublisher === anyDeferredPublisher.eraseToAnyPublisher())
  }

  // MARK: Map

  func testMapSingle() {
    basicSingleFutureTest(input: 1, output: 2) { $0.map { $0 + 1 }.eraseToAnyPublisher() }
    basicSingleFutureTest(input: "Hello", output: "HelloHello") { $0.map { $0 + $0 }.eraseToAnyPublisher() }
  }
}

// MARK: Test Helpers

private extension DeferredPublisherTests {
  func basicSingleFutureTest<Output: Equatable>(
    input: Output,
    output: Output,
    _ transform: @escaping (AnyDeferredPublisher<Output, TestError>) -> AnyDeferredPublisher<Output, TestError>
  ) {
    var countableInnerFire = 0
    var sinkResult: Output?
    let countableFuture = CountableFuture<Output, TestError> {
      countableInnerFire += 1
      $0(.success(input))
    }

    let anyDeferredPublisher: AnyDeferredPublisher<Output, TestError> =
      transform(Deferred { countableFuture }.eraseToAnyPublisher())

    XCTAssertEqual(countableInnerFire, 0)
    XCTAssertEqual(countableFuture.receiveCount, 0)

    _ = anyDeferredPublisher.assertSink { sinkResult = $0 }

    XCTAssertEqual(countableInnerFire, 1)
    XCTAssertEqual(sinkResult, output)
    XCTAssertEqual(countableFuture.receiveCount, 1)
  }
}
