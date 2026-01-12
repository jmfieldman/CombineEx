//
//  SendableOverloads.swift
//  Copyright © 2025 Jason Fieldman.
//

import Combine
import Foundation

/*
 There are some native functions that we cannot naturally overload for certain protocols.
 For example, compactMap doesn't work on properties or futures, since they must guarantee
 values are emitted/present.

 If we leave them completely empty, then we have issues with @Sendable conformance (since
 normal Combine functions do not take Sendable parameters. This causes issues if the base
 publisher emits on a background thread.

 In this file we can add function overloads to these classes that accept Sendable parameters.
 */

// Properties typically degrade into standard hot publishers.

public extension PropertyProtocol {
    func compactMap<T>(
        _ transform: @escaping @Sendable (Output) -> T?,
    ) -> Publishers.CompactMap<AnyPublisher<Output, Never>, T> {
        eraseToAnyPublisher().compactMap { @Sendable in transform($0) }
    }
}

// DeferredFutures degrade into DeferredPublishers

public extension DeferredFutureProtocol {
    func compactMap<T>(
        _ transform: @escaping @Sendable (Output) -> T?,
    ) -> some DeferredPublisherProtocol<T, Failure> {
        eraseToAnyDeferredPublisher().compactMap { @Sendable in transform($0) }
    }
}
