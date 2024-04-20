//
//  DeferredFutureProtocol.swift
//  Copyright © 2023 Jason Fieldman.
//

import Combine

// MARK: DeferredFutureProtocol

public protocol DeferredFutureProtocol<Output, Failure>: Publisher {
  associatedtype WrappedFuture = Future<Output, Failure>
  var attemptToFulfill: (@escaping Future<Output, Failure>.Promise) -> Void { get }
}
