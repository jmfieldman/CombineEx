//
//  PropertyTests.swift
//  Copyright © 2025 Jason Fieldman.
//

@testable import CombineEx
import XCTest

/// A generic error enum we can use for these test cases
private enum TestError: Error {
    case error1
}

private struct TestValue: Identifiable, Equatable {
    let id: String
    let value: Int
}

private struct OutputModel {
    let id: String
    let valueProperty: Property<Int>
}

final class PropertyTests: XCTestCase {
    var cancellable: AnyCancellable?

    func testProperty() {
        let mutableProperty = MutableProperty<Bool>(false)
        let property = Property(mutableProperty)

        class Box {
            var values: [Bool] = []
            func append(_ bool: Bool) {
                values.append(bool)
            }
        }
        let box = Box()

        property
            .handleValue { box.append($0) }
            .sink(duringLifetimeOf: self)

        mutableProperty.value = true
        mutableProperty.value = false
        mutableProperty.value = true

        XCTAssert(box.values == [false, true, false, true])
    }

    func testPropertyMap() {
        let mutableProperty = MutableProperty<Bool>(false)
        let property = Property(mutableProperty)

        class Box {
            var values: [String] = []
            func append(_ str: String) {
                values.append(str)
            }
        }
        let box = Box()

        property
            .map { "\($0)" }
            .handleValue { box.append($0) }
            .sink(duringLifetimeOf: self)

        mutableProperty.value = true
        mutableProperty.value = false
        mutableProperty.value = true

        XCTAssert(box.values == ["false", "true", "false", "true"])
    }

    func testPropertyFilterStartFalse() {
        let mutableProperty = MutableProperty<Bool>(false)
        let property = Property(mutableProperty)

        class Box {
            var values: [Bool] = []
            func append(_ bool: Bool) {
                values.append(bool)
            }
        }
        let box = Box()

        property
            .filter(\.self)
            .handleValue { box.append($0) }
            .sink(duringLifetimeOf: self)

        mutableProperty.value = true
        mutableProperty.value = false
        mutableProperty.value = true

        XCTAssert(box.values == [true, true])
    }

    func testPropertyFilterStartTrue() {
        let mutableProperty = MutableProperty<Bool>(true)
        let property = Property(mutableProperty)

        class Box {
            var values: [Bool] = []
            func append(_ bool: Bool) {
                values.append(bool)
            }
        }
        let box = Box()

        property
            .filter(\.self)
            .handleValue { box.append($0) }
            .sink(duringLifetimeOf: self)

        mutableProperty.value = false
        mutableProperty.value = true

        XCTAssert(box.values == [true, true])
    }

    func testPropertyRemoveDuplicates() {
        let mutableProperty = MutableProperty<Bool>(false)
        let property = Property(mutableProperty)

        class Box {
            var values: [Bool] = []
            func append(_ bool: Bool) {
                values.append(bool)
            }
        }
        let box = Box()

        property
            .removeDuplicates()
            .handleValue { box.append($0) }
            .sink(duringLifetimeOf: self)

        mutableProperty.value = true
        mutableProperty.value = true
        mutableProperty.value = true
        mutableProperty.value = false
        mutableProperty.value = false
        mutableProperty.value = false
        mutableProperty.value = true

        XCTAssert(box.values == [false, true, false, true])
    }

    func testPropertyThenOnlyExecutesOnce() {
        let testCount = TestBox<Int>(0)
        let work = AnyDeferredFuture<Bool, Never> { promise in
            testCount.value += 1
            promise(.success(true))
        }

        let property = Property(initial: false, then: work)
        let accumulator = TestAccumulator<Bool>()

        property
            .handleValue { accumulator.append($0) }
            .sink(duringLifetimeOf: self)

        property
            .handleValue { accumulator.append($0) }
            .sink(duringLifetimeOf: self)

        XCTAssertEqual(accumulator.values, [true, true])
        XCTAssertEqual(testCount.value, 1)
    }

    func testPropertyComplexPostAssignmentStream() {
        var capturedHandler: (any Publishers.CustomSubscriptionHandler<Int, Never>)? = nil
        let custom = Publishers.Custom<Int, Never> { handler in
            capturedHandler = handler
        }.eraseToAnyPublisher()

        let property = Property<Int>(initial: 0, then: custom)
        let accumulator1 = TestAccumulator<Int>()
        let accumulator2 = TestAccumulator<Int>()

        property
            .map { $0 * 2 }
            .handleValue { accumulator1.append($0) }
            .sink(duringLifetimeOf: self)

        property
            .handleValue { accumulator2.append($0) }
            .map { $0 * 2 }
            .sink(duringLifetimeOf: self)

        capturedHandler?.sendValue(1)
        capturedHandler?.sendValue(2)

        XCTAssertEqual(accumulator1.values, [0, 2, 4])
        XCTAssertEqual(accumulator2.values, [0, 1, 2])
    }

    func testPropertyRetention() {
        var capturedHandler: (any Publishers.CustomSubscriptionHandler<Int, Never>)? = nil
        let custom = Publishers.Custom<Int, Never> { handler in
            capturedHandler = handler
        }.eraseToAnyPublisher()

        let accumulator1 = TestAccumulator<Int>()
        let accumulator2 = TestAccumulator<Int>()

        weak var weakProp: Property<Int>? = nil

        autoreleasepool {
            let property = Property<Int>(initial: 0, then: custom)
            weakProp = property

            property
                .map { $0 * 2 }
                .handleValue { accumulator1.append($0) }
                .sink(duringLifetimeOf: self)

            property
                .handleValue { accumulator2.append($0) }
                .map { $0 * 2 }
                .sink(duringLifetimeOf: self)
        }

        XCTAssertNil(weakProp)

        capturedHandler?.sendValue(1)
        capturedHandler?.sendValue(2)

        XCTAssertEqual(accumulator1.values, [0, 2, 4])
        XCTAssertEqual(accumulator2.values, [0, 1, 2])
    }

    func testAsyncAccess() async {
        let prop = Property(value: 3)
        let t = await prop.async()
        XCTAssertEqual(t, 3)
    }
}
