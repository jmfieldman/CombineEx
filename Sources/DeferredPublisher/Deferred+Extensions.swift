//
//  Deferred+Extensions.swift
//  Copyright © 2023 Jason Fieldman.
//

import Combine

extension Deferred: DeferredPublisherProtocol {
  /// We can specify that `eraseToAnyPublisher` returns an `AnyDeferredPublisher`
  public func eraseToAnyPublisher() -> AnyDeferredPublisher<Output, Failure> {
    AnyDeferredPublisher(self)
  }
}
