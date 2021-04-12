pragma solidity ^0.8.0;

import "openzeppelin-solidity/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract HastenModProxy is TransparentUpgradeableProxy {
    constructor()
        TransparentUpgradeableProxy(
            address(0xC0DE00D0Fd0Af66d767D3dD13B01EeEa9Ef213AB), // logic
            address(0xC0ffee4B437CcF6C7cE62E517D94e48c0389d1Eb), // admin
            new bytes(0)
        )
    {}
}
