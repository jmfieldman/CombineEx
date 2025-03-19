//
//  ActionTests.swift
//  Copyright © 2025 Jason Fieldman.
//

@testable import CombineEx
import XCTest

/// A generic error enum we can use for these test cases
private enum TestError: Error {
    case error1
}

final class ActionTests: XCTestCase {
    func testBasicAction() {
        let (action, countable) = ActionTests.createDoubleAction()
        XCTAssertEqual(countable.count, 0)
        let apply = action.apply(1)
        XCTAssertEqual(countable.count, 0)
        let expectation = XCTestExpectation(description: "value expectation")
        apply.handleValue {
            XCTAssertEqual($0, 2)
            XCTAssertEqual(countable.count, 1)
            expectation.fulfill()
        }.sink(duringLifetimeOf: self)
        wait(for: [expectation], timeout: 1)
    }

    // Actions and Publishers should not retain themselves
    func testBasicActionMemoryRetention() {
        weak var action: Action<Int, Int, TestError>?
        weak var apply: AnyDeferredPublisher<Int, ActionError<TestError>>?
        weak var countable: Countable?
        autoreleasepool {
            let (sAction, sCountable) = ActionTests.createDoubleAction()
            action = sAction
            countable = sCountable
            guard let action, let countable else {
                XCTFail("Weak references should not be nil")
                return
            }

            XCTAssertEqual(countable.count, 0)
            let sApply = action.apply(1)
            apply = sApply
            guard let apply else {
                XCTFail("Weak references should not be nil")
                return
            }
            XCTAssertEqual(countable.count, 0)
            let expectation = XCTestExpectation(description: "value expectation")
            apply.handleValue {
                XCTAssertEqual($0, 2)
                XCTAssertEqual(countable.count, 1)
                expectation.fulfill()
            }.sink(duringLifetimeOf: self)
            wait(for: [expectation], timeout: 1)
        }

        XCTAssertNil(action)
        XCTAssertNil(apply)
        XCTAssertNil(countable)
    }

    // Applied Publisher retains action during its lifecycle
    func testBasicActionMemoryRetentionByAppliedPublisher() {
        weak var action: Action<Int, Int, TestError>?
        var apply: AnyDeferredPublisher<Int, ActionError<TestError>>?
        var countable: Countable?
        autoreleasepool {
            let (sAction, sCountable) = ActionTests.createDoubleAction()
            action = sAction
            countable = sCountable
            guard let action, let countable else {
                XCTFail("Weak references should not be nil")
                return
            }

            XCTAssertEqual(countable.count, 0)
            apply = action.apply(1)
        }

        guard let apply, let countable else {
            XCTFail("Weak references should not be nil")
            return
        }

        XCTAssertEqual(countable.count, 0)
        let expectation = XCTestExpectation(description: "value expectation")
        apply.handleValue {
            XCTAssertEqual($0, 2)
            XCTAssertEqual(countable.count, 1)
            expectation.fulfill()
        }.sink(duringLifetimeOf: self)
        wait(for: [expectation], timeout: 1)

        XCTAssertNotNil(action)
        XCTAssertNotNil(apply)
        XCTAssertNotNil(countable)
    }

    /// The publisher derived from a .apply cannot be re-entered while running
    func testActionSameApplyIsDisabledWhenExecutingTwice() {
        let (action, countable) = ActionTests.createDoubleAction(internalDelay: 0.25)
        XCTAssertEqual(countable.count, 0)
        let apply = action.apply(1)
        XCTAssertEqual(countable.count, 0)
        let valueExpectation = XCTestExpectation(description: "value expectation")
        let errorExpectation = XCTestExpectation(description: "error expectation")
        apply.handleValue {
            XCTAssertEqual($0, 2)
            XCTAssertEqual(countable.count, 1)
            valueExpectation.fulfill()
        }.sink(duringLifetimeOf: self)
        apply.handleError { _ in
            errorExpectation.fulfill()
        }.sink(duringLifetimeOf: self)
        wait(for: [valueExpectation, errorExpectation], timeout: 2)
    }

    /// The same applied publisher can run serially
    func testActionSameApplyIsAllowedWhenExecutingSerially() {
        let (action, countable) = ActionTests.createDoubleAction(internalDelay: 0.25)
        XCTAssertEqual(countable.count, 0)
        let apply = action.apply(1)
        XCTAssertEqual(countable.count, 0)
        let valueExpectation1 = XCTestExpectation(description: "value expectation 1")
        let valueExpectation2 = XCTestExpectation(description: "value expectation 2")
        apply.handleValue {
            XCTAssertEqual($0, 2)
            XCTAssertEqual(countable.count, 1)
            valueExpectation1.fulfill()
        }.sink(duringLifetimeOf: self)
        wait(for: [valueExpectation1], timeout: 2)
        apply.handleValue {
            XCTAssertEqual($0, 2)
            XCTAssertEqual(countable.count, 2)
            valueExpectation2.fulfill()
        }.sink(duringLifetimeOf: self)
        wait(for: [valueExpectation2], timeout: 2)
    }

    /// Two separate publishers derived with .apply from the same action cannot
    /// run simultaneously. The second will fail.
    func testActionDifferentApplyIsDisabledWhenExecuting() {
        let (action, countable) = ActionTests.createDoubleAction(internalDelay: 0.25)
        XCTAssertEqual(countable.count, 0)
        let apply1 = action.apply(1)
        let apply2 = action.apply(2)
        XCTAssertEqual(countable.count, 0)
        let valueExpectation = XCTestExpectation(description: "value expectation")
        let errorExpectation = XCTestExpectation(description: "error expectation")
        apply1.handleValue {
            XCTAssertEqual($0, 2)
            XCTAssertEqual(countable.count, 1)
            valueExpectation.fulfill()
        }.sink(duringLifetimeOf: self)
        apply2.handleError { _ in
            errorExpectation.fulfill()
        }.sink(duringLifetimeOf: self)
        wait(for: [valueExpectation, errorExpectation], timeout: 2)
    }

    /// Basic sanity check that two separate actions are allowed to run simultaneously.
    func testActionDifferentActionCanRunSimultaneously() {
        let (action1, countable1) = ActionTests.createDoubleAction(internalDelay: 0.25)
        let (action2, countable2) = ActionTests.createDoubleAction(internalDelay: 0.25)
        XCTAssertEqual(countable1.count, 0)
        XCTAssertEqual(countable2.count, 0)
        let apply1 = action1.apply(1)
        let apply2 = action2.apply(2)
        XCTAssertEqual(countable1.count, 0)
        XCTAssertEqual(countable2.count, 0)
        let valueExpectation1 = XCTestExpectation(description: "value expectation 1")
        let valueExpectation2 = XCTestExpectation(description: "value expectation 2")
        apply1.handleValue {
            XCTAssertEqual($0, 2)
            XCTAssertEqual(countable1.count, 1)
            valueExpectation1.fulfill()
        }.sink(duringLifetimeOf: self)
        apply2.handleValue {
            XCTAssertEqual($0, 4)
            XCTAssertEqual(countable2.count, 1)
            valueExpectation2.fulfill()
        }.sink(duringLifetimeOf: self)
        wait(for: [valueExpectation1, valueExpectation2], timeout: 2)
    }
}

// MARK: Test Helpers

private extension ActionTests {
    static func createDoubleAction(internalDelay: TimeInterval? = nil) -> (Action<Int, Int, TestError>, Countable) {
        let countable = Countable()
        let action = Action<Int, Int, TestError> { input in
            DeferredFuture { promise in
                countable.count += 1
                DispatchQueue.global().asyncAfter(deadline: .now() + (internalDelay ?? 0)) {
                    promise(input < 0 ? .failure(.error1) : .success(input * 2))
                }
            }
            .eraseToAnyDeferredPublisher()
        }
        return (action, countable)
    }
}
