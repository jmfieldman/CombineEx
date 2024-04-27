//
//  PropertyProtocol+Operators.swift
//  Copyright © 2023 Jason Fieldman.
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
