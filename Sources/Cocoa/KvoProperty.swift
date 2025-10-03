//
//  KvoProperty.swift
//  Copyright © 2025 Jason Fieldman.
//

import Foundation

public protocol KVOPropertyProviding: NSObject {}

extension NSObject: KVOPropertyProviding {}

public extension KVOPropertyProviding {
    func kvoProperty<T>(
        _ keyPath: KeyPath<Self, T>
    ) -> Property<T> {
        let mutableProperty = MutableProperty(self[keyPath: keyPath])
        let property = Property(mutableProperty)

        let kvoToken = observe(keyPath) { obj, _ in
            mutableProperty.value = obj[keyPath: keyPath]
        }

        permanentlyAssociate(kvoToken)
        permanentlyAssociate(property)

        return property
    }
}

// MARK: - Permanent Association for NSObjects

private var kPermanentObjAssociationKey = 0

private func __AnyObjectPermanentObjStorage(_ object: AnyObject) -> NSMutableArray {
    if let array = objc_getAssociatedObject(object, &kPermanentObjAssociationKey) as? NSMutableArray {
        return array
    }

    let array = NSMutableArray()
    objc_setAssociatedObject(object, &kPermanentObjAssociationKey, array, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    return array
}

private final class AssociationBox<T> {
    let contained: T
    init(_ value: T) {
        self.contained = value
    }
}

extension NSObject {
    func permanentlyAssociate(_ t: some Any) {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        let storage = __AnyObjectPermanentObjStorage(self)
        storage.add(AssociationBox(t))
    }
}
