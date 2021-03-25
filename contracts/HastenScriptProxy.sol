pragma solidity ^0.8.0;

import "openzeppelin-solidity/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract HastenScriptProxy is TransparentUpgradeableProxy {
    constructor()
        TransparentUpgradeableProxy(
            address(0xC0DE00d21d6fd31F4A4d4804bc678428DA9ab545), // logic
            address(0xC0ffee4B437CcF6C7cE62E517D94e48c0389d1Eb), // admin
            new bytes(0)
        )
    {}
}
