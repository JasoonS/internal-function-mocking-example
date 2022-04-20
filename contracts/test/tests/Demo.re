open LetOps;
open Mocha;
open Globals;
open SmockGeneral;
let functionInput = Helpers.randomInteger();
let degen1Return = Helpers.randomInteger();
let degen2Return = Helpers.randomInteger();

describeUnit("example", () => {
  it_only("internal mock", () => {
    let%AwaitThen exampleContract = InternalMockExample.Exposed.makeSmock();
    let%AwaitThen _ =
      exampleContract->InternalMockExampleSmocked.InternalMock.setup;

    let%AwaitThen _ =
      exampleContract->InternalMockExampleSmocked.InternalMock.setupFunctionForUnitTesting(
        ~functionName="_internalFunctionToReduceCodeDuplication",
      );

    let%AwaitThen degenProtocol2Smocked = DegenProtocolSmocked.make();
    let%AwaitThen _ =
      exampleContract->InternalMockExample.Exposed.setDegenProtocol2(
        ~degenProtocol2=degenProtocol2Smocked.address,
      );

    InternalMockExampleSmocked.InternalMock.mock_doSomethingDegenToReturn(
      degen1Return,
    );

    degenProtocol2Smocked->DegenProtocolSmocked.mockDegenFunctionToReturn(
      degen2Return,
    );

    let%Await functionReturnValue =
      exampleContract->InternalMockExample.Exposed._internalFunctionToReduceCodeDuplicationExposedCall(
        ~inputNumber=functionInput,
      );

    degenProtocol2Smocked->DegenProtocolSmocked.degenFunctionCallCheck({
      someValue: degen1Return,
    });

    InternalMockExampleSmocked.InternalMock._doSomethingDegenCallCheck({
      inputNumber: functionInput,
    });

    Chai.bnEqual(functionReturnValue, degen2Return);
  })
});
