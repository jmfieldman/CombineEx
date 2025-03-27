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

### Hot vs Cold

One fundamental missing piece in Combine is the lack of semantics around hot vs. cold publishers. 

If you are unfamiliar with the distinction:

* A *hot publisher* is usually attached to emissions from a shared resource, and the act of subscribing does not typically fire off a new unit of work.
  * An example might be something like `currentLocation` that emits values returned from a `CLLocationManagerDelegate` callback. `currentLocation` might be backed by a `CurrentValueSubject`, and subscribing simply listens to changes in this subject. Multiple subscribers will all receive the same values from the each update.
* A *cold publisher* kicks off a new, distinct unit of work for every subscription, and the emissions of the publisher are unique to that subscription.
  * An example of this is `URLSession.shared.dataTaskPublisher(for: url)` -- each subscription kicks off a distinct call to the URL, and the results of that request are only sent to the subscription that initiated it.

In Combine, when the above use cases are exposed through an API, they are both represented by `AnyPublisher`. This provides no mental signposting for how to think about the way a publisher acts when it is subscribed to.

CombineEx defines an opinated semantic that `Deferred` is reserved for *cold publishers*. By extension, an API can provide the new `AnyDeferredPublisher` to establish at the API layer that the vended publisher is *cold* and will kick off a distinct stream of values backed by a distinct workstream for each subscription.

APIs can continue to vend `AnyPublisher` for hot/ambiguous publishers.

##### Hot

A hot publisher emits values from some existing resource. Consider conceptual hot publishers:

* `TemperatureSensor.temperature: Publisher<Double, Never>` 
* `NetworkManager.connectivityState: Publisher<ConnectionState, Never>`
* `BookDBTable.rowCount: Publisher<Int, Never>`

When these publishers are started, they perform no additional work other than latching
onto these existing resources and emitting updates when they change. A hot publisher does
not guarantee that the current state is emitted when it is subscribed to.

Hot publishers often use `Never` as their error, since they report on a resource
that always exists and indefinitely emits some value. Error states are usually reported on a
separate hot publisher, or rolled into an umbrella enum that is used as the value type (e.g. the
`ConnectionState` enum contains a 'notConnected' case.)

Another common aspect of hot publishers is that multiple subscriptions all observe the
same fundamental underlying resource. Ten subscribers to `TemperatureSensor.temperature` will
typically all be updated with the same `Double` when the underlying sensor updates.
In combine, because there are no guaratees about underlying Publisher behavior, we should
assume that any `Publisher`/`AnyPublisher` objects are *hot*.

##### Cold

A cold publisher is different from a hot publisher, in that a cold publisher is assumed
to perform some unique additional work for each subscription, and each separate subscription
is likely to get a unique stream of data.

Consider conceptual cold publishers:

* `NetworkManager.httpFetchBooks: DeferredPublisher<BooksResult, NetworkError>`
* `DatabaseManager.queryBookCount: DeferredPublisher<Int, DatabaseError>` 

These publishers perform some action when subscribed (a network query, or a database query, etc)
and emits values unique to that work. It is understood that separate subscribers all perform
their own unique work and received their own unique values.

In combine, the mechanism for this is with a `Deferred` publisher. The problem with combine
is that the type-erasure system wipes `Deferred` publishers into `AnyPublisher` at API/module boundaries,
which removes any type-based inferrence about whether or not the publisher is hot or cold.

CombineEx introduces new first-class types: 

* `DeferredPublisher: struct` and its corresponding `AnyDeferredPublisher: class`
* `DeferredFuture: struct` and its corresponding `AnyDeferredFuture: class`

You can use the new type-erased `AnyDeferredPublisher` and `AnyDeferredFuture` to convey
explicit cold-publisher types across API/module boundaries.

These new types are all `Publisher`, so any operator works on them. New operator overrides exist
to keep their Deferred nature, as long as it makes sense.  e.g. `DeferredFuture` has an override
to flatMap into another `DeferredFuture` (and keep the output a `DeferredFuture`), but flatMapping
into a `DeferredPublisher` would only emit a `DeferredPublisher`. 

### Property and MutableProperty

Combine only offers a single subject that guarantees that it has a current value: `CurrentValueSubject`.
This subject has two drawbacks: First, it has no write-protection (anyone can update its value). Second,
it can receive an error, which means that it can stop emitting values forever.

`Property` and `MutableProperty` (implementing PropertyProtocol) solve these problems:

* The only generic parameter is the value. These types always use `Never` as their error.
* APIs can expose `Property` in their protocols, and use `MutableProperty` in internal implementations. This
allows internal implementations to be the only source of truth for the exposed `Property`.

The `MutableProperty` implementation also has the benefit of guaranteeing thread safety when imperatively
accessing/modifying the internal value.

### Action class

ReactiveSwift introduced the concept of an `Action`.  Think of an `Action` as a cold publisher factory.
Each call to `apply` constructs a cold publisher with the input.  

These constructed cold publishers:
* Cannot run in parallel. Starting a new publisher will interrupt a previous one, or return an immediate error
that a previous publisher was running.
* The execution state (whether or not one is in flight, and observing all of the values/errors) can be
tracking by the parent Action.

This makes Actions great for hooking up to UI.  i.e. pressing a UIButton can build and run an Action's publisher,
and the button's loading spinner can reflect the in-flight execution state of the publisher.

### Quality of Life Extensions

##### Sink

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

This `sink` automatically binds the cancellable to the lifetime of the specified object, with automatic garbage collection
that removes the cancellable from the object if the cancellable completes before the object is deallocated.

This is useful when starting publishers from within the lifetime of longer-lived objects such as UIViewControllers or
Services/Managers, and not needing to explicitly deal with collections of AnyCancellable.
