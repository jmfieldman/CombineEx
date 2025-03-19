//
//  DemoteFailure.swift
//  Copyright © 2025 Jason Fieldman.
//

import Combine

public extension Publisher {
    /// Convenience wrapper to ignores failures and set the new Publisher
    /// failure type to Never.
    func demoteFailure() -> Publishers.Catch<Self, Empty<Output, Never>> {
        self.catch { _ in
            Empty(outputType: Output.self, failureType: Never.self)
        }
    }
}

public extension DeferredPublisherProtocol {
    @_disfavoredOverload
    func demoteFailure() -> Deferred<Publishers.Catch<WrappedPublisher, Empty<Output, Never>>> where WrappedPublisher: Publisher {
        deferredLift { $0.demoteFailure() }
    }
}
