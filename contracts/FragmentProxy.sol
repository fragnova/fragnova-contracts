/* SPDX-License-Identifier: BUSL-1.1 */
/* Copyright © 2021 Fragcolor Pte. Ltd. */

pragma solidity ^0.8.7;

import "openzeppelin-solidity/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract FragmentProxy is TransparentUpgradeableProxy {
    constructor()
        TransparentUpgradeableProxy(
            address(0xC0DE0BA1f4b227339AFe5b34C9657FA01bb93f4b), // logic
            address(0xC0FFEEaAd4F914eD5eC6c87DfCE1e453fC16646A), // admin
            new bytes(0)
        )
    {}
}
