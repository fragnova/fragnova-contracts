pragma solidity ^0.8.0;

import "openzeppelin-solidity/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract HastenScriptProxy is TransparentUpgradeableProxy {
    constructor()
        TransparentUpgradeableProxy(
            address(0xC0DE0006b9055df6f94E971471F46F894a0E5B1F), // logic
            address(0xC0ffee4B437CcF6C7cE62E517D94e48c0389d1Eb), // admin
            new bytes(0)
        )
    {}
}
