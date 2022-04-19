// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.13;

contract Demo {

  DegenProtocol immutable degenProtocol1;
  DegenProtocol immutable degenProtocol2;

  constructor () {
   degenProtocol1 = new DegenProtocol();
   degenProtocol2 = new DegenProtocol();
  }

  function _doSomethingDegen(uint256 inputNumber) internal returns (uint256 numberGoUp) {
    degenProtocol1.degenFunction(inputNumber);
    return inputNumber + 5; // Number must go up!
  }

  function _internalFunctionToReduceCodeDuplication(uint256 inputNumber) internal {
    uint256 result = _doSomethingDegen(inputNumber);

    degenProtocol2.degenFunction(result);
  }

  function makeNumberGoUp(uint256 inputNumber) external {
    _internalFunctionToReduceCodeDuplication(inputNumber);
  }
}

contract DegenProtocol {
  uint256 someValue;

  function degenFunction(uint256 _someValue) external {
    someValue = _someValue;
  }
}
