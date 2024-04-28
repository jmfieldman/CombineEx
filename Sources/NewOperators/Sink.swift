//
//  Sink.swift
//  Copyright © 2023 Jason Fieldman.
//

import Combine

// MARK: - DeferredFutureProtocol

public extension Publisher {
  @_disfavoredOverload
  func sink() -> AnyCancellable {
    sink(receiveCompletion: { _ in }, receiveValue: { _ in })
  }
}
