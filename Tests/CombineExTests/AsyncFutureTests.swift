//
//  AsyncFutureTests.swift
//  Copyright © 2025 Jason Fieldman.
//

@testable import CombineEx
import XCTest

/// A generic error enum we can use for these test cases
private enum TestError: Error {
    case error1
}

final class AsyncFutureTests: XCTestCase {
    func testAsyncFuture() async {
        let workFuture = DeferredFuture<Int, Never> { promise in
            DispatchQueue.global().async {
                promise(.success(42))
            }
        }

        let result: Int = await workFuture.async()
        XCTAssertEqual(result, 42)
    }

    func testAsyncFutureChained() async {
        func makeWork(_ i: Int) -> AnyDeferredFuture<Int, Never> {
            DeferredFuture<Int, Never> { promise in
                DispatchQueue.global().async {
                    promise(.success(i))
                }
            }.eraseToAnyDeferredFuture()
        }

        let chainedFuture = DeferredFuture<Int, Never>.withTask {
            let a = await makeWork(10).async()
            let b = await makeWork(10).async()
            let c = await makeWork(10).async()
            return a + b + c
        }

        let result: Int = await chainedFuture.async()
        XCTAssertEqual(result, 30)
    }

    func testAsyncFutureThrowing() async throws {
        let workFuture = DeferredFuture<Int, TestError> { promise in
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.25) {
                promise(.success(42))
            }
        }

        let result: Int = try await workFuture.asyncThrowing()
        XCTAssertEqual(result, 42)
    }

    func testAsyncFutureThrowingDoes() async throws {
        let workFuture = DeferredFuture<Int, TestError> { promise in
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.25) {
                promise(.failure(.error1))
            }
        }

        var e: TestError? = nil
        do {
            let _ = try await workFuture.asyncThrowing()
            XCTFail("Don't get here")
        } catch {
            e = error
        }

        XCTAssertEqual(e, .error1)
    }
}
