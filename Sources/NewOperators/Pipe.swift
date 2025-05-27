//
//  Pipe.swift
//  Copyright © 2025 Jason Fieldman.
//

import Combine
import Foundation

infix operator <~: AssignmentPrecedence

/// Binds a publisher to a mutable property, updating the property with values emitted by the publisher.
/// - Parameters:
///   - lhs: The mutable property that will be updated with values from the publisher.
///   - rhs: The publisher that emits values of type `Output` and can emit errors of type `E`.
/// - Returns: Void
public func <~ <Output>(lhs: any MutablePropertyProtocol<Output>, rhs: any Publisher<Output, some Error>) {
    rhs.eraseToAnyPublisher()
        .sink(
            duringLifetimeOf: lhs,
            receiveValue: { [weak lhs] in lhs?.value = $0 }
        )
}

/// Binds a publisher to a mutable property, updating the property with values emitted by the publisher.
/// - Parameters:
///   - lhs: The mutable property that will be updated with values from the publisher.
///   - rhs: The publisher that emits values of type `Output` and never emits errors.
/// - Returns: Void
public func <~ <Output>(lhs: any MutablePropertyProtocol<Output>, rhs: any Publisher<Output, Never>) {
    rhs.eraseToAnyPublisher()
        .sink(
            duringLifetimeOf: lhs,
            receiveValue: { [weak lhs] in lhs?.value = $0 }
        )
}
