//
//  JustFailEmpty.swift
//  Copyright © 2025 Jason Fieldman.
//

import Combine
import Foundation

/// Static helper methods for creating publishers with common values and errors.
public extension Publisher {
    /// Creates a publisher that immediately emits the specified value and then finishes.
    ///
    /// - Parameter value: The value to emit.
    /// - Returns: An `AnyPublisher` that emits the specified value and then finishes.
    static func just(_ value: Output) -> AnyPublisher<Output, Failure> {
        Just<Output>(value).setFailureType(to: Failure.self).eraseToAnyPublisher()
    }

    /// Creates a publisher that immediately fails with the specified error.
    ///
    /// - Parameter failure: The error to fail with.
    /// - Returns: An `AnyPublisher` that immediately fails with the specified error.
    static func fail(_ failure: Failure) -> AnyPublisher<Output, Failure> {
        Fail(outputType: Output.self, failure: failure).eraseToAnyPublisher()
    }

    /// Creates a publisher that immediately finishes without emitting any values.
    ///
    /// - Returns: An `AnyPublisher` that immediately finishes.
    static func empty() -> AnyPublisher<Output, Failure> {
        Empty<Output, Failure>().eraseToAnyPublisher()
    }
}
