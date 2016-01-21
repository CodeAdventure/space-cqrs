
{Snapshotter} = Space.eventSourcing

describe 'Space.eventSourcing.Snapshotter', ->

  class MySnapshotAggregate extends Space.eventSourcing.Aggregate
    @toString: -> 'MySnapshotAggregate'
    fields: -> test: String
    @registerSnapshotType 'MySnapshotAggregate'

  class MySnapshotApp extends Space.Application
    requiredModules: ['Space.eventSourcing']
    configuration: {
      appId: 'MySnapshotApp'
      eventSourcing: {
        snapshotting: {
          enabled: true,
          frequency: 2
        }
      }
    }
    onStart: ->
      @snapshotter = @injector.get('Space.eventSourcing.Snapshotter')
      @snapshots = @snapshotter.collection

  beforeEach ->
    # Test aggregate
    @aggregateId = '123'
    @aggregate = new MySnapshotAggregate @aggregateId
    @aggregate.test = 'test'
    # Test app
    @myApp = new MySnapshotApp()
    @myApp.start()
    # Expose tested components
    @snapshotter = @myApp.snapshotter
    @collection = @myApp.snapshotter.collection
    @collection.remove {}

  afterEach ->
    @myApp.stop()

  describe 'making snapshots', ->

    it 'saves the current state of the aggregate', ->
      @aggregate._version = @myApp.configuration.eventSourcing.snapshotting.frequency
      @snapshotter.makeSnapshotOf @aggregate
      expect(@collection.findOne()).toMatch {
        _id: @aggregateId
        snapshot: EJSON.stringify(@aggregate.getSnapshot())
      }

    it 'skips snapshot if not enough versions have passed', ->
      # Simulate a previous snapshot at version 1
      firstSnapshot = @aggregate.getSnapshot()
      @collection.insert {
        _id: @aggregateId
        snapshot: EJSON.stringify(firstSnapshot)
      }

      # Increase aggregate version + 1 (not enough for the frequency)
      @aggregate._version = 1
      @snapshotter.makeSnapshotOf @aggregate

      # No snapshot should have been taken!
      expect(@collection.findOne()).toMatch {
        _id: @aggregateId
        snapshot: EJSON.stringify(firstSnapshot)
      }

    it 'makes snapshot when enough versions have passed', ->
      # Simulate a previous snapshot at version 1
      @aggregate._version = 1
      @collection.insert {
        _id: @aggregateId
        snapshot: EJSON.stringify(@aggregate.getSnapshot())
      }

      # Increase aggregate version + 2 (enough for the frequency)
      @aggregate._version = 3
      @snapshotter.makeSnapshotOf @aggregate

      # Snapshot should have been taken!
      expect(@collection.findOne()).toMatch {
        _id: @aggregateId
        snapshot: EJSON.stringify(@aggregate.getSnapshot())
      }

  describe 'getting latest snapshot of aggregate', ->

    it 'creates and returns an aggregate instance based on the snapshot', ->

      # Simulate a previous snapshot at version 1
      @collection.insert {
        _id: @aggregateId
        snapshot: EJSON.stringify(@aggregate.getSnapshot())
      }

      aggregate = @snapshotter.getSnapshotOf MySnapshotAggregate, @aggregateId

      expect(aggregate).to.be.instanceOf MySnapshotAggregate
      expect(aggregate.getVersion()).to.equal @aggregate.getVersion()
      expect(aggregate.getState()).to.equal @aggregate.getState()
      expect(aggregate.getSnapshot()).toMatch @aggregate.getSnapshot()
