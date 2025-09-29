//
//  CompositeErrorTests.swift
//  Copyright © 2025 Jason Fieldman.
//

@testable import CombineEx
import XCTest

/// A generic error enum we can use for these test cases
private enum TestError: Error {
    case error1
}

private enum TestError2: Error {
    case error2
}

private enum TestOtherError: Error {
    case error3
}

private enum CompositeTestError: Error, CompositeError {
    case e1(TestError)
    case e2(TestError2)
    case underlying(Error)

    static func wrapping(_ error: any Error) -> CompositeTestError {
        if let e = error as? CompositeTestError {
            e
        } else if let e = error as? TestError {
            .e1(e)
        } else if let e = error as? TestError2 {
            .e2(e)
        } else {
            .underlying(error)
        }
    }
}

final class CompositeErrorTests: XCTestCase {
    func testWithTaskSuccess() async throws {
        let workFuture = DeferredFuture<Int, CompositeTestError>.withTask {
            1
        }

        let result = try await workFuture.asyncThrowing()
        XCTAssertEqual(result, 1)
    }

    func testWithTaskError1() async throws {
        let workFuture = DeferredFuture<Int, CompositeTestError>.withTask {
            throw TestError.error1
        }

        var e: Error?
        do {
            let _ = try await workFuture.asyncThrowing()
            XCTFail("Should not hit")
        } catch {
            e = error
        }

        guard let eTest = e as? CompositeTestError else {
            XCTFail("Bad")
            return
        }

        if case let .e1(eValue) = eTest, case .error1 = eValue {
            // Good
        } else {
            XCTFail("Bad")
        }
    }

    func testWithTaskError2() async throws {
        let workFuture = DeferredFuture<Int, CompositeTestError>.withTask {
            throw TestError2.error2
        }

        var e: Error?
        do {
            let _ = try await workFuture.asyncThrowing()
            XCTFail("Should not hit")
        } catch {
            e = error
        }

        guard let eTest = e as? CompositeTestError else {
            XCTFail("Bad")
            return
        }

        if case let .e2(eValue) = eTest, case .error2 = eValue {
            // Good
        } else {
            XCTFail("Bad")
        }
    }

    func testWithUnderlying() async throws {
        let workFuture = DeferredFuture<Int, CompositeTestError>.withTask {
            throw TestOtherError.error3
        }

        var e: Error?
        do {
            let _ = try await workFuture.asyncThrowing()
            XCTFail("Should not hit")
        } catch {
            e = error
        }

        guard let eTest = e as? CompositeTestError else {
            XCTFail("Bad")
            return
        }

        if case let .underlying(eValue) = eTest {
            XCTAssertNotNil(eValue as? TestOtherError)
        } else {
            XCTFail("Bad")
        }
    }

    func testPromotion() async throws {
        func makeFuture() -> AnyDeferredFuture<Int, CompositeTestError> {
            DeferredFuture<Int, TestError> { promise in
                promise(.failure(.error1))
            }
            .wrapWithCompositeFailure()
            .eraseToAnyDeferredFuture()
        }

        var e: Error?
        do {
            let _ = try await makeFuture().asyncThrowing()
            XCTFail("Should not hit")
        } catch {
            e = error
        }

        guard let eTest = e as? CompositeTestError else {
            XCTFail("Bad")
            return
        }

        if case let .e1(eValue) = eTest, case .error1 = eValue {
            // Good
        } else {
            XCTFail("Bad")
        }
    }
}
