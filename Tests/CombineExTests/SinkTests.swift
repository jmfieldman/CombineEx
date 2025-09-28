//
//  SinkTests.swift
//  Copyright © 2024 Jason Fieldman.
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
        let accumulator = TestAccumulator<Int>()
        let cancel = TestBox(false)

        autoreleasepool {
            let lifetime = LifetimeClass()
            subject
                .handleValue { accumulator.append($0) }
                .sink(
                    duringLifetimeOf: lifetime,
                    receiveCancel: { cancel.value = true }
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
        XCTAssertEqual(accumulator.values, [1, 2, 3, 4])
        XCTAssertEqual(cancel.value, true)
    }

    func testSinkDuringLifetimeOperatesOnSet() {
        let subject = CurrentValueSubject<Int, TestError>(1)
        let accumulator = TestAccumulator<Int>()
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
        cancellable.cancel()
        XCTAssertEqual(__AnyObjectCancellableStorage(lifetime).count, 0)

        subject.send(5)
        XCTAssertEqual(accumulator.values, [1, 2, 3, 4])
    }

    func testSinkDuringLifetimeBlocksWithCancel() {
        let subject = CurrentValueSubject<Int, TestError>(1)
        let accumulator = TestAccumulator<Int>()
        let lifetime = LifetimeClass()

        let sub = TestBox(false)
        let req = TestBox(false)
        let comp = TestBox(false)
        let cancel = TestBox(false)

        XCTAssertEqual(__AnyObjectCancellableStorage(lifetime).count, 0)

        let cancellable = subject
            .sink(
                duringLifetimeOf: lifetime,
                receiveSubscription: { _ in sub.value = true },
                receiveValue: { accumulator.append($0) },
                receiveCompletion: { _ in comp.value = true },
                receiveCancel: { cancel.value = true },
                receiveRequest: { _ in req.value = true }
            )

        XCTAssertEqual(__AnyObjectCancellableStorage(lifetime).count, 1)

        subject.send(2)
        subject.send(3)
        subject.send(4)

        XCTAssertEqual(__AnyObjectCancellableStorage(lifetime).count, 1)
        cancellable.cancel()
        XCTAssertEqual(__AnyObjectCancellableStorage(lifetime).count, 0)

        subject.send(5)
        XCTAssertEqual(accumulator.values, [1, 2, 3, 4])
        XCTAssertEqual(sub.value, true)
        XCTAssertEqual(req.value, true)
        XCTAssertEqual(comp.value, false)
        XCTAssertEqual(cancel.value, true)
    }

    func testSinkDuringLifetimeBlocksWithFinish() {
        let subject = CurrentValueSubject<Int, TestError>(1)
        let accumulator = TestAccumulator<Int>()
        let lifetime = LifetimeClass()

        let sub = TestBox(false)
        let req = TestBox(false)
        let comp = TestBox(false)
        let cancel = TestBox(false)

        XCTAssertEqual(__AnyObjectCancellableStorage(lifetime).count, 0)

        subject
            .sink(
                duringLifetimeOf: lifetime,
                receiveSubscription: { _ in sub.value = true },
                receiveValue: { accumulator.append($0) },
                receiveCompletion: { _ in comp.value = true },
                receiveCancel: { cancel.value = true },
                receiveRequest: { _ in req.value = true }
            )

        XCTAssertEqual(__AnyObjectCancellableStorage(lifetime).count, 1)

        subject.send(2)
        subject.send(3)
        subject.send(4)

        XCTAssertEqual(__AnyObjectCancellableStorage(lifetime).count, 1)
        subject.send(completion: .finished)
        XCTAssertEqual(__AnyObjectCancellableStorage(lifetime).count, 0)

        subject.send(5)
        XCTAssertEqual(accumulator.values, [1, 2, 3, 4])
        XCTAssertEqual(sub.value, true)
        XCTAssertEqual(req.value, true)
        XCTAssertEqual(comp.value, true)
        XCTAssertEqual(cancel.value, false)
    }
}
