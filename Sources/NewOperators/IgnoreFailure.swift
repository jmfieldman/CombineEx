//
//  IgnoreFailure.swift
//  Copyright © 2023 Jason Fieldman.
//

import Combine

public extension Publisher {
  /// Convenience wrapper to ignore failures.
  func ignoreFailure() -> Publishers.Catch<Self, Empty<Output, Failure>> {
    self.catch { _ in
      Empty(outputType: Output.self, failureType: Failure.self)
    }
  }
}

public extension DeferredPublisherProtocol {
  @_disfavoredOverload
  func ignoreFailure() -> Deferred<Publishers.Catch<WrappedPublisher, Empty<Output, Failure>>> where WrappedPublisher: Publisher, WrappedPublisher.Failure == Failure {
    deferredLift { $0.ignoreFailure() }
  }
}
