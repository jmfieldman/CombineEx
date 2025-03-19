//
//  PropertyProtocol+Operators.swift
//  Copyright © 2025 Jason Fieldman.
//

import Combine

public extension PropertyProtocol {
    func lift<U>(
        _ transform: @escaping (AnyPublisher<Output, Never>) -> some Publisher<U, Never>
    ) -> Property<U> {
        Property(unsafe: transform(eraseToAnyPublisher()))
    }
}

public extension PropertyProtocol {
    @_disfavoredOverload
    func map<T>(
        _ transform: @escaping (Output) -> T
    ) -> Property<T> {
        lift { $0.map(transform) }
    }

    @_disfavoredOverload
    func map<T>(
        value: T
    ) -> Property<T> {
        lift { _ in Just(value) }
    }

    @_disfavoredOverload
    func map<T>(
        _ keyPath: KeyPath<Output, T>
    ) -> Property<T> {
        lift { $0.map(keyPath) }
    }

    @_disfavoredOverload
    func filter(
        initial: Output,
        _ predicate: @escaping (Output) -> Bool
    ) -> Property<Output> {
        Property(initial: initial, then: filter(predicate))
    }

    @_disfavoredOverload
    func combinePrevious(
        _ initial: Output
    ) -> Property<(Output, Output)> {
        lift { $0.combinePrevious(initial) }
    }

    @_disfavoredOverload
    func removeDuplicates(
        by isEqual: @escaping (Output, Output) -> Bool
    ) -> Property<Output> {
        lift { $0.removeDuplicates(by: isEqual) }
    }
}

public extension PropertyProtocol where Output: Equatable {
    @_disfavoredOverload
    func removeDuplicates() -> Property<Output> {
        lift { $0.removeDuplicates() }
    }
}

public extension PropertyProtocol {
    @_disfavoredOverload
    func combineLatest<A>(
        _ pA: some PropertyProtocol<A>
    ) -> Property<(Output, A)> {
        lift { $0.combineLatest(pA) }
    }

    @_disfavoredOverload
    func combineLatest<A, B>(
        _ pA: some PropertyProtocol<A>,
        _ pB: some PropertyProtocol<B>
    ) -> Property<(Output, A, B)> {
        lift { $0.combineLatest(pA, pB) }
    }

    @_disfavoredOverload
    func combineLatest<A, B, C>(
        _ pA: some PropertyProtocol<A>,
        _ pB: some PropertyProtocol<B>,
        _ pC: some PropertyProtocol<C>
    ) -> Property<(Output, A, B, C)> {
        lift { $0.combineLatest(pA, pB, pC) }
    }

    @_disfavoredOverload
    func combineLatest<A, B, C, D>(
        _ pA: some PropertyProtocol<A>,
        _ pB: some PropertyProtocol<B>,
        _ pC: some PropertyProtocol<C>,
        _ pD: some PropertyProtocol<D>
    ) -> Property<(Output, A, B, C, D)> {
        lift { $0.combineLatest(pA, pB, pC, pD) }
    }

    @_disfavoredOverload
    func combineLatest<A, B, C, D, E>(
        _ pA: some PropertyProtocol<A>,
        _ pB: some PropertyProtocol<B>,
        _ pC: some PropertyProtocol<C>,
        _ pD: some PropertyProtocol<D>,
        _ pE: some PropertyProtocol<E>
    ) -> Property<(Output, A, B, C, D, E)> {
        lift { $0.combineLatest(pA, pB, pC, pD, pE) }
    }

    @_disfavoredOverload
    func combineLatest<A, B, C, D, E, F>(
        _ pA: some PropertyProtocol<A>,
        _ pB: some PropertyProtocol<B>,
        _ pC: some PropertyProtocol<C>,
        _ pD: some PropertyProtocol<D>,
        _ pE: some PropertyProtocol<E>,
        _ pF: some PropertyProtocol<F>
    ) -> Property<(Output, A, B, C, D, E, F)> {
        lift { $0.combineLatest(pA, pB, pC, pD, pE, pF) }
    }

    @_disfavoredOverload
    func combineLatest<A, B, C, D, E, F, G>(
        _ pA: some PropertyProtocol<A>,
        _ pB: some PropertyProtocol<B>,
        _ pC: some PropertyProtocol<C>,
        _ pD: some PropertyProtocol<D>,
        _ pE: some PropertyProtocol<E>,
        _ pF: some PropertyProtocol<F>,
        _ pG: some PropertyProtocol<G>
    ) -> Property<(Output, A, B, C, D, E, F, G)> {
        lift { $0.combineLatest(pA, pB, pC, pD, pE, pF, pG) }
    }

    @_disfavoredOverload
    func combineLatest<A, B, C, D, E, F, G, H>(
        _ pA: some PropertyProtocol<A>,
        _ pB: some PropertyProtocol<B>,
        _ pC: some PropertyProtocol<C>,
        _ pD: some PropertyProtocol<D>,
        _ pE: some PropertyProtocol<E>,
        _ pF: some PropertyProtocol<F>,
        _ pG: some PropertyProtocol<G>,
        _ pH: some PropertyProtocol<H>
    ) -> Property<(Output, A, B, C, D, E, F, G, H)> {
        lift { $0.combineLatest(pA, pB, pC, pD, pE, pF, pG, pH) }
    }

    @_disfavoredOverload
    func combineLatest<A, B, C, D, E, F, G, H, I>(
        _ pA: some PropertyProtocol<A>,
        _ pB: some PropertyProtocol<B>,
        _ pC: some PropertyProtocol<C>,
        _ pD: some PropertyProtocol<D>,
        _ pE: some PropertyProtocol<E>,
        _ pF: some PropertyProtocol<F>,
        _ pG: some PropertyProtocol<G>,
        _ pH: some PropertyProtocol<H>,
        _ pI: some PropertyProtocol<I>
    ) -> Property<(Output, A, B, C, D, E, F, G, H, I)> {
        lift { $0.combineLatest(pA, pB, pC, pD, pE, pF, pG, pH, pI) }
    }
}

public extension PropertyProtocol {
    static func combineLatest<A, B>(
        _ pA: some PropertyProtocol<A>,
        _ pB: some PropertyProtocol<B>
    ) -> Property<(A, B)> {
        pA.combineLatest(pB)
    }

    static func combineLatest<A, B, C>(
        _ pA: some PropertyProtocol<A>,
        _ pB: some PropertyProtocol<B>,
        _ pC: some PropertyProtocol<C>
    ) -> Property<(A, B, C)> {
        pA.combineLatest(pB, pC)
    }

    static func combineLatest<A, B, C, D>(
        _ pA: some PropertyProtocol<A>,
        _ pB: some PropertyProtocol<B>,
        _ pC: some PropertyProtocol<C>,
        _ pD: some PropertyProtocol<D>
    ) -> Property<(A, B, C, D)> {
        pA.combineLatest(pB, pC, pD)
    }

    static func combineLatest<A, B, C, D, E>(
        _ pA: some PropertyProtocol<A>,
        _ pB: some PropertyProtocol<B>,
        _ pC: some PropertyProtocol<C>,
        _ pD: some PropertyProtocol<D>,
        _ pE: some PropertyProtocol<E>
    ) -> Property<(A, B, C, D, E)> {
        pA.combineLatest(pB, pC, pD, pE)
    }

    static func combineLatest<A, B, C, D, E, F>(
        _ pA: some PropertyProtocol<A>,
        _ pB: some PropertyProtocol<B>,
        _ pC: some PropertyProtocol<C>,
        _ pD: some PropertyProtocol<D>,
        _ pE: some PropertyProtocol<E>,
        _ pF: some PropertyProtocol<F>
    ) -> Property<(A, B, C, D, E, F)> {
        pA.combineLatest(pB, pC, pD, pE, pF)
    }

    static func combineLatest<A, B, C, D, E, F, G>(
        _ pA: some PropertyProtocol<A>,
        _ pB: some PropertyProtocol<B>,
        _ pC: some PropertyProtocol<C>,
        _ pD: some PropertyProtocol<D>,
        _ pE: some PropertyProtocol<E>,
        _ pF: some PropertyProtocol<F>,
        _ pG: some PropertyProtocol<G>
    ) -> Property<(A, B, C, D, E, F, G)> {
        pA.combineLatest(pB, pC, pD, pE, pF, pG)
    }

    static func combineLatest<A, B, C, D, E, F, G, H>(
        _ pA: some PropertyProtocol<A>,
        _ pB: some PropertyProtocol<B>,
        _ pC: some PropertyProtocol<C>,
        _ pD: some PropertyProtocol<D>,
        _ pE: some PropertyProtocol<E>,
        _ pF: some PropertyProtocol<F>,
        _ pG: some PropertyProtocol<G>,
        _ pH: some PropertyProtocol<H>
    ) -> Property<(A, B, C, D, E, F, G, H)> {
        pA.combineLatest(pB, pC, pD, pE, pF, pG, pH)
    }

    static func combineLatest<A, B, C, D, E, F, G, H, I>(
        _ pA: some PropertyProtocol<A>,
        _ pB: some PropertyProtocol<B>,
        _ pC: some PropertyProtocol<C>,
        _ pD: some PropertyProtocol<D>,
        _ pE: some PropertyProtocol<E>,
        _ pF: some PropertyProtocol<F>,
        _ pG: some PropertyProtocol<G>,
        _ pH: some PropertyProtocol<H>,
        _ pI: some PropertyProtocol<I>
    ) -> Property<(A, B, C, D, E, F, G, H, I)> {
        pA.combineLatest(pB, pC, pD, pE, pF, pG, pH, pI)
    }

    static func combineLatest<A, B, C, D, E, F, G, H, I, J>(
        _ pA: some PropertyProtocol<A>,
        _ pB: some PropertyProtocol<B>,
        _ pC: some PropertyProtocol<C>,
        _ pD: some PropertyProtocol<D>,
        _ pE: some PropertyProtocol<E>,
        _ pF: some PropertyProtocol<F>,
        _ pG: some PropertyProtocol<G>,
        _ pH: some PropertyProtocol<H>,
        _ pI: some PropertyProtocol<I>,
        _ pJ: some PropertyProtocol<J>
    ) -> Property<(A, B, C, D, E, F, G, H, I, J)> {
        pA.combineLatest(pB, pC, pD, pE, pF, pG, pH, pI, pJ)
    }
}
