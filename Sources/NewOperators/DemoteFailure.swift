//
//  DemoteFailure.swift
//  Copyright © 2025 Jason Fieldman.
//

import Combine

public extension Publisher {
    /// Convenience wrapper to ignore failures and set the new publisher's failure type to `Never`.
    ///
    /// - Returns: A `Publishers.Catch` instance with the failure type set to `Never`.
    func demoteFailure() -> Publishers.Catch<Self, Empty<Output, Never>> {
        self.catch { _ in
            Empty(outputType: Output.self, failureType: Never.self)
        }
    }
}

public extension DeferredPublisherProtocol {
    /// Convenience wrapper to ignore failures and set the new deferred publisher's failure type to `Never`.
    ///
    /// - Returns: A `Deferred<Publishers.Catch<WrappedPublisher, Empty<Output, Never>>>` instance with the failure type set to `Never`.
    @_disfavoredOverload
    func demoteFailure() -> Deferred<Publishers.Catch<WrappedPublisher, Empty<Output, Never>>> where WrappedPublisher: Publisher {
        deferredLift { $0.demoteFailure() }
    }
}
