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
        let capturedSubject = PassthroughSubject<Int, Never>()

        let property = Property<Int>(initial: 0, then: capturedSubject)
        let accumulator1 = TestAccumulator<Int>()
        let accumulator2 = TestAccumulator<Int>()
        let accumulator3 = TestAccumulator<Int>()

        property
            .map { $0 * 2 }
            .handleValue { accumulator1.append($0) }
            .sink(duringLifetimeOf: self)

        property
            .handleValue { accumulator2.append($0) }
            .map { $0 * 2 }
            .sink(duringLifetimeOf: self)

        capturedSubject.send(1)
        capturedSubject.send(2)

        XCTAssertEqual(accumulator1.values, [0, 2, 4])
        XCTAssertEqual(accumulator2.values, [0, 1, 2])
        XCTAssertEqual(accumulator3.values, [])

        property
            .handleValue { accumulator3.append($0) }
            .sink(duringLifetimeOf: self)

        capturedSubject.send(3)

        XCTAssertEqual(accumulator1.values, [0, 2, 4, 6])
        XCTAssertEqual(accumulator2.values, [0, 1, 2, 3])
        XCTAssertEqual(accumulator3.values, [2, 3])
    }

    func testPropertyRetention() {
        let capturedSubject = PassthroughSubject<Int, Never>()

        let accumulator1 = TestAccumulator<Int>()
        let accumulator2 = TestAccumulator<Int>()

        weak var weakProp: Property<Int>? = nil

        autoreleasepool {
            let property = Property<Int>(initial: 0, then: capturedSubject)
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

        capturedSubject.send(1)
        capturedSubject.send(2)

        XCTAssertEqual(accumulator1.values, [0, 2, 4])
        XCTAssertEqual(accumulator2.values, [0, 1, 2])
    }

    func testAsyncAccess() async {
        let prop = Property(value: 3)
        let t = await prop.async()
        XCTAssertEqual(t, 3)
    }

    func testFlatMap() {
        struct TestObj {
            let innerProperty: MutableProperty<Int>
        }
        let innerProp1 = MutableProperty(1)
        let innerProp2 = MutableProperty(10)

        let testObjProperty = MutableProperty<TestObj>(TestObj(innerProperty: innerProp1))
        let outerProperty: Property<Int> = testObjProperty.flatMap(\.innerProperty)

        let accumulator = TestAccumulator<Int>()
        outerProperty
            .handleValue { accumulator.append($0) }
            .sink(duringLifetimeOf: self)

        innerProp1.value = 2
        innerProp1.value = 3
        testObjProperty.value = TestObj(innerProperty: innerProp2)
        innerProp2.value = 20
        innerProp2.value = 30

        XCTAssertEqual(accumulator.values, [1, 2, 3, 10, 20, 30])
    }
}
