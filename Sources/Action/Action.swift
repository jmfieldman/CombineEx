//
//  Action.swift
//  Copyright © 2025 Jason Fieldman.
//

import Combine
import Foundation

public final class Action<Input, Output, Failure: Error> {
    // Private state
    private let publisherBuilder: (Input) -> AnyDeferredPublisher<Output, Failure>
    private let mutableSubscriberCount = MutableProperty(0)
    private let valuesSubject = PassthroughSubject<Output, Never>()
    private let errorsSubject = PassthroughSubject<Failure, Never>()
    private var inFlightSubscription: Subscription?

    // Public state
    public private(set) lazy var isExecuting: Property<Bool> = mutableSubscriberCount.map { $0 > 0 }.removeDuplicates()
    public private(set) lazy var values: AnyPublisher<Output, Never> = valuesSubject.eraseToAnyPublisher()
    public private(set) lazy var errors: AnyPublisher<Failure, Never> = errorsSubject.eraseToAnyPublisher()
    public let isInterruptable: Bool

    /// Create a new Action that executes the given builder's Publisher on `apply`.
    /// If `isInterruptable` is true, successive `apply` calls will cancel any
    /// in-flight producers.
    public init(isInterruptable: Bool = false, builder: @escaping (Input) -> AnyDeferredPublisher<Output, Failure>) {
        self.isInterruptable = isInterruptable
        self.publisherBuilder = builder
    }

    public func apply(_ input: Input) -> AnyDeferredPublisher<Output, ActionError<Failure>> {
        let constructedPublisher = publisherBuilder(input)
            .mapError { ActionError.publisherFailure($0) }
            .eraseToAnyDeferredPublisher()

        return isExecutingCheck()
            .flatMapLatest { _ -> AnyDeferredPublisher<Output, ActionError<Failure>> in constructedPublisher }
            .handleEvents(receiveSubscription: { [weak self] subscription in
                self?.inFlightSubscription = subscription
                self?.mutableSubscriberCount.modify { $0 += 1 }
            }, receiveOutput: { [valuesSubject] value in
                valuesSubject.send(value)
            }, receiveCompletion: { [weak self] completion in
                switch completion {
                case .finished: break
                case let .failure(error):
                    switch error {
                    case .disabled: break
                    case let .publisherFailure(failure): self?.errorsSubject.send(failure)
                    }
                }
                self?.inFlightSubscription = nil
                self?.mutableSubscriberCount.modify { $0 -= 1 }
            }, receiveCancel: { [weak self] in
                self?.inFlightSubscription = nil
                self?.mutableSubscriberCount.modify { $0 -= 1 }
            })
            .eraseToAnyDeferredPublisher()
    }

    /// The same as `apply`, but if the action is in-flight and would return .disabled
    /// this just flatMaps to an 'empty'.  Otherwise it surfaces the internal failure
    /// so you don't need to unbox the ActionError manually.
    ///
    /// This is great for times when you don't care about the .disabled error, like when
    /// your UI element that triggers the action is already disabled while the action
    /// is executing.
    public func applyIfPossible(_ input: Input) -> AnyDeferredPublisher<Output, Failure> {
        apply(input)
            .catch { actionError -> AnyDeferredPublisher<Output, Failure> in
                switch actionError {
                case .disabled: return .empty()
                case let .publisherFailure(failure): return .fail(failure)
                }
            }
            .eraseToAnyDeferredPublisher()
    }

    private func isExecutingCheck() -> AnyDeferredPublisher<Void, ActionError<Failure>> {
        DeferredFuture<Void, ActionError<Failure>> { [weak self] promise in
            guard let self else {
                promise(.failure(.disabled))
                return
            }

            if isInterruptable == true {
                inFlightSubscription?.cancel()
                inFlightSubscription = nil
                promise(.success(()))
            } else {
                promise(isExecuting.value == false ? .success(()) : .failure(.disabled))
            }
        }.eraseToAnyDeferredPublisher()
    }
}

public extension Action {
    static func value<O>(_ value: O) -> Action<Void, O, Never> {
        Action<Void, O, Never> {
            .just(value)
        }
    }

    static func immediate<I, O>(_ block: @escaping (I) -> O) -> Action<I, O, Never> {
        Action<I, O, Never> { input in
            .just(block(input))
        }
    }

    static func immediateResult<I, O, F>(_ block: @escaping (I) -> Result<O, F>) -> Action<I, O, F> {
        Action<I, O, F> { input in
            let result = block(input)
            switch result {
            case let .success(output):
                return .just(output)
            case let .failure(error):
                return .fail(error)
            }
        }
    }
}

public enum ActionError<Failure: Error>: Error {
    case disabled
    case publisherFailure(Failure)
}

// A AnyAction is a convenience container for Actions that do not
// care about the value/failure of the wrapped action. It can be
// used in UI scenarios where you only want UI to trigger an action
// while other side effects are handled elsewhere.
public final class AnyAction<Input> {
    public let isExecuting: Property<Bool>
    public let applyAnonymous: (Input) -> AnyDeferredPublisher<Void, Never>

    public init(_ internalAction: Action<Input, some Any, some Any>) {
        self.isExecuting = internalAction.isExecuting
        self.applyAnonymous = { input in
            internalAction.applyIfPossible(input)
                .demoteFailure()
                .map { _ in () }
                .eraseToAnyDeferredPublisher()
        }
    }

    public static func immediate(_ block: @escaping (Input) -> Void) -> AnyAction<Input> {
        Action<Input, Void, Never>.immediate(block).asAnyAction
    }
}

public extension Action {
    var asAnyAction: AnyAction<Input> {
        AnyAction(self)
    }
}
