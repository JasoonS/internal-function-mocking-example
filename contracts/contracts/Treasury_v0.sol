// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.3;

import "./abstract/AccessControlledAndUpgradeable.sol";

/** @title Treasury Contract */
contract Treasury_v0 is AccessControlledAndUpgradeable {
  /*╔══════════════════════════════╗
    ║        CONTRACT SETUP        ║
    ╚══════════════════════════════╝*/

  function initialize(address _admin) external initializer {
    _AccessControlledAndUpgradeable_init(_admin);
  }

  /** To be upgraded in future allowing governance of treasury 
    and its funds */
}
