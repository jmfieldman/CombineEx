//
//  CombinePrevious.swift
//  Copyright © 2025 Jason Fieldman.
//

import Combine

public extension Publisher {
    func combinePrevious() -> some Publisher<(Output?, Output), Failure> {
        scan((Output?, Output)?.none) { ($0?.1, $1) }
            .compactMap { $0 }
    }

    func combinePrevious(
        _ initialValue: Output
    ) -> some Publisher<(Output, Output), Failure> {
        scan((initialValue, initialValue)) { ($0.1, $1) }
    }

    func combinePrevious<T>() -> some Publisher<(Output, Output), Failure> where Output == T? {
        scan((Output, Output)?.none) { ($0?.1, $1) }
            .compactMap { $0 }
    }
}
