//
//  Aggregation.swift
//  Copyright © 2023 Jason Fieldman.
//

import Combine
import Foundation

public protocol AggregationComponentIngesting: Subscription {
  associatedtype Failure: Error
  func add<T>(_ publisher: () -> some Publisher<T, Failure>)
}

private protocol AggregationStartable: Subscription {
  func start()
}

public extension Publishers {
  struct Aggregate<Output, Failure: Error>: Publisher {
    public enum Strategy {
      case combineLatest
      case zip
    }

    let strategy: Strategy
    let componentBuilder: (any AggregationComponentIngesting) -> Void
    let aggregationBlock: (ContiguousArray<Any>) -> Output

    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
      let subscription: AggregationStartable = switch strategy {
      case .combineLatest:
        CombineLatestSubscription(
          subscriber: subscriber,
          strategy: strategy,
          componentBuilder: componentBuilder,
          aggregationBlock: aggregationBlock
        )
      case .zip:
        fatalError("unimplemented")
      }
      subscriber.receive(subscription: subscription)
      subscription.start()
    }

    private final class CombineLatestSubscription<S: Subscriber>: Subscription, AggregationStartable, AggregationComponentIngesting where S.Input == Output {
      typealias Failure = S.Failure
      typealias Input = Output

      var subscriber: S?
      var isCancelled = false
      var demand: Subscribers.Demand = .unlimited

      let strategy: Strategy
      let componentBuilder: (any AggregationComponentIngesting) -> Void
      let aggregationBlock: (ContiguousArray<Any>) -> Output

      var lock = NSLock()
      var startBlocks: [() -> Void] = []
      var subscribers: [any Subscriber] = []
      var values: ContiguousArray<Any> = []
      var finished: ContiguousArray<Bool> = []

      init(
        subscriber: S,
        strategy: Strategy,
        componentBuilder: @escaping (any AggregationComponentIngesting) -> Void,
        aggregationBlock: @escaping (ContiguousArray<Any>) -> Output
      ) {
        self.subscriber = subscriber
        self.strategy = strategy
        self.componentBuilder = componentBuilder
        self.aggregationBlock = aggregationBlock

        componentBuilder(self)
        self.values = ContiguousArray(repeating: 0, count: startBlocks.count)
        self.finished = ContiguousArray(repeating: false, count: startBlocks.count)
      }

      func request(_ demand: Subscribers.Demand) {
        lock.withLock {
          self.demand = demand
        }
      }

      func cancel() {
        subscriber = nil
        subscribers = []
        isCancelled = true
      }

      func add(_ publisher: () -> some Publisher<some Any, Failure>) {
        let index = startBlocks.count
        let p = publisher()
        startBlocks.append { [weak self] in
          self?.attach(p, index: index)
        }
      }

      func attach<T>(_ publisher: some Publisher<T, Failure>, index: Int) {
        let subscriber = CombineLatestSubscriptionComponent<T, Failure>(index: index, listener: self)
        subscribers.append(subscriber)
        publisher.subscribe(subscriber)
      }

      func start() {
        startBlocks.forEach { $0() }
      }

      func onValue(index: Int, value: some Any) {
        lock.withLock {
          values[index] = value
          process()
        }
      }

      func onError(index: Int, error: Failure) {
        lock.withLock {
          subscriber?.receive(completion: .failure(error))
          cancel()
        }
      }

      func onFinish(index: Int) {
        lock.withLock {
          finished[index] = true
          process()
        }
      }

      func process() {
        guard let subscriber else { return }

        if finished.allSatisfy({ $0 }) {
          subscriber.receive(completion: .finished)
          cancel()
        }

        if demand > 0, !isCancelled {
          demand = subscriber.receive(aggregationBlock(values))
        }
      }

      /// Subscribes to a single upstream factor
      private final class CombineLatestSubscriptionComponent<T, F>: Subscriber {
        typealias Input = T

        let index: Int
        weak var listener: CombineLatestSubscription?

        init(
          index: Int,
          listener: CombineLatestSubscription
        ) {
          self.index = index
          self.listener = listener
        }

        func receive(subscription: Subscription) {}

        func receive(completion: Subscribers.Completion<Failure>) {
          switch completion {
          case .finished:
            listener?.onFinish(index: index)
          case let .failure(error):
            listener?.onError(index: index, error: error)
          }
        }

        func receive(_ input: T) -> Subscribers.Demand {
          listener?.onValue(index: index, value: input)
          return .unlimited
        }
      }
    }
  }
}

public extension Publisher {}
