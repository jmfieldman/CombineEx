//
//  PromoteFailure.swift
//  Copyright © 2023 Jason Fieldman.
//

import Combine

public extension Publisher where Failure == Never {
  /// Wraps `setFailureType(to:)` in a way that forces the type checker to
  /// imply what the desired new failure type will be.
  func promoteFailure<NewFailure>() -> Publishers.SetFailureType<Self, NewFailure> {
    setFailureType(to: NewFailure.self)
  }
}

public extension DeferredPublisherProtocol where Failure == Never {
  @_disfavoredOverload
  func promoteFailure<NewFailure>() -> Deferred<Publishers.SetFailureType<WrappedPublisher, NewFailure>> where WrappedPublisher: Publisher {
    deferredLift { $0.setFailureType(to: NewFailure.self) }
  }
}

public extension DeferredFutureProtocol where Failure == Never {
  @_disfavoredOverload
  func promoteFailure<NewFailure>() -> DeferredFuture<Output, NewFailure> {
    futureLiftFailure { _, _ in }
  }
}
