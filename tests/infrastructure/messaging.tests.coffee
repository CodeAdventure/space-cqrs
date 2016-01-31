describe 'Space.eventSourcing - messaging', ->

  customer = id: 'customer_123', name: 'Dominik'
  registration = id: 'registration_123'

  generatedEventsForCustomerRegistration = -> [

    new Test.RegistrationInitiated({
      sourceId: registration.id
      version: 1
      timestamp: new Date()
      customerId: customer.id
      customerName: customer.name
    })
    new Test.CustomerCreated({
      sourceId: customer.id
      version: 1
      timestamp: new Date()
      customerName: customer.name
      meta: {
        customerRegistrationId: registration.id
      }
    })
    new Test.WelcomeEmailTriggered({
      sourceId: registration.id
      version: 2
      timestamp: new Date()
      customerId: customer.id
      meta: {
        customerRegistrationId: registration.id
      }
    })
    # This is just visible in the app that runs the code
    # since it is directly published via the event store
    # instead of saved to the DB as part of a commit!
    new Test.WelcomeEmailSent({
      sourceId: '999'
      version: 1
      timestamp: new Date()
      email: "Hello #{customer.name}"
      customerId: customer.id
      meta: {
        customerRegistrationId: registration.id
      }
    })
    new Test.RegistrationCompleted({
      sourceId: registration.id
      version: 3
      timestamp: new Date()
      meta: {
        customerRegistrationId: registration.id
      }
    })
  ]

  it 'handles messages within one app correctly', ->

    Test.App.test(Test.Customer)
    .given(
      new Test.RegisterCustomer {
        targetId: registration.id
        customerId: customer.id
        customerName: customer.name
      }
    )
    .expect(generatedEventsForCustomerRegistration())


  '''
  it 'supports distributed messaging via a shared commits collection', (test, done) ->

    SecondApp = Space.Application.extend {
      requiredModules: ['Space.eventSourcing']
      configuration: { appId: 'SecondApp' }
      afterInitialize: ->
        # Aggregate all published events on the second app
        @publishedEvents = []
        @eventBus.onPublish (event) => @publishedEvents.push event
    }
    secondApp = new SecondApp()
    secondApp.reset()
    secondApp.start()
    try
      expectedEvents = null

      Test.test(Test.Customer)
      .given(
        new Test.RegisterCustomer {
          targetId: registration.id
          customerId: customer.id
          customerName: customer.name
        }
      )
      .expect(->
        expectedEvents = generatedEventsForCustomerRegistration()
        return expectedEvents
      )

      # Remove the event that is only visible to the other app
      # because it is directly published on its event bus!
      expectedEvents.splice(3,1)
      expect(secondApp.publishedEvents).toMatch expectedEvents
    finally
      secondApp.stop()
  '''
