
{Event, Command} = Space.domain

class Space.eventSourcing.Aggregate extends Space.Object

  @type 'Space.eventSourcing.Aggregate'

  _id: null
  _version: 0
  _events: null
  _state: null
  _handlers: null
  _metaData: null

  # Override to define which custom properties this aggregate has
  fields: {}

  ERRORS: {
    guidRequired: "#{Aggregate}: Aggregate needs an GUID on creation."
    domainEventRequired: "#{Aggregate}: Event must inherit from Space.domain.Event"
    cannotHandleMessage: "#{Aggregate}: Cannot handle: "
    invalidEventSourceId: "#{Aggregate}: The given event has an invalid source id."
    undefinedSnapshotTpe: "#{Aggregate}: Snapshot type is undefined. Did you forget to call: #{Aggregate}.registerSnapshotType()?"
  }

  @createFromHistory: (events) -> new this(events[0].sourceId, events)

  @createFromSnapshot: (snapshot) -> new this(snapshot.id, snapshot, true)

  @registerSnapshotType: (id) ->
    fields = {}
    fields[field] = type for field, type of this::fields
    @_snapshotType = Space.eventSourcing.Snapshot.extend id, {
      fields: ->
        superFields = Space.eventSourcing.Snapshot::fields()
        return _.extend(superFields, fields)
    }

  constructor: (id, data, isSnapshot) ->
    unless id? then throw new Error Aggregate::ERRORS.guidRequired
    # This aggregate is created from a command -> assign targetId
    @_id = if (id instanceof Command) then id.targetId else id
    @_events = []
    @_handlers = {}
    @fields.meta = Match.Optional(Object)
    # Setup event and command handlers
    @_setupHandlers()
    # Bootstrap the aggregate
    if isSnapshot then @applySnapshot data
    else if @isHistory data then @replayHistory data
    else if (id instanceof Command) then @handle id
    else @initialize?.apply(this, arguments)
    return this

  getId: -> @_id

  getVersion: -> @_version

  getEvents: -> @_events

  getSnapshot: ->
    unless @constructor._snapshotType? then throw new Error Aggregate::ERRORS.undefinedSnapshotTpe
    data = {}
    data.id = @_id
    data.state = @_state
    data.version = @_version
    (data[field] = this[field]) for field of @fields when this[field] != undefined
    return new @constructor._snapshotType(data)

  applySnapshot: (snapshot) ->
    if not snapshot? then throw new Error "Invalid snapshot: #{snapshot}"
    @_id = snapshot.id
    @_state = snapshot.state
    @_version = snapshot.version
    (this[field] = snapshot[field]) for field of @fields when snapshot[field] != undefined

  record: (event) ->
    if this.meta? or @_metaData?
      event.meta ?= {}
      _.extend(event.meta, this.meta ? {}, @_metaData ? {})
    @_validateEvent event
    @_events.push event
    @handle(event) if @hasHandlerFor(event)
    @_updateToEventVersion event

  replay: (event) ->
    @_validateEvent event
    @handle event if @hasHandlerFor(event)
    @_updateToEventVersion event

  isHistory: (data) -> toString.call(data) == '[object Array]'

  replayHistory: (history) -> @replay(event) for event in history

  handle: (message) ->
    @_metaData = message.meta ? null
    @_getHandler(message).call this, message
    return this

  hasState: (state) -> if state? then @_state == state else @_state?

  getState: -> @_state

  hasHandlerFor: (message) -> @_handlers[message.typeName()]?

  # ============= PRIVATE ============ #

  _setupHandlers: ->
    mappings = _.extend {}, @eventMap?(), @commandMap?()
    @_handlers[messageType] = handler for messageType, handler of mappings

  _getHandler: (message) ->
    if not @hasHandlerFor(message)
      throw new Error @ERRORS.cannotHandleMessage + message.typeName()
    else
      return @_handlers[message.typeName()]

  _validateEvent: (event) ->
    unless event instanceof Event
      throw new Error @ERRORS.domainEventRequired
    unless event.sourceId.toString() == @getId().toString()
      throw new Error @ERRORS.invalidEventSourceId

  _updateToEventVersion: (event) ->
    if event.version? then @_version = event.version

  _eventPropsFromCommand: (command) ->
    props = {}
    for key of command.fields() when key != 'targetId'
      props[key] = command[key] if command[key] != undefined
    props.sourceId = command.targetId
    props.version = @getVersion()
    return props

  _assignFields: (event) -> _.extend this, _.pick(event, _.keys(this.fields))
