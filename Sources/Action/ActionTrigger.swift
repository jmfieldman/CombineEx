//
//  ActionTrigger.swift
//  Copyright © 2025 Jason Fieldman.
//

import Combine
import Foundation
import SwiftUI

/// An ActionTrigger is a convenience container for Actions that do not
/// care about the value/failure of the wrapped action.
///
/// Construct an ActionTrigger inside your view model, where you have access to
/// the underlying values/errors that are emitted from the associated
/// publisher. Then pass this ActionTrigger to the view where it can
/// use `applyAnonymous` to construct the associated publisher that
/// triggers the underlying action.
@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
@Observable
public final class ActionTrigger<Input>: Sendable {
    /// An @Observable property that indicates whether the action
    /// is currently executing.
    public let isExecuting: UIProperty<Bool>

    /// An @Observable property that indicates whether the UI element
    /// associated with firing this action should be enabled or not
    public let isEnabled: UIProperty<Bool>

    /// A closure that applies this anonymous action with the given input
    /// and returns a publisher associated with it.
    @ObservationIgnored
    public let applyAnonymous: @Sendable (Input) -> AnyDeferredPublisher<Void, Never>

    /// Initializes an ActionTrigger with the given internal action.
    ///
    /// - Parameters:
    ///   - internalAction: The underlying action to be wrapped.
    public init(_ internalAction: Action<Input, some Any, some Any>) {
        self.isExecuting = UIProperty(internalAction.isExecuting)
        self.isEnabled = UIProperty(internalAction.isEnabled)
        self.applyAnonymous = { input in
            internalAction.applyIfPossible(input)
                .demoteFailure()
                .map { _ in () }
                .eraseToAnyDeferredPublisher()
        }
    }

    /// Conveince wrapper around `applyAnonymous`
    public func apply(_ input: Input) -> AnyDeferredPublisher<Void, Never> {
        applyAnonymous(input)
    }

    /// Conveince wrapper around `applyAnonymous` where input is Void
    public func apply() -> AnyDeferredPublisher<Void, Never> where Input == Void {
        applyAnonymous(())
    }

    /// Conveince wrapper around `applyAnonymous` that sinks the resulting
    /// publisher against itself. Useful when you know the action will take
    /// the lifetime of the UI.
    public func fire(_ input: Input) {
        applyAnonymous(input).sink(duringLifetimeOf: self)
    }

    /// Conveince wrapper around `applyAnonymous` that sinks the resulting
    /// publisher against itself. Useful when you know the action will take
    /// the lifetime of the UI.
    public func fire() where Input == Void {
        applyAnonymous(()).sink(duringLifetimeOf: self)
    }

    /// Creates an ActionTrigger from an immediate action block.
    ///
    /// - Parameters:
    ///   - enabledIf: The action can only fire when this is true.
    ///   - block: The closure to execute when the action is applied.
    ///
    /// - Returns: A new ActionTrigger instance.
    public static func immediate(
        enabledIf: Property<Bool> = .just(true),
        _ block: @MainActor @escaping @Sendable (Input) -> Void
    ) -> ActionTrigger<Input> {
        Action<Input, Void, Never>.immediateOnMainActor(enabledIf: enabledIf, block).asActionTrigger
    }
}

@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
public protocol ActionTriggerConvertible<Input> {
    associatedtype Input
    var asActionTrigger: ActionTrigger<Input> { get }
}

@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
extension ActionTrigger: ActionTriggerConvertible {
    public var asActionTrigger: ActionTrigger<Input> { self }
}

@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
extension Action: ActionTriggerConvertible {
    public var asActionTrigger: ActionTrigger<Input> { .init(self) }
}

@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
extension AnyDeferredPublisher: ActionTriggerConvertible {
    public var asActionTrigger: ActionTrigger<Void> { Action { _ in self }.asActionTrigger }
}

@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
extension AnyDeferredFuture: ActionTriggerConvertible {
    public var asActionTrigger: ActionTrigger<Void> { Action { _ in self.eraseToAnyDeferredPublisher() }.asActionTrigger }
}
