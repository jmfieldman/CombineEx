//
//  Action.swift
//  Copyright © 2024 Jason Fieldman.
//

import Combine
import Foundation

public final class Action<Input, Output, Failure: Error>: @unchecked Sendable {
    // Private state
    private let publisherBuilder: (Input) -> AnyDeferredPublisher<Output, Failure>
    private let mutableIsExecuting: MutableProperty<Bool> = .init(false)
    private let valuesSubject = PassthroughSubject<Output, Never>()
    private let errorsSubject = PassthroughSubject<Failure, Never>()

    // Public state
    public let enabled: Property<Bool>
    public let isExecuting: Property<Bool>
    public let values: AnyPublisher<Output, Never>
    public let errors: AnyPublisher<Failure, Never>

    /// Create a new Action that executes the given builder's Publisher on `apply`.
    public init(
        enabledIf: Property<Bool> = .just(true),
        builder: @escaping (Input) -> AnyDeferredPublisher<Output, Failure>
    ) {
        self.publisherBuilder = builder
        self.isExecuting = .init(mutableIsExecuting.removeDuplicates())
        self.values = valuesSubject.eraseToAnyPublisher()
        self.errors = errorsSubject.eraseToAnyPublisher()
        self.enabled = enabledIf
    }

    /// Applies the action with the given input and returns a deferred publisher.
    /// Note that no work begins until the publisher is subscribed to.
    ///
    ///  - Parameter input: The input to be used by the action's publisher builder.
    ///  - Returns: A deferred publisher that emits the result of the action or an `ActionError`.
    public func apply(_ input: Input) -> AnyDeferredPublisher<Output, ActionError<Failure>> {
        // Explicitly hold self - The Action will live as long as its applied children.
        Deferred { [self] () -> AnyPublisher<Output, ActionError<Failure>> in
            var canBegin = false
            mutableIsExecuting.modify { isExecuting in
                if !isExecuting, enabled.value {
                    isExecuting = true
                    canBegin = true
                } else {
                    canBegin = false
                }
            }

            if !canBegin {
                return .fail(.disabled)
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
                .eraseToAnyPublisher()

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

    /// Convenience method to allow parameter-less application for Actions with Void input.
    public func apply() -> AnyDeferredPublisher<Output, ActionError<Failure>> where Input == Void {
        apply(())
    }

    /// Convenience method to allow parameter-less application for Actions with Void input.
    public func applyIfPossible() -> AnyDeferredPublisher<Output, Failure> where Input == Void {
        applyIfPossible(())
    }
}

public extension Action {
    static func just<O>(
        enabledIf: Property<Bool> = .just(true),
        _ value: O
    ) -> Action<Void, O, Never> {
        Action<Void, O, Never>(enabledIf: enabledIf) {
            .just(value)
        }
    }

    static func immediate<I, O>(
        enabledIf: Property<Bool> = .just(true),
        _ block: @escaping (I) -> O
    ) -> Action<I, O, Never> {
        Action<I, O, Never>(enabledIf: enabledIf) { input in
            .just(block(input))
        }
    }

    static func immediateOnMainActor<I, O>(
        enabledIf: Property<Bool> = .just(true),
        _ block: @MainActor @escaping (I) -> O
    ) -> Action<I, O, Never> {
        Action<I, O, Never>(enabledIf: enabledIf) { input in
            AnyDeferredFuture<O, Never> { promise in
                DispatchQueue.main.async {
                    promise(.success(block(input)))
                }
            }.eraseToAnyDeferredPublisher()
        }
    }

    static func immediateResult<I, O, F>(
        enabledIf: Property<Bool> = .just(true),
        _ block: @escaping (I) -> Result<O, F>
    ) -> Action<I, O, F> {
        Action<I, O, F>(enabledIf: enabledIf) { input in
            let result = block(input)
            switch result {
            case let .success(output):
                return .just(output)
            case let .failure(error):
                return .fail(error)
            }
        }
    }

    static func withTask<I, O>(
        enabledIf: Property<Bool> = .just(true),
        _ task: @escaping (I) async -> O
    ) -> Action<I, O, Never> {
        Action<I, O, Never>(enabledIf: enabledIf) { input in
            DeferredFuture.withTask {
                await task(input)
            }.eraseToAnyDeferredPublisher()
        }
    }

    static func withThrowingTask<I, O, F>(
        enabledIf: Property<Bool> = .just(true),
        _ task: @escaping (I) async throws(F) -> O
    ) -> Action<I, O, F> {
        Action<I, O, F>(enabledIf: enabledIf) { input in
            DeferredFuture<O, F>.withTask { () throws(F) in
                try await task(input)
            }.eraseToAnyDeferredPublisher()
        }
    }

    static func withThrowingTask<I, O, F>(
        enabledIf: Property<Bool> = .just(true),
        nonconformingErrorHandler: @escaping (Error) -> F,
        task: @escaping (I) async throws -> O
    ) -> Action<I, O, F> {
        Action<I, O, F>(enabledIf: enabledIf) { input in
            DeferredFuture<O, F>.withTask(
                nonconformingErrorHandler: nonconformingErrorHandler
            ) { () throws in
                try await task(input)
            }.eraseToAnyDeferredPublisher()
        }
    }
}

public enum ActionError<Failure: Error>: Error {
    case disabled
    case publisherFailure(Failure)
}
