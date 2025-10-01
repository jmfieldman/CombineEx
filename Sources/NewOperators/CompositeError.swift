//
//  CompositeError.swift
//  Copyright © 2025 Jason Fieldman.
//

import Combine
import Foundation

/// The `CompositeError` protocol is adopted by Errors that may wrap
/// a multitude of lower errors.
///
/// Often, you may have a high-level operation that might fail in many
/// different types of sub-errors. For example, a long future may
/// emit a NetworkError, or a TransactionError, or some third/fourth/etc
/// error.
///
/// You then need to create an umbrella Error type that has cases
/// for all of those sub-error types. This type can adopt `CompositeError`
/// to improve some ergonomics around these cases.
public protocol CompositeError: Error {
    /// A `CompsiteError` must implement this function that dispatches
    /// any sub-error into the proper case. This typically checks if the
    /// error is already Self, and has a catch-all clause to wrap underlying
    /// any-Errors.
    static func wrapping(_ error: Error) -> Self
}

public extension Publisher {
    func wrapWithCompositeFailure<NewFailure>() -> Publishers.MapError<Self, NewFailure> where NewFailure: CompositeError {
        mapError { NewFailure.wrapping($0) }
    }

    func wrapWithCompositeFailure<NewFailure>(_ t: NewFailure.Type) -> Publishers.MapError<Self, NewFailure> where NewFailure: CompositeError {
        mapError { NewFailure.wrapping($0) }
    }
}

public extension DeferredPublisherProtocol {
    @_disfavoredOverload
    func wrapWithCompositeFailure<NewFailure>() -> Deferred<Publishers.MapError<WrappedPublisher, NewFailure>> where WrappedPublisher: Publisher, NewFailure: CompositeError {
        deferredLift { $0.wrapWithCompositeFailure() }
    }

    @_disfavoredOverload
    func wrapWithCompositeFailure<NewFailure>(_ t: NewFailure.Type) -> Deferred<Publishers.MapError<WrappedPublisher, NewFailure>> where WrappedPublisher: Publisher, NewFailure: CompositeError {
        deferredLift { $0.wrapWithCompositeFailure() }
    }
}

public extension DeferredFutureProtocol {
    @_disfavoredOverload
    func wrapWithCompositeFailure<NewFailure>() -> DeferredFuture<Output, NewFailure> where NewFailure: CompositeError {
        mapError { NewFailure.wrapping($0) }
    }

    @_disfavoredOverload
    func wrapWithCompositeFailure<NewFailure>(_ t: NewFailure.Type) -> DeferredFuture<Output, NewFailure> where NewFailure: CompositeError {
        mapError { NewFailure.wrapping($0) }
    }
}
