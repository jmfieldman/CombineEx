//
//  BindTarget.swift
//  Copyright © 2025 Jason Fieldman.
//

import Foundation

public protocol BindTargetProviding: AnyObject {}

extension NSObject: BindTargetProviding {}

public class BindTarget<T> {
    var associationKey: Int = 0
    let onSink: (AnyPublisher<T, Never>) -> AnyCancellable

    public init<Target: AnyObject>(
        target: Target,
        scheduler: some Scheduler = UIScheduler.shared,
        keyPath: WritableKeyPath<Target, T>
    ) {
        self.onSink = { [weak target] publisher in
            guard let target else {
                // It shouldn't be possible to get here, but including it to return some
                // AnyCancellable to avoid the optional return.
                return Just<Void>(()).sink(receiveValue: { _ in })
            }

            return publisher.receive(on: scheduler).sink(
                duringLifetimeOf: target,
                receiveValue: { [weak target] value in
                    target?[keyPath: keyPath] = value
                }
            )
        }

        // The BindTarget is usually instantiated ephemerally, and need to ensure that
        // its lifetime is bound to the receiving target. If this BindTarget is kept as
        // an ivar of the target it will just have two references and shouldn't be a problem.
        objc_setAssociatedObject(target, &associationKey, self, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    public init<Target: AnyObject>(
        target: Target,
        scheduler: some Scheduler = UIScheduler.shared,
        handler: @escaping @Sendable (Target, T) -> Void
    ) {
        self.onSink = { [weak target] publisher in
            guard let target else {
                // It shouldn't be possible to get here, but including it to return some
                // AnyCancellable to avoid the optional return.
                return Just<Void>(()).sink(receiveValue: { _ in })
            }

            return publisher.receive(on: scheduler).sink(
                duringLifetimeOf: target,
                receiveValue: { [weak target] value in
                    if let target {
                        handler(target, value)
                    }
                }
            )
        }

        // The BindTarget is usually instantiated ephemerally, and need to ensure that
        // its lifetime is bound to the receiving target. If this BindTarget is kept as
        // an ivar of the target it will just have two references and shouldn't be a problem.
        objc_setAssociatedObject(target, &associationKey, self, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}

public extension BindTargetProviding {
    func bind<T>(
        receiveOn scheduler: some Scheduler = UIScheduler.shared,
        _ keyPath: WritableKeyPath<Self, T>
    ) -> BindTarget<T> {
        BindTarget(target: self, scheduler: scheduler, keyPath: keyPath)
    }

    func bind<T>(
        receiveOn scheduler: some Scheduler = UIScheduler.shared,
        _ handler: @escaping @Sendable (Self, T) -> Void
    ) -> BindTarget<T> {
        BindTarget(target: self, scheduler: scheduler, handler: handler)
    }
}

public extension MutableProperty {
    func bind() -> BindTarget<Output> {
        BindTarget(target: self, scheduler: ImmediateScheduler.shared, keyPath: \.value)
    }
}

infix operator <~: AssignmentPrecedence

private var kBindingAssociationKey = 0

// swiftformat:disable opaqueGenericParameters

public func <~ <T, E: Error>(lhs: BindTarget<T>, rhs: some Publisher<T, E>) {
    let cancellable = lhs.onSink(rhs.demoteFailure().eraseToAnyPublisher())

    // The rhs producer is often an ephemerally-derived publisher that may
    // be created for the lifetime of this expression. We can bind it to the
    // lifetime of the cancellable. The cancellable is already bound to the
    // lifetime of the lhs target, so we are essentially keeping everything
    // bound for the lifetime of the lhs target.
    objc_setAssociatedObject(cancellable, &kBindingAssociationKey, rhs, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
}

public func <~ <T, E: Error>(lhs: BindTarget<T?>, rhs: some Publisher<T, E>) {
    let cancellable = lhs.onSink(rhs.mapOptional().demoteFailure().eraseToAnyPublisher())
    objc_setAssociatedObject(cancellable, &kBindingAssociationKey, rhs, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
}

public func <~ <T>(lhs: BindTarget<T>, rhs: some Publisher<T, Never>) {
    let cancellable = lhs.onSink(rhs.demoteFailure().eraseToAnyPublisher())
    objc_setAssociatedObject(cancellable, &kBindingAssociationKey, rhs, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
}

public func <~ <T>(lhs: BindTarget<T?>, rhs: some Publisher<T, Never>) {
    let cancellable = lhs.onSink(rhs.mapOptional().demoteFailure().eraseToAnyPublisher())
    objc_setAssociatedObject(cancellable, &kBindingAssociationKey, rhs, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
}

// swiftformat:enable opaqueGenericParameters
