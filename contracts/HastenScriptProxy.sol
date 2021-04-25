pragma solidity ^0.8.0;

import "openzeppelin-solidity/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract HastenScriptProxy is TransparentUpgradeableProxy {
    constructor()
        TransparentUpgradeableProxy(
            address(0xC0DE00ce4dc54b06BEa5EB116E4D6eF1e0A5Df49), // logic - to setup
            address(0xC0ffee4B437CcF6C7cE62E517D94e48c0389d1Eb), // admin
            new bytes(0)
        )
    {}
}
