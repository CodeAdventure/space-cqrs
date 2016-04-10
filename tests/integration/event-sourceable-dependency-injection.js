describe("Space.eventSourcing.Aggregate - dependency injection", function() {

  beforeEach(function (){
    Test.myAggregateDependency = sinon.spy();

    this.app = new Test.App();
    this.app.reset();
  });

  it("injects dependency into new aggregate", function() {
    let command = new Test.CreateCustomer({
      targetId: new Guid(),
      name: 'MyStrangeCustomerName'
    });

    this.app.start();
    this.app.commandBus.send(command);

    expect(Test.myAggregateDependency).to.have.been.calledOnce;
  });

  it("injects dependency into existing aggregate", function() {
    customerId = new Guid()

    let createCommand = new Test.CreateCustomer({
      targetId: customerId,
      name: 'MyStrangeCustomerName'
    });
    let changeCommand = new Test.ChangeCustomerName({
      targetId: customerId,
      name: 'MyEvenStrangerCustomerName'
    });

    this.app.start();
    this.app.commandBus.send(createCommand);
    this.app.commandBus.send(changeCommand);

    expect(Test.myAggregateDependency).to.have.been.callCount(2);
  });
});

describe("Space.eventSourcing.Process - dependency injection", function() {

  beforeEach(function (){
    Test.myProcessDependency = sinon.spy();
    Test.myAggregateDependency = sinon.spy();

    this.registrationId = 'registration123';
    this.customerId = 'customer543';
    this.customerName = 'TestName';

    this.app = new Test.App();
    this.app.reset();
  });

  it("injects dependency into process", function() {
    let command = new Test.RegisterCustomer({
      targetId: this.registrationId,
      customerId: this.customerId,
      customerName: this.customerName
    });

    this.app.start();
    this.app.commandBus.send(command);

    expect(Test.myProcessDependency).to.have.been.calledThrice;
    expect(Test.myAggregateDependency).to.have.been.calledOnce;
  });
});