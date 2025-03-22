//
//  Sink.swift
//  Copyright © 2025 Jason Fieldman.
//

import Combine
import Foundation

private var kSetAssociationKey = 0
private var kLockAssociationKey = 0

/// Returns a lock associated with the given object, creating one if it doesn't exist.
///
/// - Parameter object: The object to associate the lock with.
/// - Returns: An `NSLock` instance associated with the given object.
private func __AnyObjectCancellableLock(_ object: AnyObject) -> NSLock {
    objc_sync_enter(object)
    defer { objc_sync_exit(object) }

    if let lock = objc_getAssociatedObject(object, &kLockAssociationKey) as? NSLock {
        return lock
    }

    let lock = NSLock()
    objc_setAssociatedObject(
        object,
        &kLockAssociationKey,
        lock,
        objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC
    )
    return lock
}

/// Returns a mutable set associated with the given object, creating one if it doesn't exist.
///
/// - Parameter object: The object to associate the mutable set with.
/// - Returns: An `NSMutableSet` instance associated with the given object.
func __AnyObjectCancellableStorage(_ object: AnyObject) -> NSMutableSet {
    objc_sync_enter(object)
    defer { objc_sync_exit(object) }

    if let cancellables = objc_getAssociatedObject(object, &kSetAssociationKey) as? NSMutableSet {
        return cancellables
    }

    let cancellables = NSMutableSet()
    objc_setAssociatedObject(
        object,
        &kSetAssociationKey,
        cancellables,
        objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC
    )
    return cancellables
}

private class WeakCancellableBox {
    weak var cancellable: AnyCancellable?
}

public extension Publisher {
    /// Attaches a subscriber to the publisher and manages its lifecycle by associating it with an object.
    /// The subscription is automatically canceled when the associated object is deallocated, preventing memory leaks.
    ///
    /// - Parameters:
    ///   - object: The object whose lifetime determines when the subscription should be canceled.
    ///   - receiveSubscription: An optional closure to handle the received `Subscription`.
    ///   - receiveValue: An optional closure to handle new values emitted by the publisher.
    ///   - receiveCompletion: An optional closure to handle completion events from the publisher.
    ///   - receiveCancel: An optional closure to handle cancellation of the subscription.
    ///   - receiveRequest: An optional closure to handle demand requests for values from the publisher.
    ///
    /// - Returns: A `AnyCancellable` object, or `nil` if the associated object is already deallocated.
    @discardableResult
    func sink(
        duringLifetimeOf object: AnyObject,
        receiveSubscription: ((any Subscription) -> Void)? = nil,
        receiveValue: ((Self.Output) -> Void)? = nil,
        receiveCompletion: ((Subscribers.Completion<Self.Failure>) -> Void)? = nil,
        receiveCancel: (() -> Void)? = nil,
        receiveRequest: ((Subscribers.Demand) -> Void)? = nil
    ) -> AnyCancellable? {
        let cancellableBox = WeakCancellableBox()

        let remove = { [weak object, cancellableBox] in
            guard let object, let cancellable = cancellableBox.cancellable else { return }
            __AnyObjectCancellableLock(object).withLock {
                __AnyObjectCancellableStorage(object).remove(cancellable)
                cancellableBox.cancellable = nil
            }
        }

        // Create a sink with custom event handlers and store the cancellable.
        let cancellable = handleEvents(
            receiveSubscription: receiveSubscription,
            receiveCancel: {
                receiveCancel?()
                remove()
            },
            receiveRequest: receiveRequest
        ).sink(receiveCompletion: { completion in
            receiveCompletion?(completion)
            remove()
        }, receiveValue: { value in
            receiveValue?(value)
        })

        // Store the cancellable in the box so it can be explicitly removed.
        cancellableBox.cancellable = cancellable

        // Add the cancellable to the receiving object's lifecycle.
        __AnyObjectCancellableLock(object).withLock {
            __AnyObjectCancellableStorage(object).add(cancellable)
        }

        return cancellable
    }
}
