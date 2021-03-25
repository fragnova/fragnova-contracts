pragma solidity ^0.8.0;

import "openzeppelin-solidity/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract HastenScriptProxy is TransparentUpgradeableProxy {
    constructor()
        TransparentUpgradeableProxy(
            address(0xC0DE00d21d6fd31F4A4d4804bc678428DA9ab545), // logic
            address(0xC0FFee00b68f0F079d904844b49a064E3046AE91), // admin
            new bytes(0)
        )
    {}
}
