# CQRS & Event Sourcing for Meteor

[![Circle CI](https://circleci.com/gh/meteor-space/event-sourcing.svg?style=svg)](https://circleci.com/gh/meteor-space/event-sourcing)
[![Join the chat at https://gitter.im/meteor-space/event-sourcing](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/meteor-space/event-sourcing?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

This package provides the infrastructure for building your Meteor app
with the **CQRS** (Command/Query Responsibility Separation) and **Event Sourcing**
principles in mind. This enables you to build complex applications with a strong
business logic that is easy to test and reason about.

### Contents:
* [Installation](#installation)
* [Concepts](#concepts)
  * [Event Sourcing](#event-sourcing)
  * [CQRS](#cqrs)
  * [Domain Driven Design](#domain-driven-design)
* [Documentation](#documentation)

## Installation
`meteor add space:event-sourcing`

## Concepts

If you're new to concepts like **CQRS**, **ES** and **DDD**, read
on to get a quick overview.

-----------------------

### Event Sourcing
Storing all the changes (events) to the system, rather than just its
current state.

#### Why haven't I heard of storing events before?
You have. Almost all database systems use a log for storing all changes applied
to the database (OPLOG anyone?). In a pinch, the current state
of the database can be recreated from this transaction log. This is a kind of event
store. Event sourcing just means following this idea to its conclusion and using
such a log as the primary source of data.

#### What are some advantages of event sourcing?
* **History**: Having a true history of the system. Gives further benefits such
as audit and traceability.
* **Answers**: You never know which questions about your system/users you will
ask in one year.
* **Time travel**: Ability to put the system in any prior state. (I.e. what did
the system look like last week?)
* **Flexibility**: By storing all events your can create arbitrary read-model
projections at any time in the project. This enables you to present your data in
any number of ways and optimize it for the client-side.
* **Speed:** Events are always appended, never updated or deleted which makes
storing them blazing fast.

*You can read more about Event Sourcing here:*

* [Martin Fowler - Event Sourcing](http://www.martinfowler.com/eaaDev/EventSourcing.html)
* [Greg Young - Event Sourcing](http://docs.geteventstore.com/introduction/event-sourcing-basics/)
* [Microsoft - Event Sourcing](https://msdn.microsoft.com/en-us/library/dn589792.aspx)

-----------------------

### CQRS
*Command/Query Responsibility Separation*

We segregate the responsibility between **commands** (write requests) and **queries**
(read requests). Where you had just one model to read/write data from/to your system,
you now have two. Each one is optimized for its purpose, reading or writing.

The true strength of CQRS lies in the combination with Event Sourcing. Your event-store
becomes the **write model** side of your system (optimized for business logic).
The projected data-structures based on your event stream, become the **read model**
(optimized for the requirements of the UI / client-side).

#### What are advantages of this pattern?

* You can optimize the reading / writing to your system separately.
* Your business logic becomes simpler because you don't need to think about UI concerns.
* You can create any number of different read-models (think: Mongo.Collections)
based on your event stream. And rebuild them from scratch at any time in the project!
* Much faster data subscriptions/loading because the collections can be optimized
for the UI.
* No more reactive JOINS or other nonsense that does not perform.

*You can read more about CQRS here:*

* [Microsoft about CQRS](http://msdn.microsoft.com/en-us/library/dn568103.aspx)
* [CQRS FAQ](http://www.cqrs.nu/)
* [Tutorial about CQRS & Event Sourcing](http://cqrs.nu/tutorial/cs/01-design)
(C# but still relevant)
* [Martin Fowler about CQRS](http://martinfowler.com/bliki/CQRS.html)

-----------------------

### Domain Driven Design
Structure, practices and terminology for making design decisions in complex software.

#### What is a domain?
*The field for which a system is built.*

Airport management, insurance sales, coffee shops, orbital flight, you name it.
It's not unusual for an application to span several different domains. For example,
an online retail system might be working in the domains of shipping (picking
appropriate ways to deliver, depending on items and destination), pricing
(including promotions and user-specific pricing by, say, location), and
recommendations (calculating related products by purchase history).

#### What is a model?
*"A useful approximation to the problem at hand." -- Gerry Sussman*

An `Employee` class is not a real employee. It models a real employee. We know
that the model does not capture everything about real employees, and that's not
the point of it. It's only meant to capture what we are interested in for the
current context.

Different domains may be interested in different ways to model the same thing.
For example, the salary department and the human resources department may model
employees in different ways.

#### What is Domain-Driven Design (DDD)?
It is a development approach that deeply values the domain model and connects
it to the implementation. DDD was coined and initially developed by Eric Evans
in his great book [Domain-Driven Design: Tackling Complexity in the Heart of Software](http://www.amazon.com/Domain-Driven-Design-Tackling-Complexity-Software/dp/0321125215).

*You can read more about DDD here:*

* [An Introduction to Domain Driven Design](http://www.methodsandtools.com/archive/archive.php?id=97)
* [Domain Driven Design Quickly - Great Book!](http://www.infoq.com/minibooks/domain-driven-design-quickly)
* [Common DDD mistakes](http://www.infoq.com/news/2015/07/ddd-mistakes)

-----------------------

## Documentation

*More and better documentation is coming soon …*

`meteor:event-sourcing` provides distributed Event Sourcing infrastructure,
with CQRS and DDD patterns in mind. It provides a base class for event-sourced [Aggregates](http://martinfowler.com/bliki/DDD_Aggregate.html)
and [ProcessManagers](https://msdn.microsoft.com/en-us/library/jj591569.aspx), and pairs nicely with `space:domain` to model
your business domain with Entities,
[ValueObjects](http://martinfowler.com/bliki/ValueObject.html), and Domain Events.

It also provides a MongoDB based distributed EventStore which works a little bit different
than "normal" event store implementations because MongoDB doesn't support transactions.
To circumvent this, the concept of a commit is used, which bundles multiple events and
commands together into one "transaction" commit. [Here is a short blog article](http://blingcode.blogspot.co.at/2010/12/cqrs-building-transactional-event-store.html)
talking about the basic concept.

It heavily uses the `space-messaging` package for Meteor `EJSON` and
runtime-`check`ed domain events and commands that are automatically serialized
into the MongoDB and restored for you. So you don't have to deal with
serialization concerns anywhere but within your value objects.

## Contributing
In lieu of a formal styleguide, take care to maintain the existing coding style.
Add unit / integration tests for any new or changed functionality.

## Run the tests
`meteor test-packages ./`

## Release History
You can find the release history in the [changelog](https://github.com/meteor-space/event-sourcing/blob/master/CHANGELOG.md)

## Thanks
Thanks to [CQRS FAQ](http://cqrs.nu/Faq/) (Creative Commons) for a lot of
inspiration and copy.

## License
Licensed under the MIT license.
