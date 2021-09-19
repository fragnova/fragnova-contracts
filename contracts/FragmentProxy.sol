/* SPDX-License-Identifier: BUSL-1.1 */
/* Copyright © 2021 Fragcolor Pte. Ltd. */

pragma solidity ^0.8.7;

import "openzeppelin-solidity/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract FragmentProxy is TransparentUpgradeableProxy {
    constructor()
        TransparentUpgradeableProxy(
            address(0xeA5914012124BafFE6C44Af723C21B6023189e77), // logic
            address(0x4F3A5C59E65219138c1cF66308EbD81dF08d45Aa), // admin
            new bytes(0)
        )
    {}
}
