//
//  UIProperty.swift
//  Copyright © 2025 Jason Fieldman.
//

import Combine
import Foundation
import SwiftUI

@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
@Observable
public final class UIProperty<Output>: PropertyProtocol {
    public typealias Failure = Never

    public private(set) var value: Output
    @ObservationIgnored private var cancellable: AnyCancellable? = nil
    @ObservationIgnored private var captured: any Publisher<Output, Never>

    public init<P: PropertyProtocol>(_ capturing: P) where P.Output == Output {
        self.captured = capturing

        // Intentially capture current value here so that self can be used
        // in the sink
        self.value = capturing.value
        self.cancellable = capturing
            .dropFirst()
            .receiveOnMain()
            .sink(receiveValue: { [weak self] value in
                self?.update(value)
            })

        // But we need this to capture the true state of the argument
        // in a thread-safe manner since we dropFirst on its publisher.
        // This second update should not be observed as two events since
        // they are both inside the init.
        self.value = capturing.value
    }

    public init(initial: Output, then: some Publisher<Output, Never>) {
        self.captured = then
        self.value = initial
        self.cancellable = then
            .receiveOnMain()
            .sink(receiveValue: { [weak self] value in
                self?.update(value)
            })
    }

    private func update(_ value: Output) {
        self.value = value
    }
}

public extension UIProperty {
    func receive<S>(subscriber: S) where S: Subscriber, Never == S.Failure, Output == S.Input {
        captured.receive(subscriber: subscriber)
    }
}
