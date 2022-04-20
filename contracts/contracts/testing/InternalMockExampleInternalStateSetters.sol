// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.13;

import "../demo/InternalMockExample.sol";

/*
NOTE: This contract is for testing purposes only!
*/

contract InternalMockExampleInternalStateSetters is InternalMockExample {
  function setDegenProtocol2(DegenProtocol _degenProtocol2) external {
    degenProtocol2 = _degenProtocol2;
  }
}
