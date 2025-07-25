//
//  Pipe.swift
//  Copyright © 2025 Jason Fieldman.
//

import Combine
import Foundation

// swiftformat:disable opaqueGenericParameters

infix operator <~: AssignmentPrecedence

private var kBindingAssociationKey = 0

/// Binds a publisher to a mutable property, updating the property with values emitted by the publisher.
/// - Parameters:
///   - lhs: The mutable property that will be updated with values from the publisher.
///   - rhs: The publisher that emits values of type `Output` and can emit errors of type `E`.
/// - Returns: Void
public func <~ <Output, E: Error>(lhs: any MutablePropertyProtocol<Output>, rhs: any Publisher<Output, E>) {
    let cancellable = rhs.eraseToAnyPublisher()
        .sink(
            duringLifetimeOf: lhs,
            receiveValue: { [weak lhs] in lhs?.value = $0 }
        )

    // Bind rhs to lifetime of cancellable to preserve it if it is a class
    objc_setAssociatedObject(cancellable, &kBindingAssociationKey, rhs, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
}

/// Binds a publisher to a mutable property, updating the property with values emitted by the publisher.
/// - Parameters:
///   - lhs: The mutable property that will be updated with values from the publisher.
///   - rhs: The publisher that emits values of type `Output` and never emits errors.
/// - Returns: Void
public func <~ <Output>(lhs: any MutablePropertyProtocol<Output>, rhs: any Publisher<Output, Never>) {
    let cancellable = rhs.eraseToAnyPublisher()
        .sink(
            duringLifetimeOf: lhs,
            receiveValue: { [weak lhs] in lhs?.value = $0 }
        )

    // Bind rhs to lifetime of cancellable to preserve it if it is a class
    objc_setAssociatedObject(cancellable, &kBindingAssociationKey, rhs, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
}

// swiftformat:enable opaqueGenericParameters
