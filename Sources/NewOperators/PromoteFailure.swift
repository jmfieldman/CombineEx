//
//  PromoteFailure.swift
//  Copyright © 2023 Jason Fieldman.
//

import Combine

public extension Publisher {
  /// Wraps `setFailureType(to:)` in a way that forces the type checker to
  /// imply what the desired new failure type will be.
  func promoteFailure<NewFailure>() -> Publishers.SetFailureType<Self, NewFailure> where Failure == Never {
    setFailureType(to: NewFailure.self)
  }
}
