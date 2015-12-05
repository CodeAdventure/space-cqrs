class Space.eventSourcing.Router extends Space.messaging.Controller

  @type 'Space.eventSourcing.Router'

  dependencies: {
    configuration: 'configuration'
    repository: 'Space.eventSourcing.Repository'
    commitStore: 'Space.eventSourcing.CommitStore'
    log: 'log'
  }

  @ERRORS: {

    managedEventSourcableNotSpecified: 'Please specify a Router::eventSourceable
    class to be managed by the router.'

    missingInitializingMessage: 'Please specify Router::initializingMessage
    (an event or command class) that will be used to create new instanes of
    the managed eventSourceable.'

    missingEventCorrelationProperty: 'Please specify Process::eventCorrelationProperty
    that will be used to route events to the managed eventSourceable.'

    cannotHandleMessage: (message, id) ->
      new Error "No eventSourceable <#{id}> found to handle #{message.typeName()}"
  }

  eventSourceable: null
  initializingMessage: null
  routeEvents: null
  routeCommands: null
  eventCorrelationProperty: null

  constructor: ->
    if not @eventSourceable?
      throw new Error Router.ERRORS.managedEventSourcableNotSpecified
    if not @initializingMessage?
      throw new Error Router.ERRORS.missingInitializingMessage
    @routeEvents ?= []
    @eventCorrelationProperty = @eventSourceable::eventCorrelationProperty
    if @routeEvents.length > 0 and not @eventCorrelationProperty?
      throw new Error Router.ERRORS.missingEventCorrelationProperty
    @routeCommands ?= []
    super

  onDependenciesReady: ->
    super
    @_setupInitializingMessage()
    @_routeEventToEventSourceable(eventType) for eventType in @routeEvents
    @_routeCommandToEventSourceable(commandType) for commandType in @routeCommands

  _setupInitializingMessage: ->
    if @initializingMessage.isSubclassOf(Space.messaging.Event)
      @eventBus.subscribeTo @initializingMessage, (event) =>
        @log.info("#{this}: Creating new #{@eventSourceable} with event
                  #{event.typeName()}\n", event)
        eventSourceable = @_handleDomainErrors(-> new @eventSourceable event)
        @repository.save(eventSourceable) if eventSourceable?
    else if @initializingMessage.isSubclassOf(Space.messaging.Command)
      @commandBus.registerHandler @initializingMessage, (cmd) =>
        @log.info("#{this}: Creating new #{@eventSourceable} with command
                  #{cmd.typeName()}\n", cmd)
        eventSourceable = @_handleDomainErrors(-> new @eventSourceable cmd)
        @repository.save(eventSourceable) if eventSourceable?

  _routeEventToEventSourceable: (eventType) ->
    @eventBus.subscribeTo eventType, @_genericEventHandler

  _routeCommandToEventSourceable: (commandType) ->
    @commandBus.registerHandler commandType, @_genericCommandHandler

  _genericEventHandler: (event) =>
    # Only route this event if the correlation property exists
    return unless event.meta? and event.meta[this.eventCorrelationProperty]?
    correlationId = event.meta[this.eventCorrelationProperty]
    @log.info(@_logMsg("Handling event #{event.typeName()} for
                       #{@eventSourceable}<#{correlationId}>\n"), event)
    eventSourceable = @repository.find @eventSourceable, correlationId
    throw Router.ERRORS.cannotHandleMessage(event) if !eventSourceable?
    eventSourceable = @_handleDomainErrors(-> eventSourceable.handle event)
    @repository.save(eventSourceable) if eventSourceable?

  _genericCommandHandler: (command) =>
    if not command? then return
    @log.info(@_logMsg("Handling command #{command.typeName()} for
                       #{@eventSourceable}<#{command.targetId}>"), command)
    eventSourceable = @repository.find @eventSourceable, command.targetId
    throw Router.ERRORS.cannotHandleMessage(command) if !eventSourceable?
    eventSourceable = @_handleDomainErrors(-> eventSourceable.handle command)
    @repository.save(eventSourceable) if eventSourceable?

  _logMsg: (message) -> "#{@configuration.appId}: #{this}: #{message}"

  _handleDomainErrors: (fn) ->
    try
      return fn.call(this)
    catch error
      if error instanceof Space.Error
        this.publish(new Space.domain.Exception({
          thrower: @eventSourceable.toString(),
          error: error
        }))
        return null
      else
        throw error
