//
//  Action.swift
//  Copyright © 2024 Jason Fieldman.
//

import Combine
import Foundation

public final class Action<Input, Output, Failure: Error> {
    // Private state
    private let publisherBuilder: (Input) -> AnyDeferredPublisher<Output, Failure>
    private let mutableIsExecuting: MutableProperty<Bool> = .init(false)
    private let valuesSubject = PassthroughSubject<Output, Never>()
    private let errorsSubject = PassthroughSubject<Failure, Never>()

    // Public state
    public let isExecuting: Property<Bool>
    public let values: AnyPublisher<Output, Never>
    public let errors: AnyPublisher<Failure, Never>

    /// Create a new Action that executes the given builder's Publisher on `apply`.
    public init(builder: @escaping (Input) -> AnyDeferredPublisher<Output, Failure>) {
        self.publisherBuilder = builder
        self.isExecuting = .init(mutableIsExecuting.removeDuplicates())
        self.values = valuesSubject.eraseToAnyPublisher()
        self.errors = errorsSubject.eraseToAnyPublisher()
    }

    /// Applies the action with the given input and returns a deferred publisher.
    /// Note that no work begins until the publisher is subscribed to.
    ///
    ///  - Parameter input: The input to be used by the action's publisher builder.
    ///  - Returns: A deferred publisher that emits the result of the action or an `ActionError`.
    public func apply(_ input: Input) -> AnyDeferredPublisher<Output, ActionError<Failure>> {
        // Explicitly hold self - The Action will live as long as its applied children.
        Deferred { [self] in
            var canBegin = false
            mutableIsExecuting.modify { isExecuting in
                if !isExecuting {
                    isExecuting = true
                    canBegin = true
                } else {
                    canBegin = false
                }
            }

            if !canBegin {
                return AnyDeferredPublisher<Output, ActionError<Failure>>.fail(.disabled)
            }

            return publisherBuilder(input)
                .mapError { ActionError.publisherFailure($0) }
                .handleEvents(receiveOutput: { [weak self] value in
                    self?.valuesSubject.send(value)
                }, receiveCompletion: { [weak self] completion in
                    switch completion {
                    case .finished: break
                    case let .failure(error):
                        switch error {
                        case .disabled: break
                        case let .publisherFailure(failure): self?.errorsSubject.send(failure)
                        }
                    }
                    self?.mutableIsExecuting.value = false
                }, receiveCancel: { [weak self] in
                    self?.mutableIsExecuting.value = false
                })
                .eraseToAnyDeferredPublisher()

        }.eraseToAnyDeferredPublisher()
    }

    /// Applies the action with the given input, but suppresses `.disabled` errors.
    ///
    ///  If the action is already executing and would return `.disabled`, this method returns an empty publisher instead.
    ///  Otherwise, it surfaces the internal failure directly without needing to unbox `ActionError`.
    ///
    ///  This is useful for UI elements that automatically disable while the action is executing.
    ///
    ///  - Parameter input: The input to be used by the action's publisher builder.
    ///  - Returns: A deferred publisher that emits the result of the action or a direct failure.
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
