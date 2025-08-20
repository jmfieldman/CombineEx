//
//  PropertyMapTests.swift
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

final class PropertyMapTests: XCTestCase {
    var cancellable: AnyCancellable?

    func testPropertyMapNoRemoveDuplicates() {
        let subject = CurrentValueSubject<[TestValue], Never>([])
        var outputModels: [OutputModel] = []
        var emissions = 0
        var instantiations = 0
        var propertyEmissions = 0
        cancellable = subject
            .propertyMap(removeDuplicates: false) { testValueProperty -> OutputModel in
                instantiations += 1
                return OutputModel(
                    id: testValueProperty.value.id,
                    valueProperty: testValueProperty.map {
                        propertyEmissions += 1
                        return $0.value
                    }
                )
            }
            .sink { newOutputModels in
                emissions += 1
                outputModels = newOutputModels
            }

        XCTAssertEqual(emissions, 1)
        XCTAssertEqual(instantiations, 0)
        XCTAssertEqual(propertyEmissions, 0)
        XCTAssertEqual(outputModels.map(\.id), [])

        subject.send([
            TestValue(id: "1", value: 1),
            TestValue(id: "2", value: 2),
        ])

        XCTAssertEqual(emissions, 2)
        XCTAssertEqual(instantiations, 2)
        XCTAssertEqual(propertyEmissions, 2)
        XCTAssertEqual(outputModels.map(\.id), ["1", "2"])
        XCTAssertEqual(outputModels.map(\.valueProperty.value), [1, 2])

        subject.send([
            TestValue(id: "1", value: 2),
            TestValue(id: "2", value: 3),
        ])

        // Emissions do not update, since Identifiable array is the same -
        // but the property values update.
        XCTAssertEqual(emissions, 2)
        XCTAssertEqual(instantiations, 2)
        XCTAssertEqual(propertyEmissions, 4)
        XCTAssertEqual(outputModels.map(\.id), ["1", "2"])
        XCTAssertEqual(outputModels.map(\.valueProperty.value), [2, 3])

        subject.send([
            TestValue(id: "1", value: 2),
            TestValue(id: "2", value: 3),
        ])

        // property emissions update since we are not removing duplicates.
        XCTAssertEqual(emissions, 2)
        XCTAssertEqual(instantiations, 2)
        XCTAssertEqual(propertyEmissions, 6)
        XCTAssertEqual(outputModels.map(\.id), ["1", "2"])
        XCTAssertEqual(outputModels.map(\.valueProperty.value), [2, 3])

        subject.send([
            TestValue(id: "0", value: 0),
            TestValue(id: "2", value: 4),
        ])

        // Emission updates with the new identifiable, and it only increments instantiations
        // by one, since only "0" is new.
        XCTAssertEqual(emissions, 3)
        XCTAssertEqual(instantiations, 3)
        XCTAssertEqual(propertyEmissions, 8)
        XCTAssertEqual(outputModels.map(\.id), ["0", "2"])
        XCTAssertEqual(outputModels.map(\.valueProperty.value), [0, 4])
    }

    func testPropertyMapRemoveDuplicates() {
        let subject = CurrentValueSubject<[TestValue], Never>([])
        var outputModels: [OutputModel] = []
        var emissions = 0
        var instantiations = 0
        var propertyEmissions = 0
        cancellable = subject
            .propertyMap(removeDuplicates: true) { testValueProperty -> OutputModel in
                instantiations += 1
                return OutputModel(
                    id: testValueProperty.value.id,
                    valueProperty: testValueProperty.map {
                        propertyEmissions += 1
                        return $0.value
                    }
                )
            }
            .sink { newOutputModels in
                emissions += 1
                outputModels = newOutputModels
            }

        XCTAssertEqual(emissions, 1)
        XCTAssertEqual(instantiations, 0)
        XCTAssertEqual(propertyEmissions, 0)
        XCTAssertEqual(outputModels.map(\.id), [])

        subject.send([
            TestValue(id: "1", value: 1),
            TestValue(id: "2", value: 2),
        ])

        XCTAssertEqual(emissions, 2)
        XCTAssertEqual(instantiations, 2)
        XCTAssertEqual(propertyEmissions, 2)
        XCTAssertEqual(outputModels.map(\.id), ["1", "2"])
        XCTAssertEqual(outputModels.map(\.valueProperty.value), [1, 2])

        subject.send([
            TestValue(id: "1", value: 2),
            TestValue(id: "2", value: 3),
        ])

        // Emissions do not update, since Identifiable array is the same -
        // but the property values update.
        XCTAssertEqual(emissions, 2)
        XCTAssertEqual(instantiations, 2)
        XCTAssertEqual(propertyEmissions, 4)
        XCTAssertEqual(outputModels.map(\.id), ["1", "2"])
        XCTAssertEqual(outputModels.map(\.valueProperty.value), [2, 3])

        subject.send([
            TestValue(id: "1", value: 2),
            TestValue(id: "2", value: 3),
        ])

        // property emissions do not update since we are removing duplicates.
        XCTAssertEqual(emissions, 2)
        XCTAssertEqual(instantiations, 2)
        XCTAssertEqual(propertyEmissions, 4)
        XCTAssertEqual(outputModels.map(\.id), ["1", "2"])
        XCTAssertEqual(outputModels.map(\.valueProperty.value), [2, 3])

        subject.send([
            TestValue(id: "0", value: 0),
            TestValue(id: "2", value: 4),
        ])

        // Emission updates with the new identifiable, and it only increments instantiations
        // by one, since only "0" is new.
        XCTAssertEqual(emissions, 3)
        XCTAssertEqual(instantiations, 3)
        XCTAssertEqual(propertyEmissions, 6)
        XCTAssertEqual(outputModels.map(\.id), ["0", "2"])
        XCTAssertEqual(outputModels.map(\.valueProperty.value), [0, 4])
    }
}
