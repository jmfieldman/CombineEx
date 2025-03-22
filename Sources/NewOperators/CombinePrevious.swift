//
//  CombinePrevious.swift
//  Copyright © 2025 Jason Fieldman.
//

import Combine

public extension Publisher {
    /// Combines each element with the previous one, returning a tuple of `(previousValue, currentValue)`.
    /// The first element will not have a previous value and is omitted from the output.
    ///
    /// - Returns: A publisher that emits tuples of `(previousValue, currentValue)`.
    func combinePrevious() -> some Publisher<(Output?, Output), Failure> {
        scan((Output?, Output)?.none) { ($0?.1, $1) }
            .compactMap { $0 }
    }

    /// Combines each element with the previous one, using an initial value for the first element's previous value.
    ///
    /// - Parameter initialValue: The initial value to use for the first element's previous value.
    /// - Returns: A publisher that emits tuples of `(previousValue, currentValue)`.
    func combinePrevious(
        _ initialValue: Output
    ) -> some Publisher<(Output, Output), Failure> {
        scan((initialValue, initialValue)) { ($0.1, $1) }
    }

    /// Combines each element with the previous one for optional types, returning a tuple of `(previousValue, currentValue)`.
    /// The first element will not have a previous value and is omitted from the output.
    ///
    /// - Returns: A publisher that emits tuples of `(previousValue, currentValue)`.
    func combinePrevious<T>() -> some Publisher<(Output, Output), Failure> where Output == T? {
        scan((Output, Output)?.none) { ($0?.1, $1) }
            .compactMap { $0 }
    }
}
