//
//  DeferredPublisherProtocol.swift
//  Copyright © 2023 Jason Fieldman.
//

import Combine

// MARK: DeferredPublisherProtocol

/// `DeferredPublisherProtocol` allow both `Deferred` and `AnyDeferredPublisher`
/// to conform and inherit the new deferred operators.
public protocol DeferredPublisherProtocol<Output, Failure>: Publisher {
  associatedtype WrappedPublisher = any Publisher<Output, Failure>
  var createPublisher: () -> WrappedPublisher { get }
}
