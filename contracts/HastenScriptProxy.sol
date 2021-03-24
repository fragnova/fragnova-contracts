pragma solidity ^0.8.0;

import "openzeppelin-solidity/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract HastenScriptProxy is TransparentUpgradeableProxy {
    constructor()
        TransparentUpgradeableProxy(
            address(0xC0DE77CE9A83B7ec9520FbA3Ca349b2cEE3a5CcC), // logic
            address(0xC0FFee00b68f0F079d904844b49a064E3046AE91), // admin
            new bytes(0)
        )
    {}
}
