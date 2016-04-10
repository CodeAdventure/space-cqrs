
class Space.eventSourcing.CommitPublisher extends Space.Object

  @type 'Space.eventSourcing.CommitPublisher'

  dependencies:
    commits: 'Space.eventSourcing.Commits'
    configuration: 'configuration'
    eventBus: 'Space.messaging.EventBus'
    commandBus: 'Space.messaging.CommandBus'
    meteor: 'Meteor'
    ejson: 'EJSON'
    log: 'log'

  _publishHandle: null
  _inProgress: {}

  startPublishing: ->
    appId = @configuration.appId
    if not appId? then throw new Error "#{this}: You have to specify an appId"
    @log.info @_logMsg("started")
    notReceivedYet = { 'receivers.appId': { $nin: [appId] }}
    # Save the observe handle for stopping
    @_publishHandle = @commits.find(notReceivedYet).observe {
      added: (commit) =>
        # Find and lock the event, so only one app instance publishes it
        lockedCommit = @commits.findAndModify({
          query: $and: [_id: commit._id, notReceivedYet]
          update: $push: { receivers: { appId: appId, receivedAt: new Date() } }
        })
        # Only publish the event if this process was the one that locked it
        @publishCommit(@_parseCommit(lockedCommit)) if lockedCommit?
    }

  stopPublishing: ->
    @log.info @_logMsg("stopped")
    @_publishHandle?.stop()

  publishCommit: (commit) =>
    try
      @_setProcessingTimeout(commit)
      for event in commit.changes.events
        @log.info @_logMsg("publishing #{event.typeName()}"), event
        @eventBus.publish event
      for command in commit.changes.commands
        @log.info @_logMsg("sending #{command.typeName()}"), command
        @commandBus.send command
    catch error
      @_failCommitProcessingAttempt(commit._id)
      throw new Error "while publishing:\n
        #{JSON.stringify(commit)}\n
        error:#{error.message}\n
        stack:#{error.stack}"
    @_markAsProcessed(commit)

  _setProcessingTimeout: (commit) ->
    @_inProgress[commit._id] = @meteor.setTimeout (=>
      @log.error(@_logMsg("#{commit._id} timed out"), commit)
      @_failCommitProcessingAttempt(commit._id)
    ), @configuration.eventSourcing.commitProcessing.timeout

  _parseCommit: (commit) ->
    events = []
    commands = []
    # Only parse events that can be handled by this app
    for event in commit.changes.events
      if @_supportsEjsonType event.type
        EventType = Space.resolvePath(event.type)
        events.push EventType.fromData(event.data)
    # Only parse commands that can be handled by this app
    for command in commit.changes.commands
      if @_supportsEjsonType(command.type) and @commandBus.hasHandlerFor(command.type)
        CommandType = Space.resolvePath(command.type)
        commands.push CommandType.fromData(command.data)

    commit.changes.events = events
    commit.changes.commands = commands
    return commit

  _supportsEjsonType: (type) -> @ejson._getTypes()[type]?

  _failCommitProcessingAttempt: (commitId) ->
    appId = @configuration.appId
    commit = @commits.findOne(commitId)
    # Protect against race condition
    if(_.findWhere(commit.receivers, {appId: appId}).processedAt)
      return @log.warning @_logMsg("#{commitId} has already been failed. Potential race condition met, no action required."), commit
    @commits.update(
      { _id: commitId, 'receivers.appId': appId },
      { $set: { 'receivers.$.failedAt': new Date() } }
    )
    @log.error @_logMsg("#{commitId} failed"), commit
    @_cleanupTimeout(commitId)


  _markAsProcessed: (commit) ->
    appId = @configuration.appId
    @meteor.clearTimeout(@_inProgress[commit._id])
    @_cleanupTimeout(commit._id)
    @commits.update(
      { _id: commit._id, 'receivers.appId': appId },
      { $set: { 'receivers.$.processedAt': new Date() } }
    )
    @log.info @_logMsg("#{commit._id} processed"), commit

  _cleanupTimeout: (commitId) ->
    delete @_inProgress[commitId]

  _logMsg: (message) ->
    "#{@configuration.appId}: #{this}: #{message}"
