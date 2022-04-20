// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import "@float-capital/ds-test/src/test.sol";
import "../testing/generated/InternalMockExampleForInternalMocking.sol";
import "../testing/generated/InternalMockExampleMockable.sol";

interface CheatCodes {
  function mockCall(
    address,
    bytes calldata,
    bytes calldata
  ) external;

  function assume(bool) external;
}

contract ExampleTest is DSTest {
  CheatCodes cheats = CheatCodes(HEVM_ADDRESS);
  InternalMockExampleForInternalMocking mocker =
    InternalMockExampleForInternalMocking(address(123));

  function setUp() public {}

  function testExample(
    uint256 exampleInput,
    uint256 degenAction1Output,
    uint256 degenAction2Output
  ) public {
    cheats.assume(degenAction1Output > exampleInput);
    cheats.assume(exampleInput < 0x0fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0);

    InternalMockExampleMockable contractToTest = new InternalMockExampleMockable();

    contractToTest.setMocker(mocker);
    contractToTest.setFunctionToNotMock("_internalFunctionToReduceCodeDuplication");

    cheats.mockCall(
      address(mocker),
      abi.encodeWithSelector(
        InternalMockExampleForInternalMocking._doSomethingDegenMock.selector,
        exampleInput
      ),
      abi.encode(degenAction1Output)
    );

    cheats.mockCall(
      address(mocker),
      abi.encodeWithSelector(
        InternalMockExampleForInternalMocking._doSomethingDegenMock.selector,
        exampleInput
      ),
      abi.encode(degenAction1Output)
    );

    cheats.mockCall(
      address(contractToTest.degenProtocol2()),
      abi.encodeWithSelector(DegenProtocol.degenFunction.selector, degenAction1Output),
      abi.encode(degenAction2Output)
    );

    uint256 result = contractToTest._internalFunctionToReduceCodeDuplicationExposed(exampleInput);

    assert(result == degenAction2Output);
  }
}
