//
//  DeferredFutureProtocol+Operators.swift
//  Copyright © 2023 Jason Fieldman.
//

import Combine

public protocol PropertyProtocol: AnyObject, Publisher where Failure == Never {
  var value: Output { get }
}

//public class Property<Value>: PropertyProtocol {
//  public typealias Output = Value
//  public typealias Failure = Never
//
//  
//}
