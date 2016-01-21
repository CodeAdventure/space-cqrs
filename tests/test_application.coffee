'''
This test application is a simple event sourcing example that can be used
by integration tests to work in a real-world setup. The app can be configured
via the new configuration api introduced in space:base.
'''

class @CustomerApp extends Space.Application

  @publish this, 'CustomerApp'

  requiredModules: ['Space.eventSourcing']

  dependencies: {
    mongo: 'Mongo'
  }

  configuration: {
    appId: 'CustomerApp'
    eventSourcing: {
      snapshotting: {
        frequency: 2
      }
    }
  }

  routers: [
    'CustomerApp.CustomerRegistrationRouter'
    'CustomerApp.CustomerRouter'
    'CustomerApp.EmailRouter'
  ]

  projections: [
    'CustomerApp.CustomerRegistrationProjection'
  ]

  afterInitialize: ->
    @injector.map('CustomerApp.CustomerRegistrations').to new @mongo.Collection(null)

  onReset: ->
    @injector.get('CustomerApp.CustomerRegistrations').remove {}

# -------------- COMMANDS ---------------

Space.messaging.define Space.messaging.Command, 'CustomerApp', {
  RegisterCustomer: {
    customerId: String,
    customerName: String
  }
  CreateCustomer: {
    name: String
  }
  SendWelcomeEmail: {
    customerId: String,
    customerName: String
  }
}

# --------------- EVENTS ---------------

Space.messaging.define Space.messaging.Event, 'CustomerApp', {
  RegistrationInitiated: {
    customerId: String,
    customerName: String
  }
  CustomerCreated: {
    customerName: String
  }
  WelcomeEmailTriggered: {
    customerId: String
  }
  WelcomeEmailSent: {
    email: String,
    customerId: String
  }
  RegistrationCompleted: {}
}

# --------------- EXCEPTIONS ---------------

Space.Error.extend CustomerApp, 'InvalidCustomerName', {
  Constructor: (name) ->
    Space.Error.call(this, "Invalid customer name <#{name}>")
    this.stack = null # Make it easier to test this
}

# -------------- AGGREGATES ---------------

class CustomerApp.Customer extends Space.eventSourcing.Aggregate

  fields: -> {
    name: String
  }

  commandMap: -> {
    'CustomerApp.CreateCustomer': (command) ->
      @record new CustomerApp.CustomerCreated {
        sourceId: @getId()
        customerName: command.name
      }
  }

  eventMap: -> {
    'CustomerApp.CustomerCreated': (event) -> @name = event.customerName
  }

CustomerApp.Customer.registerSnapshotType 'CustomerApp.CustomerSnapshot'

# -------------- PROCESSES ---------------

class CustomerApp.CustomerRegistration extends Space.eventSourcing.Process

  @type 'CustomerApp.CustomerRegistration'

  STATES: {
    creatingCustomer: 'creatingCustomer'
    sendingWelcomeEmail: 'sendingWelcomeEmail'
    completed: 'completed'
  }

  fields: -> {
    customerId: String
    customerName: String
  }

  eventCorrelationProperty: 'customerRegistrationId'

  commandMap: -> {
    'CustomerApp.RegisterCustomer': @_registerCustomer
  }

  eventMap: -> {
    'CustomerApp.RegistrationInitiated': @_onRegistrationInitiated
    'CustomerApp.CustomerCreated': @_onCustomerCreated
    'CustomerApp.WelcomeEmailTriggered': @_onWelcomeEmailTriggered
    'CustomerApp.WelcomeEmailSent': @_onWelcomeEmailSent
    'CustomerApp.RegistrationCompleted': @_onRegistrationCompleted
  }

  # =========== COMMAND HANDLERS =============

  _registerCustomer: (command) ->
    if command.customerName == 'MyStrangeCustomerName'
      throw new CustomerApp.InvalidCustomerName(command.customerName)

    @trigger new CustomerApp.CreateCustomer {
      targetId: command.customerId
      name: command.customerName
    }
    @record new CustomerApp.RegistrationInitiated {
      sourceId: @getId()
      customerId: command.customerId
      customerName: command.customerName
    }

  # =========== EXTERNAL EVENT HANDLERS =============

  _onCustomerCreated: (event) ->
    @trigger new CustomerApp.SendWelcomeEmail {
      targetId: @customerId
      customerId: @customerId
      customerName: @customerName
    }
    @record new CustomerApp.WelcomeEmailTriggered {
      sourceId: @getId()
      customerId: @customerId
    }

  _onWelcomeEmailSent: ->
    @record new CustomerApp.RegistrationCompleted sourceId: @getId()

  # =========== INTERNAL EVENT HANDLERS =============

  _onRegistrationInitiated: (event) ->
    @_assignFields(event)
    @_state = @STATES.creatingCustomer

  _onWelcomeEmailTriggered: -> @_state = @STATES.sendingWelcomeEmail

  _onRegistrationCompleted: -> @_state = @STATES.completed

CustomerApp.CustomerRegistration.registerSnapshotType 'CustomerApp.CustomerRegistrationSnapshot'

# -------------- ROUTERS --------------- #

class CustomerApp.CustomerRegistrationRouter extends Space.eventSourcing.Router
  eventSourceable: CustomerApp.CustomerRegistration
  initializingMessage: CustomerApp.RegisterCustomer
  routeEvents: [
    CustomerApp.CustomerCreated
    CustomerApp.WelcomeEmailSent
  ]

class CustomerApp.CustomerRouter extends Space.eventSourcing.Router

  eventSourceable: CustomerApp.Customer
  initializingMessage: CustomerApp.CreateCustomer

class CustomerApp.EmailRouter extends Space.Object

  @type 'CustomerApp.EmailRouter'

  @mixin [
    Space.messaging.CommandHandling
    Space.messaging.EventPublishing
  ]

  commandHandlers: -> [
    'CustomerApp.SendWelcomeEmail': (command) ->
      # simulate sub-system sending emails
      @publish new CustomerApp.WelcomeEmailSent {
        sourceId: '999'
        version: 1
        customerId: command.customerId
        email: "Hello #{command.customerName}"
        meta: command.meta
      }
  ]

# -------------- VIEW PROJECTIONS --------------- #

class CustomerApp.CustomerRegistrationProjection extends Space.eventSourcing.Projection

  dependencies: {
    registrations: 'CustomerApp.CustomerRegistrations'
  }

  eventSubscriptions: -> [
    'CustomerApp.RegistrationInitiated': (event) ->
      @registrations.insert {
        _id: event.sourceId
        customerId: event.customerId
        customerName: event.customerName
        isCompleted: false
      }
    'CustomerApp.RegistrationCompleted': (event) ->
      @registrations.update { _id: event.sourceId }, $set: isCompleted: true
  ]
