//
//  SinkTests.swift
//  Copyright © 2023 Jason Fieldman.
//

@testable import CombineEx
import XCTest

/// A generic error enum we can use for these test cases
private enum TestError: Error {
  case error1
}

private class LifetimeClass {
  deinit {
    print("dealloc")
  }
}

final class SinkTests: XCTestCase {
  func testFoo() {
    let subject = CurrentValueSubject<Int, TestError>(1)
    var accumulator: [Int] = []

    autoreleasepool {
      let lifetime = LifetimeClass()
      subject
        .handleValue { accumulator.append($0) }
        .sink(duringLifetimeOf: lifetime)

      subject.send(2)
      Thread.sleep(forTimeInterval: 0.01)
      subject.send(3)
      Thread.sleep(forTimeInterval: 0.01)
      subject.send(4)
      Thread.sleep(forTimeInterval: 0.01)
    }

    Thread.sleep(forTimeInterval: 0.11)
    subject.send(5)
    XCTAssertEqual(accumulator, [1, 2, 3, 4])
  }
}
