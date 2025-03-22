//
//  UIProperty.swift
//  Copyright © 2025 Jason Fieldman.
//

import Combine
import Foundation
import SwiftUI

@Observable
public final class UIProperty<Output> {
    public typealias Failure = Never

    public var value: Output
    @ObservationIgnored private var cancellable: AnyCancellable? = nil
    @ObservationIgnored private var captured: any Publisher<Output, Never>

    public init<P: PropertyProtocol>(_ capturing: P) where P.Output == Output {
        self.captured = capturing
        self.value = capturing.value
        self.cancellable = capturing
            .receiveOnMain()
            .sink(receiveValue: { [weak self] value in
                self?.update(value)
            })
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
