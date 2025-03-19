//
//  Action.swift
//  Copyright © 2025 Jason Fieldman.
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
    public private(set) lazy var isExecuting: Property<Bool> = .init(mutableIsExecuting.removeDuplicates())
    public private(set) lazy var values: AnyPublisher<Output, Never> = valuesSubject.eraseToAnyPublisher()
    public private(set) lazy var errors: AnyPublisher<Failure, Never> = errorsSubject.eraseToAnyPublisher()

    /// Create a new Action that executes the given builder's Publisher on `apply`.
    public init(builder: @escaping (Input) -> AnyDeferredPublisher<Output, Failure>) {
        self.publisherBuilder = builder
    }

    public func apply(_ input: Input) -> AnyDeferredPublisher<Output, ActionError<Failure>> {
        Deferred { [weak self] in
            guard let self else {
                return AnyDeferredPublisher<Output, ActionError<Failure>>.fail(.disabled)
            }

            var canBegin: Bool = false
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
