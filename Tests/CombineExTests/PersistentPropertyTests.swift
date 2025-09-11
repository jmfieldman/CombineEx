//
//  PersistentPropertyTests.swift
//  Copyright © 2025 Jason Fieldman.
//

@testable import CombineEx
import XCTest

struct TestObject: Codable, Equatable {
    let int: Int
    let string: String
    let inner: Inner

    struct Inner: Codable, Equatable {
        let innerInt: Int
    }

    init(int: Int, string: String, inner: Int) {
        self.int = int
        self.string = string
        self.inner = Inner(innerInt: inner)
    }
}

final class PersistentPropertyTests: XCTestCase {
    var cancellable: AnyCancellable?

    func testPropertyStorageAndRetrieve() {
        let storageEngine = FileBasedPersistentPropertyStorageEngine(
            environmentId: "PersistentPropertyTest",
            rootDirectory: .temporary
        )
        storageEngine.wipeDirectory()

        let property = PersistentProperty<TestObject?>(
            storageEngine: storageEngine,
            key: "key",
            defaultValue: nil
        )

        XCTAssertNil(property.value)

        property.value = TestObject(int: 1, string: "test", inner: 2)

        let property2 = PersistentProperty<TestObject?>(
            storageEngine: storageEngine,
            key: "key",
            defaultValue: nil
        )

        XCTAssertEqual(property.value, property2.value)
    }

    func testPropertyPublisher() {
        let storageEngine = FileBasedPersistentPropertyStorageEngine(
            environmentId: "PersistentPropertyTest",
            rootDirectory: .temporary
        )
        storageEngine.wipeDirectory()

        let property = PersistentProperty<TestObject?>(
            storageEngine: storageEngine,
            key: "key",
            defaultValue: nil
        )

        XCTAssertNil(property.value)

        var iteration = 1
        var iterations = 0
        property.value = TestObject(int: iteration, string: "test", inner: 2)

        cancellable = property.sink { obj in
            XCTAssertEqual(obj, TestObject(int: iteration, string: "test", inner: 2))
            iterations += 1
        }

        iteration = 2
        property.value = TestObject(int: iteration, string: "test", inner: 2)

        XCTAssertEqual(2, iterations)
    }
}
