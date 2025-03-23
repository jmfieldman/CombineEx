//
//  FilterProperty.swift
//  Copyright © 2025 Jason Fieldman.
//

import Combine

public extension Publisher {
    /// Returns a publisher that includes elements from the upstream publisher when the
    /// specified property is true -- i.e. the provided property acts as a sieve that
    /// allows output while it is true.
    ///
    /// - Parameters:
    ///   - property: A property that provides a Boolean value. Elements are included while
    ///     this property's value is `true`.
    ///
    /// - Returns: A publisher that includes elements while the property's value is `true`.
    func filter(
        _ isIncluded: any PropertyProtocol<Bool>
    ) -> Publishers.Filter<Self> {
        filter { _ in isIncluded.value }
    }
}

public extension DeferredPublisherProtocol {
    /// Returns a deferred publisher that includes elements from the upstream publisher when the
    /// specified property is true -- i.e. the provided property acts as a sieve that
    /// includes output while it is true.
    ///
    /// - Parameters:
    ///   - property: A property that provides a Boolean value. Elements are included while
    ///     this property's value is `true`.
    ///
    /// - Returns: A deferred publisher that includes elements while the property's value is `true`.
    @_disfavoredOverload
    func filter(
        _ isIncluded: any PropertyProtocol<Bool>
    ) -> Deferred<Publishers.Filter<WrappedPublisher>> where WrappedPublisher: Publisher {
        deferredLift { $0.filter { _ in isIncluded.value } }
    }
}
