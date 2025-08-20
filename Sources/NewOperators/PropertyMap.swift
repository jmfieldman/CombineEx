//
//  PropertyMap.swift
//  Copyright © 2025 Jason Fieldman.
//

import Combine

public extension Publishers {
    /// A publisher that maps an array of identifiable elements to a transformed array.
    /// The publisher only outputs a new array when the order of identifiable elements
    /// has changed. Each entry in the output is derived *once* per input value, but the
    /// transform block takes a Property of all new values that its identifier receives.
    /// This allows you to embed Properties in the `TransformOutput` derived from changes
    /// to the element.
    ///
    /// - Parameters:
    ///   - upstream: The upstream publisher that emits arrays of identifiable elements.
    ///   - removeDuplicates: Whether to remove duplicate values from the property stream.
    ///   - transform: A closure that transforms a `Property<Element>` into a `TransformOutput`.
    struct PropertyMap<Upstream: Publisher, Element: Identifiable & Equatable, TransformOutput>: Publisher where Upstream.Output == [Element] {
        public typealias Output = [TransformOutput]
        public typealias Failure = Upstream.Failure

        let upstream: Upstream
        let removeDuplicates: Bool
        let transform: (Property<Element>) -> TransformOutput

        /// Receives a subscriber and sets up the transformation logic.
        ///
        /// - Parameter subscriber: The subscriber to receive outputs.
        public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
            // Each subscriber captures its own intermediate state
            var propertyMap: [Element.ID: MutableProperty<Element>] = [:]
            var transformOutputMap: [Element.ID: TransformOutput] = [:]
            var previousIdOrder: [Element.ID] = []
            var emittedOnce = false

            upstream.compactMap { values -> [TransformOutput]? in
                var unseenIds = Set(propertyMap.keys)
                let sameSize = values.count == previousIdOrder.count
                var idOrderMismatch = !sameSize

                for (index, value) in values.enumerated() {
                    // Detect ID ordering mismatch
                    if sameSize, !idOrderMismatch {
                        if value.id != previousIdOrder[index] {
                            idOrderMismatch = true
                        }
                    }

                    // We saw this ID, so remove it from `unseenIds`
                    unseenIds.remove(value.id)

                    // Update or create the property entry
                    if let existingProperty = propertyMap[value.id] {
                        existingProperty.value = value
                    } else {
                        let newProperty = MutableProperty(value)
                        propertyMap[value.id] = newProperty

                        if removeDuplicates {
                            transformOutputMap[value.id] = transform(newProperty.removeDuplicates())
                        } else {
                            transformOutputMap[value.id] = transform(Property(newProperty))
                        }
                    }
                }

                // Update previous ids
                previousIdOrder = values.map(\.id)

                // Clean up unseedIds
                for id in unseenIds {
                    propertyMap[id] = nil
                    transformOutputMap[id] = nil
                }

                // If we are the same order, we don't need to emit a new top-level order
                if !idOrderMismatch, emittedOnce {
                    return nil
                }

                emittedOnce = true
                return values.compactMap { transformOutputMap[$0.id] }
            }.subscribe(subscriber)
        }
    }
}

public extension Publisher {
    /// A publisher that maps an array of identifiable elements to a transformed array.
    /// The publisher only outputs a new array when the order of identifiable elements
    /// has changed. Each entry in the output is derived *once* per input value, but the
    /// transform block takes a Property of all new values that its identifier receives.
    /// This allows you to embed Properties in the `TransformOutput` derived from changes
    /// to the element.
    ///
    /// - Parameters:
    ///   - removeDuplicates: Whether to apply deduplication on the property stream.
    ///   - transform: A closure that transforms a `Property<Element>` into a `TransformOutput`.
    /// - Returns: A `PropertyMap` publisher that applies the transformation.
    func propertyMap<Element: Identifiable & Equatable, TransformOutput>(
        removeDuplicates: Bool = true,
        transform: @escaping (Property<Element>) -> TransformOutput
    ) -> Publishers.PropertyMap<Self, Element, TransformOutput> where Output == [Element] {
        Publishers.PropertyMap(
            upstream: self,
            removeDuplicates: removeDuplicates,
            transform: transform
        )
    }
}

public extension DeferredPublisherProtocol {
    /// Transforms the deferred publisher by applying a property mapping transformation.
    ///
    /// A publisher that maps an array of identifiable elements to a transformed array.
    /// The publisher only outputs a new array when the order of identifiable elements
    /// has changed. Each entry in the output is derived *once* per input value, but the
    /// transform block takes a Property of all new values that its identifier receives.
    /// This allows you to embed Properties in the `TransformOutput` derived from changes
    /// to the element.
    ///
    /// - Parameters:
    ///   - removeDuplicates: Whether to apply deduplication on the property stream.
    ///   - transform: A closure that transforms a `Property<Element>` into a `TransformOutput`.
    /// - Returns: A deferred publisher that applies the property mapping.
    @_disfavoredOverload
    func propertyMap<Element: Identifiable & Equatable, TransformOutput>(
        removeDuplicates: Bool = true,
        transform: @escaping (Property<Element>) -> TransformOutput
    ) -> Deferred<Publishers.PropertyMap<WrappedPublisher, Element, TransformOutput>> where WrappedPublisher.Output == [Element] {
        deferredLift {
            $0.propertyMap(removeDuplicates: removeDuplicates, transform: transform)
        }
    }
}
