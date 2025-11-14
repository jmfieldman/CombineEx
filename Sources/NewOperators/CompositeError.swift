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
///
/// `CompositeError` must always have a case `unexpected(Error)` to handle
/// errors that do not cleanly map into other well-named cases.
public protocol CompositeError: Error {
    /// A `CompsiteError` must implement this map that dispatches
    /// any sub-error into the proper case.
    ///
    /// It does not need to handle cases where error is Self, or when
    /// it is an unexpected sub-error.
    ///
    /// A typical implementation might look like:
    ///
    ///   static let errorMap = CompositeErrorMap<CompositeTestError>()
    ///       .mapping(TestError.self) { .e1($0) }
    ///       .mapping(TestError2.self) { .e2($0) }
    ///
    static var errorMap: CompositeErrorMap<Self> { get }

    /// This must return the corresponding `unexpected(Error)` case.
    /// Swift magic allows this constraint to be satisfied by simply
    /// having the correct case:
    /// `case unexpected(Error)`
    static func unexpected(_ error: Error) -> Self
}

public extension CompositeError {
    /// This extension returns an optional Self that reflects all cases
    /// except the `unexpected(Error)` case. This is useful for recursive
    /// wrapping that does not capture the unexpected cases
    static func wrappingWithSelf(_ error: some Error) -> Self? {
        if let selfError = error as? Self {
            selfError
        } else {
            Self.errorMap.resolving(error)
        }
    }

    /// This wraps all cases. It will return the unexpected cases if no
    /// other cases match.
    static func wrappingAllCases(_ error: some Error) -> Self {
        wrappingWithSelf(error) ?? unexpected(error)
    }
}

public final class CompositeErrorMap<T: CompositeError>: @unchecked Sendable {
    private var internalArray: [(CompositeErrorMapElementProtocol, (Any) -> T)] = []

    public init() {}

    public func mapping<E: Error>(_ type: E.Type, resolution: @escaping @Sendable (E) -> T) -> Self {
        internalArray.append((CompositeErrorMapElement(type), { resolution($0 as! E) }))
        return self
    }

    func resolving(_ error: some Error) -> T? {
        for resolution in internalArray {
            if resolution.0.check(error) {
                return resolution.1(error)
            }
        }
        return nil
    }
}

protocol CompositeErrorMapElementProtocol {
    func check(_ error: some Error) -> Bool
}

final class CompositeErrorMapElement<E: Error>: CompositeErrorMapElementProtocol {
    let t: E.Type
    init(_ t: E.Type) { self.t = t }
    func check(_ error: some Error) -> Bool {
        (error as? E) != nil
    }
}

public extension Publisher {
    func wrapWithCompositeFailure<NewFailure>() -> Publishers.MapError<Self, NewFailure> where NewFailure: CompositeError {
        mapError { NewFailure.wrappingAllCases($0) }
    }

    func wrapWithCompositeFailure<NewFailure>(_ t: NewFailure.Type) -> Publishers.MapError<Self, NewFailure> where NewFailure: CompositeError {
        mapError { NewFailure.wrappingAllCases($0) }
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
        mapError { NewFailure.wrappingAllCases($0) }
    }

    @_disfavoredOverload
    func wrapWithCompositeFailure<NewFailure>(_ t: NewFailure.Type) -> DeferredFuture<Output, NewFailure> where NewFailure: CompositeError {
        mapError { NewFailure.wrappingAllCases($0) }
    }
}
