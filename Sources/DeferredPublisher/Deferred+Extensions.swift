//
//  Deferred+Extensions.swift
//  Copyright © 2023 Jason Fieldman.
//

import Combine

extension Deferred: DeferredPublisherProtocol {
  public func eraseToAnyDeferredPublisher() -> AnyDeferredPublisher<Output, Failure> {
    AnyDeferredPublisher(self)
  }
}
