pragma solidity ^0.7.4;

import "openzeppelin-solidity/contracts/proxy/TransparentUpgradeableProxy.sol";

contract HastenScriptProxy is TransparentUpgradeableProxy {
    constructor()
        TransparentUpgradeableProxy(
            address(0), // logic
            address(0xC0FFee00b68f0F079d904844b49a064E3046AE91), // admin
            new bytes(0)
        )
    {}
}
