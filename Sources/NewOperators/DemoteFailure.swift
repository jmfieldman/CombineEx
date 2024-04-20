//
//  DemoteFailure.swift
//  Copyright © 2023 Jason Fieldman.
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
