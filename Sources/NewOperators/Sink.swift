//
//  Sink.swift
//  Copyright © 2023 Jason Fieldman.
//

import Combine
import Foundation

private var kSetAssociationKey = 0
private var kLockAssociationKey = 0

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

private func __AnyObjectCancellableStorage(_ object: AnyObject) -> NSMutableSet {
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

private class CancellableBox {
  var cancellable: AnyCancellable?
}

public extension Publisher {
  func sink(
    duringLifetimeOf object: AnyObject,
    receiveSubscription: ((any Subscription) -> Void)? = nil,
    receiveValue: ((Self.Output) -> Void)? = nil,
    receiveCompletion: ((Subscribers.Completion<Self.Failure>) -> Void)? = nil,
    receiveCancel: (() -> Void)? = nil,
    receiveRequest: ((Subscribers.Demand) -> Void)? = nil
  ) -> AnyCancellable? {
    let cancellableBox = CancellableBox()

    let remove = { [weak object, cancellableBox] in
      guard let object, let cancellable = cancellableBox.cancellable else { return }
      __AnyObjectCancellableLock(object).withLock {
        __AnyObjectCancellableStorage(object).remove(cancellable)
      }
    }

    cancellableBox.cancellable = handleEvents(
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

    return cancellableBox.cancellable
  }
}
