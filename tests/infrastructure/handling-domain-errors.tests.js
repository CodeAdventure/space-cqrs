describe("Space.eventSourcing - Handling domain errors", function() {

  it("publishes them as exception event", function() {
    const registrationId = 'reg123';
    Test.App.test(Test.Customer)
    .given(
      new Test.RegisterCustomer({
        targetId: registrationId,
        customerId: 'cust123',
        customerName: 'MyStrangeCustomerName'
      })
    )
    .expect([
      new Space.domain.Exception({
        thrower: 'Test.CustomerRegistration',
        error: new Test.InvalidCustomerName('MyStrangeCustomerName')
      })
    ]);
  });

});
