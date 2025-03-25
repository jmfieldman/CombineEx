//
//  Aggregation+Publisher.swift
//  Copyright © 2025 Jason Fieldman.
//

import Combine
import Foundation

// MARK: - Combine Latest

// Additional combineLatest implementations that combine the receiver with
// other publishers -- these extend the limit beyond 3

public extension Publisher {
    func combineLatest<A, B, C, D>(
        _ p1: some Publisher<A, Failure>,
        _ p2: some Publisher<B, Failure>,
        _ p3: some Publisher<C, Failure>,
        _ p4: some Publisher<D, Failure>
    ) -> Publishers.Aggregate<(Output, A, B, C, D), Failure> {
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

    func combineLatest<A, B, C, D, E>(
        _ p1: some Publisher<A, Failure>,
        _ p2: some Publisher<B, Failure>,
        _ p3: some Publisher<C, Failure>,
        _ p4: some Publisher<D, Failure>,
        _ p5: some Publisher<E, Failure>
    ) -> Publishers.Aggregate<(Output, A, B, C, D, E), Failure> {
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

    func combineLatest<A, B, C, D, E, F>(
        _ p1: some Publisher<A, Failure>,
        _ p2: some Publisher<B, Failure>,
        _ p3: some Publisher<C, Failure>,
        _ p4: some Publisher<D, Failure>,
        _ p5: some Publisher<E, Failure>,
        _ p6: some Publisher<F, Failure>
    ) -> Publishers.Aggregate<(Output, A, B, C, D, E, F), Failure> {
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

    func combineLatest<A, B, C, D, E, F, G>(
        _ p1: some Publisher<A, Failure>,
        _ p2: some Publisher<B, Failure>,
        _ p3: some Publisher<C, Failure>,
        _ p4: some Publisher<D, Failure>,
        _ p5: some Publisher<E, Failure>,
        _ p6: some Publisher<F, Failure>,
        _ p7: some Publisher<G, Failure>
    ) -> Publishers.Aggregate<(Output, A, B, C, D, E, F, G), Failure> {
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

    func combineLatest<A, B, C, D, E, F, G, H>(
        _ p1: some Publisher<A, Failure>,
        _ p2: some Publisher<B, Failure>,
        _ p3: some Publisher<C, Failure>,
        _ p4: some Publisher<D, Failure>,
        _ p5: some Publisher<E, Failure>,
        _ p6: some Publisher<F, Failure>,
        _ p7: some Publisher<G, Failure>,
        _ p8: some Publisher<H, Failure>
    ) -> Publishers.Aggregate<(Output, A, B, C, D, E, F, G, H), Failure> {
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
    ) -> Publishers.Aggregate<(Output, A, B, C, D, E, F, G, H, I), Failure> {
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

// MARK: - Static Combine Latest

// Additional static combineLatest implementations that combine the arguments
// together into a single publisher, allowing up to 10 combined publishers.

public extension Publisher {
    static func combineLatest<A, B>(
        _ p1: some Publisher<A, Failure>,
        _ p2: some Publisher<B, Failure>
    ) -> Publishers.Aggregate<(A, B), Failure> {
        Publishers.Aggregate<(A, B), Failure>(
            strategy: .combineLatest)
        {
            $0.add(p1)
            $0.add(p2)
        } aggregationBlock: {
            ($0[0] as! A, $0[1] as! B)
        }
    }

    static func combineLatest<A, B, C>(
        _ p1: some Publisher<A, Failure>,
        _ p2: some Publisher<B, Failure>,
        _ p3: some Publisher<C, Failure>
    ) -> Publishers.Aggregate<(A, B, C), Failure> {
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

    static func combineLatest<A, B, C, D>(
        _ p1: some Publisher<A, Failure>,
        _ p2: some Publisher<B, Failure>,
        _ p3: some Publisher<C, Failure>,
        _ p4: some Publisher<D, Failure>
    ) -> Publishers.Aggregate<(A, B, C, D), Failure> {
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

    static func combineLatest<A, B, C, D, E>(
        _ p1: some Publisher<A, Failure>,
        _ p2: some Publisher<B, Failure>,
        _ p3: some Publisher<C, Failure>,
        _ p4: some Publisher<D, Failure>,
        _ p5: some Publisher<E, Failure>
    ) -> Publishers.Aggregate<(A, B, C, D, E), Failure> {
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

    static func combineLatest<A, B, C, D, E, F>(
        _ p1: some Publisher<A, Failure>,
        _ p2: some Publisher<B, Failure>,
        _ p3: some Publisher<C, Failure>,
        _ p4: some Publisher<D, Failure>,
        _ p5: some Publisher<E, Failure>,
        _ p6: some Publisher<F, Failure>
    ) -> Publishers.Aggregate<(A, B, C, D, E, F), Failure> {
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

    static func combineLatest<A, B, C, D, E, F, G>(
        _ p1: some Publisher<A, Failure>,
        _ p2: some Publisher<B, Failure>,
        _ p3: some Publisher<C, Failure>,
        _ p4: some Publisher<D, Failure>,
        _ p5: some Publisher<E, Failure>,
        _ p6: some Publisher<F, Failure>,
        _ p7: some Publisher<G, Failure>
    ) -> Publishers.Aggregate<(A, B, C, D, E, F, G), Failure> {
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

    static func combineLatest<A, B, C, D, E, F, G, H>(
        _ p1: some Publisher<A, Failure>,
        _ p2: some Publisher<B, Failure>,
        _ p3: some Publisher<C, Failure>,
        _ p4: some Publisher<D, Failure>,
        _ p5: some Publisher<E, Failure>,
        _ p6: some Publisher<F, Failure>,
        _ p7: some Publisher<G, Failure>,
        _ p8: some Publisher<H, Failure>
    ) -> Publishers.Aggregate<(A, B, C, D, E, F, G, H), Failure> {
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
    ) -> Publishers.Aggregate<(A, B, C, D, E, F, G, H, I), Failure> {
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
    ) -> Publishers.Aggregate<(A, B, C, D, E, F, G, H, I, J), Failure> {
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

// MARK: - Zip

public extension Publisher {
    func zip<A, B, C, D>(
        _ p1: some Publisher<A, Failure>,
        _ p2: some Publisher<B, Failure>,
        _ p3: some Publisher<C, Failure>,
        _ p4: some Publisher<D, Failure>
    ) -> Publishers.Aggregate<(Output, A, B, C, D), Failure> {
        Publishers.Aggregate<(Output, A, B, C, D), Failure>(
            strategy: .zip)
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

    func zip<A, B, C, D, E>(
        _ p1: some Publisher<A, Failure>,
        _ p2: some Publisher<B, Failure>,
        _ p3: some Publisher<C, Failure>,
        _ p4: some Publisher<D, Failure>,
        _ p5: some Publisher<E, Failure>
    ) -> Publishers.Aggregate<(Output, A, B, C, D, E), Failure> {
        Publishers.Aggregate<(Output, A, B, C, D, E), Failure>(
            strategy: .zip)
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

    func zip<A, B, C, D, E, F>(
        _ p1: some Publisher<A, Failure>,
        _ p2: some Publisher<B, Failure>,
        _ p3: some Publisher<C, Failure>,
        _ p4: some Publisher<D, Failure>,
        _ p5: some Publisher<E, Failure>,
        _ p6: some Publisher<F, Failure>
    ) -> Publishers.Aggregate<(Output, A, B, C, D, E, F), Failure> {
        Publishers.Aggregate<(Output, A, B, C, D, E, F), Failure>(
            strategy: .zip)
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

    func zip<A, B, C, D, E, F, G>(
        _ p1: some Publisher<A, Failure>,
        _ p2: some Publisher<B, Failure>,
        _ p3: some Publisher<C, Failure>,
        _ p4: some Publisher<D, Failure>,
        _ p5: some Publisher<E, Failure>,
        _ p6: some Publisher<F, Failure>,
        _ p7: some Publisher<G, Failure>
    ) -> Publishers.Aggregate<(Output, A, B, C, D, E, F, G), Failure> {
        Publishers.Aggregate<(Output, A, B, C, D, E, F, G), Failure>(
            strategy: .zip)
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

    func zip<A, B, C, D, E, F, G, H>(
        _ p1: some Publisher<A, Failure>,
        _ p2: some Publisher<B, Failure>,
        _ p3: some Publisher<C, Failure>,
        _ p4: some Publisher<D, Failure>,
        _ p5: some Publisher<E, Failure>,
        _ p6: some Publisher<F, Failure>,
        _ p7: some Publisher<G, Failure>,
        _ p8: some Publisher<H, Failure>
    ) -> Publishers.Aggregate<(Output, A, B, C, D, E, F, G, H), Failure> {
        Publishers.Aggregate<(Output, A, B, C, D, E, F, G, H), Failure>(
            strategy: .zip)
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

    func zip<A, B, C, D, E, F, G, H, I>(
        _ p1: some Publisher<A, Failure>,
        _ p2: some Publisher<B, Failure>,
        _ p3: some Publisher<C, Failure>,
        _ p4: some Publisher<D, Failure>,
        _ p5: some Publisher<E, Failure>,
        _ p6: some Publisher<F, Failure>,
        _ p7: some Publisher<G, Failure>,
        _ p8: some Publisher<H, Failure>,
        _ p9: some Publisher<I, Failure>
    ) -> Publishers.Aggregate<(Output, A, B, C, D, E, F, G, H, I), Failure> {
        Publishers.Aggregate<(Output, A, B, C, D, E, F, G, H, I), Failure>(
            strategy: .zip)
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
