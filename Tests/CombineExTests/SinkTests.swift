//
//  SinkTests.swift
//  Copyright © 2025 Jason Fieldman.
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
    func testSinkDuringLifetimeReleases() {
        let subject = CurrentValueSubject<Int, TestError>(1)
        var accumulator: [Int] = []
        var cancel = false

        autoreleasepool {
            let lifetime = LifetimeClass()
            subject
                .handleValue { accumulator.append($0) }
                .sink(
                    duringLifetimeOf: lifetime,
                    receiveCancel: { cancel = true }
                )

            subject.send(2)
            Thread.sleep(forTimeInterval: 0.01)
            subject.send(3)
            Thread.sleep(forTimeInterval: 0.01)
            subject.send(4)
            Thread.sleep(forTimeInterval: 0.01)
        }

        Thread.sleep(forTimeInterval: 0.01)
        subject.send(5)
        XCTAssertEqual(accumulator, [1, 2, 3, 4])
        XCTAssertEqual(cancel, true)
    }

    func testSinkDuringLifetimeOperatesOnSet() {
        let subject = CurrentValueSubject<Int, TestError>(1)
        var accumulator: [Int] = []
        let lifetime = LifetimeClass()

        XCTAssertEqual(__AnyObjectCancellableStorage(lifetime).count, 0)

        let cancellable = subject
            .handleValue { accumulator.append($0) }
            .sink(duringLifetimeOf: lifetime)

        XCTAssertEqual(__AnyObjectCancellableStorage(lifetime).count, 1)

        subject.send(2)
        subject.send(3)
        subject.send(4)

        XCTAssertEqual(__AnyObjectCancellableStorage(lifetime).count, 1)
        cancellable?.cancel()
        XCTAssertEqual(__AnyObjectCancellableStorage(lifetime).count, 0)

        subject.send(5)
        XCTAssertEqual(accumulator, [1, 2, 3, 4])
    }

    func testSinkDuringLifetimeBlocksWithCancel() {
        let subject = CurrentValueSubject<Int, TestError>(1)
        var accumulator: [Int] = []
        let lifetime = LifetimeClass()

        var sub = false
        var req = false
        var comp = false
        var cancel = false

        XCTAssertEqual(__AnyObjectCancellableStorage(lifetime).count, 0)

        let cancellable = subject
            .sink(
                duringLifetimeOf: lifetime,
                receiveSubscription: { _ in sub = true },
                receiveValue: { accumulator.append($0) },
                receiveCompletion: { _ in comp = true },
                receiveCancel: { cancel = true },
                receiveRequest: { _ in req = true }
            )

        XCTAssertEqual(__AnyObjectCancellableStorage(lifetime).count, 1)

        subject.send(2)
        subject.send(3)
        subject.send(4)

        XCTAssertEqual(__AnyObjectCancellableStorage(lifetime).count, 1)
        cancellable?.cancel()
        XCTAssertEqual(__AnyObjectCancellableStorage(lifetime).count, 0)

        subject.send(5)
        XCTAssertEqual(accumulator, [1, 2, 3, 4])
        XCTAssertEqual(sub, true)
        XCTAssertEqual(req, true)
        XCTAssertEqual(comp, false)
        XCTAssertEqual(cancel, true)
    }

    func testSinkDuringLifetimeBlocksWithFinish() {
        let subject = CurrentValueSubject<Int, TestError>(1)
        var accumulator: [Int] = []
        let lifetime = LifetimeClass()

        var sub = false
        var req = false
        var comp = false
        var cancel = false

        XCTAssertEqual(__AnyObjectCancellableStorage(lifetime).count, 0)

        subject
            .sink(
                duringLifetimeOf: lifetime,
                receiveSubscription: { _ in sub = true },
                receiveValue: { accumulator.append($0) },
                receiveCompletion: { _ in comp = true },
                receiveCancel: { cancel = true },
                receiveRequest: { _ in req = true }
            )

        XCTAssertEqual(__AnyObjectCancellableStorage(lifetime).count, 1)

        subject.send(2)
        subject.send(3)
        subject.send(4)

        XCTAssertEqual(__AnyObjectCancellableStorage(lifetime).count, 1)
        subject.send(completion: .finished)
        XCTAssertEqual(__AnyObjectCancellableStorage(lifetime).count, 0)

        subject.send(5)
        XCTAssertEqual(accumulator, [1, 2, 3, 4])
        XCTAssertEqual(sub, true)
        XCTAssertEqual(req, true)
        XCTAssertEqual(comp, true)
        XCTAssertEqual(cancel, false)
    }
}
