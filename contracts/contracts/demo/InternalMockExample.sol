// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.13;

import "hardhat/console.sol";

contract InternalMockExample {
  DegenProtocol public immutable degenProtocol1;
  DegenProtocol public degenProtocol2;

  constructor() {
    degenProtocol1 = new DegenProtocol();
    degenProtocol2 = new DegenProtocol();
  }

  function _doSomethingDegen(uint256 inputNumber) internal virtual returns (uint256 numberGoUp) {
    return degenProtocol1.degenFunction(inputNumber);
  }

  function _internalFunctionToReduceCodeDuplication(uint256 inputNumber)
    internal
    virtual
    returns (uint256)
  {
    console.log("input", inputNumber);
    uint256 result = _doSomethingDegen(inputNumber);

    console.log("result", result);

    return degenProtocol2.degenFunction(result);
  }

  function makeNumberGoUp(uint256 inputNumber) external returns (uint256) {
    return _internalFunctionToReduceCodeDuplication(inputNumber);
  }
}

contract DegenProtocol {
  uint256 someValue;

  function degenFunction(uint256 _someValue) external returns (uint256) {
    someValue = _someValue;
    return someValue + 5;
  }
}
