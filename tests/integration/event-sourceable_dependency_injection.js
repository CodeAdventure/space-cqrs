describe("Space.eventSourcing.Aggregate - dependency injection", function() {

  beforeEach(function (){
    CustomerApp.myAggregateDependency = sinon.spy();

    this.app = new CustomerApp();
    this.app.reset();
  });

  it("injects dependency into new aggregate", function() {
    let command = new CustomerApp.CreateCustomer({
      targetId: new Guid(),
      name: 'MyStrangeCustomerName'
    });

    this.app.start();
    this.app.commandBus.send(command);

    expect(CustomerApp.myAggregateDependency).to.have.been.calledOnce;
  });

  it("injects dependency into existing aggregate", function() {
    customerId = new Guid()
    let createCommand = new CustomerApp.CreateCustomer({
      targetId: customerId,
      name: 'MyStrangeCustomerName'
    });
    let changeCommand = new CustomerApp.ChangeCustomerName({
      targetId: customerId,
      name: 'MyEvenStrangerCustomerName'
    });

    this.app.start();
    this.app.commandBus.send(createCommand);
    this.app.commandBus.send(changeCommand);

    expect(CustomerApp.myAggregateDependency).to.have.been.callCount(2);
  });
});

describe("Space.eventSourcing.Process - dependency injection", function() {

  beforeEach(function (){
    CustomerApp.myProcessDependency = sinon.spy();
    CustomerApp.myAggregateDependency = sinon.spy();

    this.registrationId = 'registration123';
    this.customerId = 'customer543';
    this.customerName = 'TestName';

    this.app = new CustomerApp();
    this.app.reset();
  });

  it("injects dependency into process", function() {
    let command = new CustomerApp.RegisterCustomer({
      targetId: this.registrationId,
      customerId: this.customerId,
      customerName: this.customerName
    });

    this.app.start();
    this.app.commandBus.send(command);

    expect(CustomerApp.myProcessDependency).to.have.been.calledThrice;
    expect(CustomerApp.myAggregateDependency).to.have.been.calledOnce;
  });
});