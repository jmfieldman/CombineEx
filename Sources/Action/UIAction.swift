//
//  UIAction.swift
//  Copyright © 2025 Jason Fieldman.
//

import Combine
import Foundation
import SwiftUI

/// A UIAction is a convenience container for Actions that do not
/// care about the value/failure of the wrapped action.
///
/// Construct a UIAction inside your view model, where you have access to
/// the underlying values/errors that are emitted from the associated
/// publisher. Then pass this UIAction to the view where it can
/// use `applyAnonymous` to construct the associated publisher that
/// triggers the underlying action.
@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
@Observable
public final class UIAction<Input> {
    /// An @Observable property that indicates whether the action
    /// is currently executing.
    public let isExecuting: UIProperty<Bool>

    /// A closure that applies this anonymous action with the given input
    /// and returns a publisher associated with it.
    @ObservationIgnored
    public let applyAnonymous: (Input) -> AnyDeferredPublisher<Void, Never>

    /// Initializes a UIAction with the given internal action.
    ///
    /// - Parameters:
    ///   - internalAction: The underlying action to be wrapped.
    public init(_ internalAction: Action<Input, some Any, some Any>) {
        self.isExecuting = UIProperty(internalAction.isExecuting)
        self.applyAnonymous = { input in
            internalAction.applyIfPossible(input)
                .demoteFailure()
                .map { _ in () }
                .eraseToAnyDeferredPublisher()
        }
    }

    /// Creates a UIAction from an immediate action block.
    ///
    /// - Parameters:
    ///   - block: The closure to execute when the action is applied.
    ///
    /// - Returns: A new UIAction instance.
    public static func immediate(_ block: @escaping (Input) -> Void) -> UIAction<Input> {
        Action<Input, Void, Never>.immediate(block).asUIAction
    }
}

public extension Action {
    /// Converts an `Action` to a `UIAction`.
    ///
    /// - Returns: A new `UIAction` instance wrapping the current action.
    var asUIAction: UIAction<Input> {
        UIAction(self)
    }
}
