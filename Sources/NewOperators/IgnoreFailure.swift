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
