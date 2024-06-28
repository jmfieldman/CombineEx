# CombineEx

> CombineEx is a WIP, it is not ready for production. I can use your help
> to fill out the complete suite of functionality and tests.

CombineEx is a Swift Combine extension library that fills the gaps which made
ReactiveSwift so great:

* Explicit publisher types for Hot vs. Cold
* Property (and MutableProperty) for error-free, read-only CurrentValueSubject
* Action class
* Quality-of-life extensions for Publisher

### Hot vs Cold

One important missing aspect of Combine publishers is the notion of type-based Hot
vs. Cold.

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
