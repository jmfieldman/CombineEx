//
//  SinkProviding.swift
//  Copyright © 2025 Jason Fieldman.
//

import Foundation

/// SinkProviding creates syntaxtical short-hand for sinking a publisher into
/// some block of work that only involves a receiving object and the new value.
public protocol SinkProviding: AnyObject {}

extension NSObject: SinkProviding {}

public extension SinkProviding {
    @discardableResult
    func sink<Output, E: Error>(
        _ publisher: some Publisher<Output, E>,
        on scheduler: some Scheduler = UIScheduler.shared,
        receiveValue: ((Self, Output) -> Void)? = nil,
        receiveCompletion: ((Self, Subscribers.Completion<E>) -> Void)? = nil
    ) -> AnyCancellable {
        publisher
            .receive(on: scheduler)
            .sink(
                duringLifetimeOf: self,
                receiveValue: { [weak self] in
                    guard let self else { return }
                    receiveValue?(self, $0)
                },
                receiveCompletion: { [weak self] in
                    guard let self else { return }
                    receiveCompletion?(self, $0)
                }
            )
    }

    @discardableResult
    func sink<Output>(
        _ publisher: some Publisher<Output, Never>,
        on scheduler: some Scheduler = UIScheduler.shared,
        receiveValue: ((Self, Output) -> Void)?
    ) -> AnyCancellable {
        publisher.eraseToAnyPublisher()
            .receive(on: scheduler)
            .sink(
                duringLifetimeOf: self,
                receiveValue: { [weak self] in
                    guard let self else { return }
                    receiveValue?(self, $0)
                }
            )
    }

    @discardableResult
    func sink<E: Error>(
        _ publisher: some Publisher<Void, E>,
        on scheduler: some Scheduler = UIScheduler.shared,
        receiveValue: ((Self) -> Void)?,
        receiveCompletion: ((Self, Subscribers.Completion<E>) -> Void)?
    ) -> AnyCancellable {
        publisher.eraseToAnyPublisher()
            .receive(on: scheduler)
            .sink(
                duringLifetimeOf: self,
                receiveValue: { [weak self] in
                    guard let self else { return }
                    receiveValue?(self)
                }
            )
    }

    @discardableResult
    func sink(
        _ publisher: some Publisher<Void, Never>,
        on scheduler: some Scheduler = UIScheduler.shared,
        receiveValue: ((Self) -> Void)?
    ) -> AnyCancellable {
        publisher.eraseToAnyPublisher()
            .receive(on: scheduler)
            .sink(
                duringLifetimeOf: self,
                receiveValue: { [weak self] in
                    guard let self else { return }
                    receiveValue?(self)
                }
            )
    }
}
