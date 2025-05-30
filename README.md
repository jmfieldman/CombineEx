# CombineEx

> CombineEx is still a WIP, and may not be ready for production. I can use your help
> to fill out the complete suite of functionality and tests.

CombineEx is a Swift Combine extension library that fills significant usabliliy gaps:

* Explicit Hot vs. Cold Publisher types
* Explicit Cold Future type
* Property (and MutableProperty) for Failureless CurrentValueSubject with read-only semantics.
* Action support
* UIScheduler
* Quality-of-life Publisher extensions and @Observable integrations

It is heavily influenced by concepts in the amazing [ReactiveSwift](https://github.com/ReactiveCocoa/ReactiveSwift) and [ReactiveCocoa](https://github.com/ReactiveCocoa/ReactiveCocoa) libraries.

## Hot vs Cold

Combine lacks native semantics around hot vs. cold Publisher types. 

If you are unfamiliar with the distinction:

* A *hot publisher* is usually attached to emissions from a shared resource, and the act of subscribing does not typically fire off a new unit of work.
  * An example might be something like `currentLocation` that emits values returned from a `CLLocationManagerDelegate` callback. `currentLocation` might be backed by a `CurrentValueSubject`, and subscribing simply listens to changes in this subject. Multiple subscribers will all receive the same values from the each update.
* A *cold publisher* kicks off a new, distinct unit of work for every subscription, and the emissions of the publisher are unique to that subscription.
  * An example of this is `URLSession.shared.dataTaskPublisher(for: url)` -- each subscription kicks off a distinct call to the URL, and the results of that request are only sent to the subscription that initiated it.

In Combine, when the above use cases are exposed through an API, they are both represented by `AnyPublisher`. This provides no semantic guide to the way that publisher acts when it is subscribed to.

CombineEx is opinionated that `Deferred` is the preferred keyword for *cold publishers*. An API can provide the new erased type `AnyDeferredPublisher` to establish at the API layer that the vended publisher is *cold* and will kick off a distinct stream of values backed by a distinct workstream for each subscription.

In addition, all publisher functions are overloaded for `AnyDeferredPublisher` to return a new `Deferred` Publisher, allowing you to retain the deferred semantics even after you perform publisher operations like `map`, `first`, `filter`, etc.

APIs can continue to vend `AnyPublisher` for hot/ambiguous publishers.

## Future

The Combine `Future` is an interesting Publisher; it is neither hot nor cold. It executes the provided block immediately upon instantiation, without waiting for a subscriber. It then forwards the single result to all subscribers for the remainder of its lifetime.  

This can cause severe ambiguity if a `Future` is provided through an API as an `AnyPublisher`. The caller cannot be sure if the returned `AnyPublisher` will perform new work on each subscription or not.

Instead, CombineEx offers a new `DeferredFuture` struct that unambiguously ensures that each subscription triggers the work inside the `Future` on each subscription. This can be returned through an API by erasing it to `AnyDeferredFuture`.

`DeferredFuture` and `AnyDeferredFuture` only overload operators that make sense for single-value publishers. If you'd like to use other operators, you can use `eraseToAnyDeferredPublisher` to switch
to multi-value publisher operators while still guaranteeing the Publisher is cold.

## Property and MutableProperty

Combine only offers a single subject that guarantees that it has a current value: `CurrentValueSubject`. This subject has two drawbacks: First, it has no write-protection (anyone can update its value). Second, it can receive an error, which means that it can stop emitting values forever.

`Property` and `MutableProperty` (implementing PropertyProtocol) solve these problems:

* The only generic parameter is the value. These types use `Never` as their Failure (so can never fail.)
* APIs can expose `Property` in their protocols, and use `MutableProperty` in internal implementations. This allows internal implementations to be the only source of truth for the exposed `Property`.

The `MutableProperty` implementation also has the benefit of guaranteeing thread safety when imperatively accessing/modifying the internal value.

An `@Observable UIProperty` class is also available for wrapping Properties such that they can be used with SwiftUI Observable mechanics (ensuring their value is only updated on the main thread.) This is the perfect class to bridge underlying manager state to SwiftUI view models.

## Action

An `Action` is a deferred (cold) publisher factory. Each call to `apply` constructs a new `AnyDeferredPublisher` using the provided input.  

All publishers constructed by a single parent Action:
* Cannot run in parallel. If any child publisher has an active subscription, then attempting to subscribe to any child publisher will immediately fail.
* The execution state (whether or not any child publisher is in flight, and observing all of the values/errors of all child publishers) is tracking by the parent Action.

This makes Actions great for hooking up to UI!  i.e. pressing a Button can build and run an Action's publisher, and the button's loading spinner can reflect the in-flight execution state of the publisher. The action will prevent code from mistakenly firing an underlying publisher twice in parallel.

## UIScheduler

Typically, when you receive/subscribe using DispatchQueue.main or RunLoop.main, that action will still dispatch asynchronously to the next iteration of the main thread, even if the work was already being on the main thread.

A new scheduler, `UIScheduler` allows you to receive or subscribe on the main thread, but in a way that will execute synchronously/immediately if the receive/subscribe is already occurring in the main thread.

This allows you to guarantee handling updates on the main thread, without observing small visual update delays if the work was already executing on the main thread.

The following QoL Publisher extensions can make this more concise:

```swift
public extension Publisher {
  /// Receive synchronously on the main thread if the upstream publisher
  /// emits on the main thread, otherwise dispatch to main asynchronously.
  func receiveOnMain()

  /// Receive values on the main thread using `DispatchQueue.main`.
  /// This will always dispatch asynchronously to the main queue,
  func receiveOnMainAsync()

  /// Receive values on the main run loop using `RunLoop.main`.
  /// This will only receive events when the current RunLoop
  /// finishes (e.g. it will wait until the user finishes scrolling.)
  func receiveOnMainRunLoop()
}
```

## Quality of Life Extensions

### Sink

Combine typically requires you to retain your AnyCancellables, often having to explicitly store them in a `Set<AnyCancellable>` ivar.

There is a new powerful override of `sink`:

```swift
func sink(
  duringLifetimeOf object: AnyObject,
  receiveSubscription: ((any Subscription) -> Void)? = nil,
  receiveValue: ((Self.Output) -> Void)? = nil,
  receiveCompletion: ((Subscribers.Completion<Self.Failure>) -> Void)? = nil,
  receiveCancel: (() -> Void)? = nil,
  receiveRequest: ((Subscribers.Demand) -> Void)? = nil
) -> AnyCancellable?
```

This `sink` automatically binds the cancellable to the lifetime of the specified object, with automatic garbage collection that removes the cancellable from the object if the cancellable completes before the object is deallocated.

This is useful when starting publishers from within the lifetime of longer-lived objects such as UIViewControllers or Services/Managers. You'll never need to explicitly deal with collections of AnyCancellables again, unless your use case requires access for premature cancellation.
