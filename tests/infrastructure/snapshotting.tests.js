describe("Space.eventSourcing - snapshotting", function() {

  beforeEach(function() {
    this.registrationId = 'registration123';
    this.customerId = 'customer543';
    this.customerName = 'TestName';
    this.app = new Test.App();
    this.app.reset();
  });

  it("generates correct snapshots", function() {
    this.app.start();
    this.app.send(new Test.RegisterCustomer({
      targetId: this.registrationId,
      customerId: this.customerId,
      customerName: this.customerName
    }));
    const snapshots = this.app.injector.get('Space.eventSourcing.Snapshots').find().fetch();
    const customerRegSnapshot = EJSON.parse(snapshots[0].snapshot);
    const customerSnapshot = EJSON.parse(snapshots[1].snapshot);
    expect(customerRegSnapshot).toMatch({ id: 'registration123',
      version: 3,
      state: 'completed',
      customerId: 'customer543',
      customerName: 'TestName'
    });
    expect(customerSnapshot).toMatch({
      id: 'customer543',
      version: 1,
      state: null,
      name: 'TestName'
    });
  });

});
