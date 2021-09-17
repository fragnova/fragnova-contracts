/* SPDX-License-Identifier: BUSL-1.1 */
/* Copyright © 2021 Fragcolor Pte. Ltd. */

pragma solidity ^0.8.7;

import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";

contract FragmentDAOToken is ERC20 {
    uint256 constant INITIAL_SUPPLY = 100000000 * (10 ** 18);

    constructor() ERC20("Fragments Foundation Token", "FRAG") {
        _mint(msg.sender, INITIAL_SUPPLY);
    }
}
