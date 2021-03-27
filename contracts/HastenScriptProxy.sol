pragma solidity ^0.8.0;

import "openzeppelin-solidity/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract HastenScriptProxy is TransparentUpgradeableProxy {
    constructor()
        TransparentUpgradeableProxy(
            address(0xC0DE00Eb3F0F006D54c878bD27063025f6D48b2c), // logic
            address(0xC0ffee4B437CcF6C7cE62E517D94e48c0389d1Eb), // admin
            new bytes(0)
        )
    {}
}
