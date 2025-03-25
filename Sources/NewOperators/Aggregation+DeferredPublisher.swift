//
//  Aggregation+DeferredPublisher.swift
//  Copyright © 2025 Jason Fieldman.
//

import Combine

// MARK: - Combine Latest

public extension DeferredPublisherProtocol {
    @_disfavoredOverload
    func combineLatest<A>(
        _ p1: some Publisher<A, Failure>
    ) -> Deferred<Publishers.Aggregate<(Output, A), Failure>> {
        Deferred {
            Publishers.Aggregate<(Output, A), Failure>(
                strategy: .combineLatest)
            {
                $0.add(self)
                $0.add(p1)
            } aggregationBlock: {
                ($0[0] as! Output, $0[1] as! A)
            }
        }
    }

    @_disfavoredOverload
    func combineLatest<A, NewOutput>(
        _ p1: some Publisher<A, Failure>,
        _ transform: @escaping (Output, A) -> NewOutput
    ) -> Deferred<Publishers.Aggregate<NewOutput, Failure>> {
        Deferred {
            Publishers.Aggregate<NewOutput, Failure>(
                strategy: .combineLatest)
            {
                $0.add(self)
                $0.add(p1)
            } aggregationBlock: {
                transform($0[0] as! Output, $0[1] as! A)
            }
        }
    }

    @_disfavoredOverload
    func combineLatest<A, B>(
        _ p1: some Publisher<A, Failure>,
        _ p2: some Publisher<B, Failure>
    ) -> Deferred<Publishers.Aggregate<(Output, A, B), Failure>> {
        Deferred {
            Publishers.Aggregate<(Output, A, B), Failure>(
                strategy: .combineLatest)
            {
                $0.add(self)
                $0.add(p1)
                $0.add(p2)
            } aggregationBlock: {
                ($0[0] as! Output, $0[1] as! A, $0[2] as! B)
            }
        }
    }

    @_disfavoredOverload
    func combineLatest<A, B, NewOutput>(
        _ p1: some Publisher<A, Failure>,
        _ p2: some Publisher<B, Failure>,
        _ transform: @escaping (Output, A, B) -> NewOutput
    ) -> Deferred<Publishers.Aggregate<NewOutput, Failure>> {
        Deferred {
            Publishers.Aggregate<NewOutput, Failure>(
                strategy: .combineLatest)
            {
                $0.add(self)
                $0.add(p1)
                $0.add(p2)
            } aggregationBlock: {
                transform($0[0] as! Output, $0[1] as! A, $0[2] as! B)
            }
        }
    }

    @_disfavoredOverload
    func combineLatest<A, B, C>(
        _ p1: some Publisher<A, Failure>,
        _ p2: some Publisher<B, Failure>,
        _ p3: some Publisher<C, Failure>
    ) -> Deferred<Publishers.Aggregate<(Output, A, B, C), Failure>> {
        Deferred {
            Publishers.Aggregate<(Output, A, B, C), Failure>(
                strategy: .combineLatest)
            {
                $0.add(self)
                $0.add(p1)
                $0.add(p2)
                $0.add(p3)
            } aggregationBlock: {
                ($0[0] as! Output, $0[1] as! A, $0[2] as! B, $0[3] as! C)
            }
        }
    }

    @_disfavoredOverload
    func combineLatest<A, B, C, NewOutput>(
        _ p1: some Publisher<A, Failure>,
        _ p2: some Publisher<B, Failure>,
        _ p3: some Publisher<C, Failure>,
        _ transform: @escaping (Output, A, B, C) -> NewOutput
    ) -> Deferred<Publishers.Aggregate<NewOutput, Failure>> {
        Deferred {
            Publishers.Aggregate<NewOutput, Failure>(
                strategy: .combineLatest)
            {
                $0.add(self)
                $0.add(p1)
                $0.add(p2)
                $0.add(p3)
            } aggregationBlock: {
                transform($0[0] as! Output, $0[1] as! A, $0[2] as! B, $0[3] as! C)
            }
        }
    }

    @_disfavoredOverload
    func combineLatest<A, B, C, D>(
        _ p1: some Publisher<A, Failure>,
        _ p2: some Publisher<B, Failure>,
        _ p3: some Publisher<C, Failure>,
        _ p4: some Publisher<D, Failure>
    ) -> Deferred<Publishers.Aggregate<(Output, A, B, C, D), Failure>> {
        Deferred {
            Publishers.Aggregate<(Output, A, B, C, D), Failure>(
                strategy: .combineLatest)
            {
                $0.add(self)
                $0.add(p1)
                $0.add(p2)
                $0.add(p3)
                $0.add(p4)
            } aggregationBlock: {
                ($0[0] as! Output, $0[1] as! A, $0[2] as! B, $0[3] as! C, $0[4] as! D)
            }
        }
    }

    @_disfavoredOverload
    func combineLatest<A, B, C, D, E>(
        _ p1: some Publisher<A, Failure>,
        _ p2: some Publisher<B, Failure>,
        _ p3: some Publisher<C, Failure>,
        _ p4: some Publisher<D, Failure>,
        _ p5: some Publisher<E, Failure>
    ) -> Deferred<Publishers.Aggregate<(Output, A, B, C, D, E), Failure>> {
        Deferred {
            Publishers.Aggregate<(Output, A, B, C, D, E), Failure>(
                strategy: .combineLatest)
            {
                $0.add(self)
                $0.add(p1)
                $0.add(p2)
                $0.add(p3)
                $0.add(p4)
                $0.add(p5)
            } aggregationBlock: {
                ($0[0] as! Output, $0[1] as! A, $0[2] as! B, $0[3] as! C, $0[4] as! D, $0[5] as! E)
            }
        }
    }

    @_disfavoredOverload
    func combineLatest<A, B, C, D, E, F>(
        _ p1: some Publisher<A, Failure>,
        _ p2: some Publisher<B, Failure>,
        _ p3: some Publisher<C, Failure>,
        _ p4: some Publisher<D, Failure>,
        _ p5: some Publisher<E, Failure>,
        _ p6: some Publisher<F, Failure>
    ) -> Deferred<Publishers.Aggregate<(Output, A, B, C, D, E, F), Failure>> {
        Deferred {
            Publishers.Aggregate<(Output, A, B, C, D, E, F), Failure>(
                strategy: .combineLatest)
            {
                $0.add(self)
                $0.add(p1)
                $0.add(p2)
                $0.add(p3)
                $0.add(p4)
                $0.add(p5)
                $0.add(p6)
            } aggregationBlock: {
                ($0[0] as! Output, $0[1] as! A, $0[2] as! B, $0[3] as! C, $0[4] as! D, $0[5] as! E, $0[6] as! F)
            }
        }
    }

    @_disfavoredOverload
    func combineLatest<A, B, C, D, E, F, G>(
        _ p1: some Publisher<A, Failure>,
        _ p2: some Publisher<B, Failure>,
        _ p3: some Publisher<C, Failure>,
        _ p4: some Publisher<D, Failure>,
        _ p5: some Publisher<E, Failure>,
        _ p6: some Publisher<F, Failure>,
        _ p7: some Publisher<G, Failure>
    ) -> Deferred<Publishers.Aggregate<(Output, A, B, C, D, E, F, G), Failure>> {
        Deferred {
            Publishers.Aggregate<(Output, A, B, C, D, E, F, G), Failure>(
                strategy: .combineLatest)
            {
                $0.add(self)
                $0.add(p1)
                $0.add(p2)
                $0.add(p3)
                $0.add(p4)
                $0.add(p5)
                $0.add(p6)
                $0.add(p7)
            } aggregationBlock: {
                ($0[0] as! Output, $0[1] as! A, $0[2] as! B, $0[3] as! C, $0[4] as! D, $0[5] as! E, $0[6] as! F, $0[7] as! G)
            }
        }
    }

    @_disfavoredOverload
    func combineLatest<A, B, C, D, E, F, G, H>(
        _ p1: some Publisher<A, Failure>,
        _ p2: some Publisher<B, Failure>,
        _ p3: some Publisher<C, Failure>,
        _ p4: some Publisher<D, Failure>,
        _ p5: some Publisher<E, Failure>,
        _ p6: some Publisher<F, Failure>,
        _ p7: some Publisher<G, Failure>,
        _ p8: some Publisher<H, Failure>
    ) -> Deferred<Publishers.Aggregate<(Output, A, B, C, D, E, F, G, H), Failure>> {
        Deferred {
            Publishers.Aggregate<(Output, A, B, C, D, E, F, G, H), Failure>(
                strategy: .combineLatest)
            {
                $0.add(self)
                $0.add(p1)
                $0.add(p2)
                $0.add(p3)
                $0.add(p4)
                $0.add(p5)
                $0.add(p6)
                $0.add(p7)
                $0.add(p8)
            } aggregationBlock: {
                ($0[0] as! Output, $0[1] as! A, $0[2] as! B, $0[3] as! C, $0[4] as! D, $0[5] as! E, $0[6] as! F, $0[7] as! G, $0[8] as! H)
            }
        }
    }

    @_disfavoredOverload
    func combineLatest<A, B, C, D, E, F, G, H, I>(
        _ p1: some Publisher<A, Failure>,
        _ p2: some Publisher<B, Failure>,
        _ p3: some Publisher<C, Failure>,
        _ p4: some Publisher<D, Failure>,
        _ p5: some Publisher<E, Failure>,
        _ p6: some Publisher<F, Failure>,
        _ p7: some Publisher<G, Failure>,
        _ p8: some Publisher<H, Failure>,
        _ p9: some Publisher<I, Failure>
    ) -> Deferred<Publishers.Aggregate<(Output, A, B, C, D, E, F, G, H, I), Failure>> {
        Deferred {
            Publishers.Aggregate<(Output, A, B, C, D, E, F, G, H, I), Failure>(
                strategy: .combineLatest)
            {
                $0.add(self)
                $0.add(p1)
                $0.add(p2)
                $0.add(p3)
                $0.add(p4)
                $0.add(p5)
                $0.add(p6)
                $0.add(p7)
                $0.add(p8)
                $0.add(p9)
            } aggregationBlock: {
                ($0[0] as! Output, $0[1] as! A, $0[2] as! B, $0[3] as! C, $0[4] as! D, $0[5] as! E, $0[6] as! F, $0[7] as! G, $0[8] as! H, $0[9] as! I)
            }
        }
    }
}

// MARK: - Static Combine Latest

public extension DeferredPublisherProtocol {
    @_disfavoredOverload
    static func combineLatest<A, B>(
        _ p1: some Publisher<A, Failure>,
        _ p2: some Publisher<B, Failure>
    ) -> Deferred<Publishers.Aggregate<(A, B), Failure>> {
        Deferred {
            Publishers.Aggregate<(A, B), Failure>(
                strategy: .combineLatest)
            {
                $0.add(p1)
                $0.add(p2)
            } aggregationBlock: {
                ($0[0] as! A, $0[1] as! B)
            }
        }
    }

    @_disfavoredOverload
    static func combineLatest<A, B, C>(
        _ p1: some Publisher<A, Failure>,
        _ p2: some Publisher<B, Failure>,
        _ p3: some Publisher<C, Failure>
    ) -> Deferred<Publishers.Aggregate<(A, B, C), Failure>> {
        Deferred {
            Publishers.Aggregate<(A, B, C), Failure>(
                strategy: .combineLatest)
            {
                $0.add(p1)
                $0.add(p2)
                $0.add(p3)
            } aggregationBlock: {
                ($0[0] as! A, $0[1] as! B, $0[2] as! C)
            }
        }
    }

    @_disfavoredOverload
    static func combineLatest<A, B, C, D>(
        _ p1: some Publisher<A, Failure>,
        _ p2: some Publisher<B, Failure>,
        _ p3: some Publisher<C, Failure>,
        _ p4: some Publisher<D, Failure>
    ) -> Deferred<Publishers.Aggregate<(A, B, C, D), Failure>> {
        Deferred {
            Publishers.Aggregate<(A, B, C, D), Failure>(
                strategy: .combineLatest)
            {
                $0.add(p1)
                $0.add(p2)
                $0.add(p3)
                $0.add(p4)
            } aggregationBlock: {
                ($0[0] as! A, $0[1] as! B, $0[2] as! C, $0[3] as! D)
            }
        }
    }

    @_disfavoredOverload
    static func combineLatest<A, B, C, D, E>(
        _ p1: some Publisher<A, Failure>,
        _ p2: some Publisher<B, Failure>,
        _ p3: some Publisher<C, Failure>,
        _ p4: some Publisher<D, Failure>,
        _ p5: some Publisher<E, Failure>
    ) -> Deferred<Publishers.Aggregate<(A, B, C, D, E), Failure>> {
        Deferred {
            Publishers.Aggregate<(A, B, C, D, E), Failure>(
                strategy: .combineLatest)
            {
                $0.add(p1)
                $0.add(p2)
                $0.add(p3)
                $0.add(p4)
                $0.add(p5)
            } aggregationBlock: {
                ($0[0] as! A, $0[1] as! B, $0[2] as! C, $0[3] as! D, $0[4] as! E)
            }
        }
    }

    @_disfavoredOverload
    static func combineLatest<A, B, C, D, E, F>(
        _ p1: some Publisher<A, Failure>,
        _ p2: some Publisher<B, Failure>,
        _ p3: some Publisher<C, Failure>,
        _ p4: some Publisher<D, Failure>,
        _ p5: some Publisher<E, Failure>,
        _ p6: some Publisher<F, Failure>
    ) -> Deferred<Publishers.Aggregate<(A, B, C, D, E, F), Failure>> {
        Deferred {
            Publishers.Aggregate<(A, B, C, D, E, F), Failure>(
                strategy: .combineLatest)
            {
                $0.add(p1)
                $0.add(p2)
                $0.add(p3)
                $0.add(p4)
                $0.add(p5)
                $0.add(p6)
            } aggregationBlock: {
                ($0[0] as! A, $0[1] as! B, $0[2] as! C, $0[3] as! D, $0[4] as! E, $0[5] as! F)
            }
        }
    }

    @_disfavoredOverload
    static func combineLatest<A, B, C, D, E, F, G>(
        _ p1: some Publisher<A, Failure>,
        _ p2: some Publisher<B, Failure>,
        _ p3: some Publisher<C, Failure>,
        _ p4: some Publisher<D, Failure>,
        _ p5: some Publisher<E, Failure>,
        _ p6: some Publisher<F, Failure>,
        _ p7: some Publisher<G, Failure>
    ) -> Deferred<Publishers.Aggregate<(A, B, C, D, E, F, G), Failure>> {
        Deferred {
            Publishers.Aggregate<(A, B, C, D, E, F, G), Failure>(
                strategy: .combineLatest)
            {
                $0.add(p1)
                $0.add(p2)
                $0.add(p3)
                $0.add(p4)
                $0.add(p5)
                $0.add(p6)
                $0.add(p7)
            } aggregationBlock: {
                ($0[0] as! A, $0[1] as! B, $0[2] as! C, $0[3] as! D, $0[4] as! E, $0[5] as! F, $0[6] as! G)
            }
        }
    }

    @_disfavoredOverload
    static func combineLatest<A, B, C, D, E, F, G, H>(
        _ p1: some Publisher<A, Failure>,
        _ p2: some Publisher<B, Failure>,
        _ p3: some Publisher<C, Failure>,
        _ p4: some Publisher<D, Failure>,
        _ p5: some Publisher<E, Failure>,
        _ p6: some Publisher<F, Failure>,
        _ p7: some Publisher<G, Failure>,
        _ p8: some Publisher<H, Failure>
    ) -> Deferred<Publishers.Aggregate<(A, B, C, D, E, F, G, H), Failure>> {
        Deferred {
            Publishers.Aggregate<(A, B, C, D, E, F, G, H), Failure>(
                strategy: .combineLatest)
            {
                $0.add(p1)
                $0.add(p2)
                $0.add(p3)
                $0.add(p4)
                $0.add(p5)
                $0.add(p6)
                $0.add(p7)
                $0.add(p8)
            } aggregationBlock: {
                ($0[0] as! A, $0[1] as! B, $0[2] as! C, $0[3] as! D, $0[4] as! E, $0[5] as! F, $0[6] as! G, $0[7] as! H)
            }
        }
    }

    @_disfavoredOverload
    static func combineLatest<A, B, C, D, E, F, G, H, I>(
        _ p1: some Publisher<A, Failure>,
        _ p2: some Publisher<B, Failure>,
        _ p3: some Publisher<C, Failure>,
        _ p4: some Publisher<D, Failure>,
        _ p5: some Publisher<E, Failure>,
        _ p6: some Publisher<F, Failure>,
        _ p7: some Publisher<G, Failure>,
        _ p8: some Publisher<H, Failure>,
        _ p9: some Publisher<I, Failure>
    ) -> Deferred<Publishers.Aggregate<(A, B, C, D, E, F, G, H, I), Failure>> {
        Deferred {
            Publishers.Aggregate<(A, B, C, D, E, F, G, H, I), Failure>(
                strategy: .combineLatest)
            {
                $0.add(p1)
                $0.add(p2)
                $0.add(p3)
                $0.add(p4)
                $0.add(p5)
                $0.add(p6)
                $0.add(p7)
                $0.add(p8)
                $0.add(p9)
            } aggregationBlock: {
                ($0[0] as! A, $0[1] as! B, $0[2] as! C, $0[3] as! D, $0[4] as! E, $0[5] as! F, $0[6] as! G, $0[7] as! H, $0[8] as! I)
            }
        }
    }

    @_disfavoredOverload
    static func combineLatest<A, B, C, D, E, F, G, H, I, J>(
        _ p1: some Publisher<A, Failure>,
        _ p2: some Publisher<B, Failure>,
        _ p3: some Publisher<C, Failure>,
        _ p4: some Publisher<D, Failure>,
        _ p5: some Publisher<E, Failure>,
        _ p6: some Publisher<F, Failure>,
        _ p7: some Publisher<G, Failure>,
        _ p8: some Publisher<H, Failure>,
        _ p9: some Publisher<I, Failure>,
        _ p10: some Publisher<J, Failure>
    ) -> Deferred<Publishers.Aggregate<(A, B, C, D, E, F, G, H, I, J), Failure>> {
        Deferred {
            Publishers.Aggregate<(A, B, C, D, E, F, G, H, I, J), Failure>(
                strategy: .combineLatest)
            {
                $0.add(p1)
                $0.add(p2)
                $0.add(p3)
                $0.add(p4)
                $0.add(p5)
                $0.add(p6)
                $0.add(p7)
                $0.add(p8)
                $0.add(p9)
                $0.add(p10)
            } aggregationBlock: {
                ($0[0] as! A, $0[1] as! B, $0[2] as! C, $0[3] as! D, $0[4] as! E, $0[5] as! F, $0[6] as! G, $0[7] as! H, $0[8] as! I, $0[9] as! J)
            }
        }
    }
}
