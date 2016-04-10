/*
This test application is a simple event sourcing example that can be used
by integration tests to work in a real-world setup. The app can be configured
via the new configuration api introduced in space:base.
*/

Test = Space.namespace('Test');

Space.Application.extend('Test.App', {

  requiredModules: ['Space.eventSourcing'],

  dependencies: {
    mongo: 'Mongo'
  },

  configuration: {
    appId: 'Test.App',
    eventSourcing: {
      snapshotting: {
        frequency: 2
      }
    }
  },

  routers: [
    'Test.CustomerRegistrationRouter',
    'Test.CustomerRouter',
    'Test.EmailRouter'
  ],

  projections: [
    'Test.CustomerRegistrationProjection'
  ],

  onInitialize() {
    this.injector.map('myAggregateDependency').asStaticValue(
      Test.myAggregateDependency
    );
    this.injector.map('myProcessDependency').asStaticValue(
      Test.myProcessDependency
    );
  },

  afterInitialize() {
    this.injector.map('Test.CustomerRegistrations')
    .to(new this.mongo.Collection(null));
  },

  onReset() {
    this.injector.get('Test.CustomerRegistrations').remove({});
  }
});

// -------------- DEPENDENCIES ---------------

Test.myAggregateDependency = sinon.spy();
Test.myProcessDependency = sinon.spy();

// -------------- COMMANDS ---------------

Space.messaging.define(Space.domain.Command, 'Test', {
  RegisterCustomer: {
    customerId: String,
    customerName: String
  },
  CreateCustomer: {
    name: String
  },
  ChangeCustomerName: {
    name: String
  },
  SendWelcomeEmail: {
    customerId: String,
    customerName: String
  }
});

// --------------- EVENTS ---------------

Space.messaging.define(Space.domain.Event, 'Test', {
  RegistrationInitiated: {
    customerId: String,
    customerName: String
  },
  CustomerCreated: {
    customerName: String
  },
  CustomerNameChanged: {
    customerName: String
  },
  WelcomeEmailTriggered: {
    customerId: String
  },
  WelcomeEmailSent: {
    email: String,
    customerId: String
  },
  RegistrationCompleted: {}
});

// --------------- EXCEPTIONS ---------------

Space.Error.extend('Test.InvalidCustomerName', {
  Constructor(name) {
    Space.Error.call(this, `Invalid customer name <${name}>`);
    this.stack = null; // Make it easier to test this
  }
});

// -------------- AGGREGATES ---------------

Space.eventSourcing.Aggregate.extend('Test.Customer', {

  dependencies: {
    myAggregateDependency: 'myAggregateDependency'
  },

  fields: {
    name: String
  },

  commandMap() {
    return {
      'Test.CreateCustomer'(command) {
        this.myAggregateDependency();

        this.record(new Test.CustomerCreated({
          sourceId: this.getId(),
          customerName: command.name
        }));
      },
      'Test.ChangeCustomerName'(command) {
        this.myAggregateDependency();

        this.record(new Test.CustomerNameChanged({
          sourceId: this.getId(),
          customerName: command.name
        }));
      }
    };
  },

  eventMap() {
    return {
      'Test.CustomerCreated'(event) {
        this.name = event.customerName;
      },
      'Test.CustomerNameChanged'(event) {
        this.name = event.customerName;
      }
    };
  }
});

Test.Customer.registerSnapshotType('Test.CustomerSnapshot');

// -------------- PROCESSES ---------------

Space.eventSourcing.Process.extend('Test.CustomerRegistration', {

  dependencies: {
    myProcessDependency: 'myProcessDependency'
  },

  STATES: {
    creatingCustomer: 'creatingCustomer',
    sendingWelcomeEmail: 'sendingWelcomeEmail',
    completed: 'completed'
  },

  fields: {
    customerId: String,
    customerName: String
  },

  eventCorrelationProperty: 'customerRegistrationId',

  commandMap() {
    return {
      'Test.RegisterCustomer': this._registerCustomer
    };
  },

  eventMap() {
    return {
      'Test.RegistrationInitiated': this._onRegistrationInitiated,
      'Test.CustomerCreated': this._onCustomerCreated,
      'Test.WelcomeEmailTriggered': this._onWelcomeEmailTriggered,
      'Test.WelcomeEmailSent': this._onWelcomeEmailSent,
      'Test.RegistrationCompleted': this._onRegistrationCompleted
    };
  },

  // =========== COMMAND HANDLERS =============

  _registerCustomer(command) {
    this.myProcessDependency();

    if (command.customerName === 'MyStrangeCustomerName') {
      throw new Test.InvalidCustomerName(command.customerName);
    }

    this.trigger(new Test.CreateCustomer({
      targetId: command.customerId,
      name: command.customerName
    }));

    this.record(new Test.RegistrationInitiated({
      sourceId: this.getId(),
      customerId: command.customerId,
      customerName: command.customerName
    }));
  },

  // =========== EXTERNAL EVENT HANDLERS =============

  _onCustomerCreated() {
    this.myProcessDependency();

    this.trigger(new Test.SendWelcomeEmail({
      targetId: this.customerId,
      customerId: this.customerId,
      customerName: this.customerName
    }));

    this.record(new Test.WelcomeEmailTriggered({
      sourceId: this.getId(),
      customerId: this.customerId
    }));
  },

  _onWelcomeEmailSent() {
    this.myProcessDependency();

    this.record(new Test.RegistrationCompleted({ sourceId: this.getId() }));
  },

  // =========== INTERNAL EVENT HANDLERS =============

  _onRegistrationInitiated(event) {
    this._assignFields(event);
    this._state = this.STATES.creatingCustomer;
  },

  _onWelcomeEmailTriggered() {
    this._state = this.STATES.sendingWelcomeEmail;
  },

  _onRegistrationCompleted() {
    this._state = this.STATES.completed;
  }
});

Test.CustomerRegistration.registerSnapshotType(
  'Test.CustomerRegistrationSnapshot'
);

// -------------- ROUTERS --------------- #

Space.eventSourcing.Router.extend('Test.CustomerRegistrationRouter', {
  eventSourceable: Test.CustomerRegistration,
  initializingMessage: Test.RegisterCustomer,
  routeEvents: [
    Test.CustomerCreated,
    Test.WelcomeEmailSent
  ]
});

Space.eventSourcing.Router.extend('Test.CustomerRouter', {
  eventSourceable: Test.Customer,
  initializingMessage: Test.CreateCustomer,
  routeCommands: [
    Test.ChangeCustomerName
  ]
});

Space.Object.extend('Test.EmailRouter', {

  mixin: [
    Space.messaging.CommandHandling,
    Space.messaging.EventPublishing
  ],

  commandHandlers() {
    return [{
      'Test.SendWelcomeEmail'(command) {
        // simulate sub-system sending emails
        this.publish(new Test.WelcomeEmailSent({
          sourceId: '999',
          version: 1,
          customerId: command.customerId,
          email: `Hello ${command.customerName}`,
          meta: command.meta
        }));
      }
    }];
  }
});

// -------------- VIEW PROJECTIONS --------------- #

Space.eventSourcing.Projection.extend('Test.CustomerRegistrationProjection', {

  dependencies: {
    registrations: 'Test.CustomerRegistrations'
  },

  eventSubscriptions() {
    return [{
      'Test.RegistrationInitiated'(event) {
        this.registrations.insert({
          _id: event.sourceId,
          customerId: event.customerId,
          customerName: event.customerName,
          isCompleted: false
        });
      },
      'Test.RegistrationCompleted'(event) {
        this.registrations.update({ _id: event.sourceId }, { $set: {
          isCompleted: true
        }});
      }
    }];
  }
});