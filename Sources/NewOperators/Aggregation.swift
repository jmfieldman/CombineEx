//
//  Aggregation.swift
//  Copyright © 2024 Jason Fieldman.
//

import Combine
import Foundation

public protocol AggregatePublisherAggregator<AggregateFailure> {
  associatedtype AggregateFailure: Error
  func add(_ publisher: some Publisher<some Any, AggregateFailure>)
}

public extension Publishers {
  struct Aggregate<Output, Failure: Error>: Publisher {
    public enum Strategy {
      case combineLatest
      case zip
    }

    let strategy: Strategy
    let componentBuilder: (any AggregatePublisherAggregator<Failure>) -> Void
    let aggregationBlock: ([Any]) -> Output

    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
      let subscription = AggregateSubscription(
        subscriber: subscriber,
        strategy: strategy,
        componentBuilder: componentBuilder,
        aggregationBlock: aggregationBlock
      )
      subscriber.receive(subscription: subscription)
      subscription.start()
    }

    public final class AggregateSubscription<S: Subscriber>: Subscription, AggregatePublisherAggregator where S.Input == Output, S.Failure == Failure {
      public typealias AggregateFailure = Failure
      public typealias Input = Output

      var subscriber: S?
      var isCancelled = false
      var demand: Subscribers.Demand = .unlimited

      let strategy: Strategy
      let componentBuilder: (AggregateSubscription) -> Void
      let aggregationBlock: ([Any]) -> Output

      var lock = NSLock()
      var startBlocks: [() -> Void] = []
      var values: ContiguousArray<[Any]> = []
      var finished: ContiguousArray<Bool> = []
      var countWithValues = 0
      var cancellables: [AnyCancellable] = []

      init(
        subscriber: S,
        strategy: Strategy,
        componentBuilder: @escaping (AggregateSubscription) -> Void,
        aggregationBlock: @escaping ([Any]) -> Output
      ) {
        self.subscriber = subscriber
        self.strategy = strategy
        self.componentBuilder = componentBuilder
        self.aggregationBlock = aggregationBlock

        componentBuilder(self)
        self.values = ContiguousArray(repeating: [], count: startBlocks.count)
        self.finished = ContiguousArray(repeating: false, count: startBlocks.count)
      }

      public func request(_ demand: Subscribers.Demand) {
        lock.withLock {
          self.demand = demand
        }
      }

      public func cancel() {
        subscriber = nil
        isCancelled = true
        cancellables = []
      }

      public func add(_ publisher: some Publisher<some Any, Failure>) {
        let index = startBlocks.count
        startBlocks.append { [weak self] in
          self?.attach(publisher, index: index)
        }
      }

      private func attach(_ publisher: some Publisher<some Any, Failure>, index: Int) {
        publisher.sink { [weak self] completion in
          switch completion {
          case .finished:
            self?.onFinish(index: index)
          case let .failure(error):
            self?.onError(index: index, error: error)
          }
        } receiveValue: { [weak self] value in
          self?.onValue(index: index, value: value)
        }.store(in: &cancellables)
      }

      fileprivate func start() {
        startBlocks.forEach { $0() }
      }

      private func onValue(index: Int, value: some Any) {
        lock.withLock {
          if values[index].isEmpty {
            countWithValues += 1
            values[index].append(value)
          } else {
            switch strategy {
            case .combineLatest:
              values[index][0] = value
            case .zip:
              values[index].append(value)
            }
          }

          // Emit next value if possible
          guard let subscriber, countWithValues == values.count, demand > 0, !isCancelled else { return }

          let nextValue = aggregationBlock(values.compactMap(\.first))
          switch strategy {
          case .combineLatest:
            break
          case .zip:
            for i in 0 ..< values.count {
              values[i].removeFirst()
              if values[i].isEmpty {
                countWithValues -= 1
              }
            }
          }
          _ = subscriber.receive(nextValue)
        }
      }

      private func onError(index: Int, error: Failure) {
        lock.withLock {
          subscriber?.receive(completion: .failure(error))
          cancel()
        }
      }

      private func onFinish(index: Int) {
        lock.withLock {
          finished[index] = true
          guard let subscriber else { return }

          switch strategy {
          case .combineLatest:
            // For combineLatest, we propogate the finish only when all
            // upstream publishers have finished (or if one has finished
            // without emitting a value)
            if values[index].isEmpty || finished.allSatisfy({ $0 }) {
              subscriber.receive(completion: .finished)
              cancel()
            }
          case .zip:
            // For zip, we propogate the finish only if any finished
            // publisher has zero elements (otherwise it can still drain)
            if values[index].isEmpty {
              subscriber.receive(completion: .finished)
              cancel()
            }
          }
        }
      }
    }
  }
}

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
