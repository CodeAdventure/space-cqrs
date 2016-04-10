
{ CommitStore, CommitPublisher } = Space.eventSourcing

Event = Space.domain.Event
EventBus = Space.messaging.EventBus
Command = Space.domain.Command
CommandBus = Space.messaging.CommandBus

# =========== TEST DATA ========== #

class CPTestEvent extends Event
  @type 'Space.eventSourcing.CommitPublisher.TestEvent'

class CPTestCommand extends Command
  @type 'Space.eventSourcing.CommitPublisher.TestCommand'

class CPCreatedEvent extends Event
  @type 'tests.CommitPublisher.CreatedEvent', ->

class CPQuantityChangedEvent extends Event
  @type 'tests.CommitPublisher.QuantityChangedEvent'
  @fields: quantity: Match.Integer

class CPTotalChangedEvent extends Event
  @type 'tests.CommitPublisher.TotalChangedEvent'
  @fields: total: Number

# =========== SPECS ============= #

describe "Space.eventSourcing.CommitPublisher", ->

  Commits = new Mongo.Collection('TestCommits')

  beforeEach ->
    @clock = sinon.useFakeTimers(Date.now(), 'Date')
    @appId = 'MyApp'
    @configuration = {
      appId: @appId,
      eventSourcing: {
        commitProcessing: {
          timeout: 20
        }
      }
    }
    Commits.remove {}
    @commitPublisher = new CommitPublisher {
      commits: Commits
      configuration: @configuration
      eventBus: new EventBus { meteor: Meteor }
      commandBus: new CommandBus { meteor: Meteor }
      meteor: Meteor
      ejson: EJSON
      log: Space.log
    }
#    Un-comment this to log test cases
#    @commitPublisher.log.start()
    @commitStore = new CommitStore {
      commits: Commits
      commitPublisher: @commitPublisher
      configuration: @configuration
      log: Space.log
    }
    @commandHandler = sinon.spy()
    @commitPublisher.commandBus.registerHandler(
      'Space.eventSourcing.CommitPublisher.TestCommand',
      @commandHandler
    )

    @externalReceiveEntry = { appId: 'someOtherApp', receivedAt: new Date() }
    sourceId = '123'
    testEvent = new CPTestEvent sourceId: sourceId
    testCommand = new CPTestCommand targetId: sourceId
    expectedVersion = 0
    newVersion = expectedVersion + 1
    @commitProps = {
      sourceId: sourceId
      version: newVersion
      changes:
        events: [EJSON.stringify(testEvent)]
        commands: [EJSON.stringify(testCommand)]
      insertedAt: new Date()
      sentBy: 'someOtherApp'
      receivers: [@externalReceiveEntry]
      eventTypes: [CPTestEvent.toString()]
    }

    @commitId = Commits.insert @commitProps

  afterEach ->
    @clock.restore()
    Commits.remove {}
    @commitPublisher.stopPublishing()

  it 'publishes externally added commits once in the current app, even with multiple app instances running', ->
    @commitPublisher.publishCommit = sinon.spy()
    @commitPublisher.startPublishing()
    insertedCommit = Commits.findOne(@commitId)
    expect(@commitPublisher.publishCommit).to.have.been.called
    expect(insertedCommit.receivers).to.deep.equal([@externalReceiveEntry, {
      appId: @appId
      receivedAt: new Date()
    }])

  it 'fails the processing attempt if configurable timeout duration is reached', (test, waitFor) ->
    fail = @commitPublisher._failCommitProcessingAttempt = sinon.spy()
    @configuration.eventSourcing.commitProcessing.timeout = 1
    commit = Commits.findOne(@commitId)
    @commitPublisher._setProcessingTimeout(commit)
    timeout = =>
      try
        commit = Commits.findOne(@commitId)
        expect(fail).to.be.calledWith(@commitId)
      catch err
        test.exception err
    Meteor.setTimeout(waitFor(timeout), 2);

  it 'updates the commit record with the date when the processing is failed', ->
    lockedCommit = Commits.findAndModify({
      query: $and: [_id: @commitId, { 'receivers.appId': { $nin: [@appId] }}]
      update: $push: { receivers: { appId: @appId, receivedAt: new Date() } }
    })
    @commitPublisher._markAsProcessed = ->
    @commitPublisher.publishCommit(@commitPublisher._parseCommit(lockedCommit))
    @commitPublisher._failCommitProcessingAttempt(@commitId)

    commit = Commits.findOne(@commitId)
    failedAt = _.findWhere(commit.receivers, {appId: @appId}).failedAt
    Meteor.clearTimeout(@commitPublisher._inProgress[commit._id])
    expect(failedAt).to.be.instanceOf(Date)

  it 'ignores calls to fail successful processing attempt to protects the commit record from race conditions with timeouts', ->
    @configuration.eventSourcing.commitProcessing.timeout = 1
    Commits.findAndModify({
      query: $and: [_id: @commitId, { 'receivers.appId': { $nin: [@appId] }}]
      update: $push: { receivers: {
        appId: @appId,
        receivedAt: new Date(),
        processedAt: new Date()
      }}
    })
    @commitPublisher._failCommitProcessingAttempt(@commitId)
    commit = Commits.findOne(@commitId)
    failedAt = _.findWhere(commit.receivers, {appId: @appId}).failedAt
    expect(failedAt).to.equal.undefined

  it "stores each commit's publishing timeout using the id as a the key", ->
    commit = Commits.findOne(@commitId)
    @commitPublisher._setProcessingTimeout(commit)
    expect(@commitPublisher._inProgress).to.have.property(@commitId);
    expect(@commitPublisher._inProgress[@commitId]).to.respondTo('_onTimeout');

  it "tracks each commit's publishing timeout when publishing", ->
    mockPublisher = sinon.mock(@commitPublisher)
    commit = Commits.findOne(@commitId)
    mockPublisher.expects("_setProcessingTimeout").once().withExactArgs(commit)
    @commitPublisher.publishCommit(@commitPublisher._parseCommit(commit))
    mockPublisher.verify()

  it "cleans up after the commit is processed, by deleting the object key", ->
    mockPublisher = sinon.mock(@commitPublisher)
    mockPublisher.expects("_cleanupTimeout").once().withExactArgs(@commitId)
    @commitPublisher.startPublishing()
    expect(@commitPublisher._inProgress[@commitId]).to.equal.undefined
    mockPublisher.verify()
