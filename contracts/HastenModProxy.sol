pragma solidity ^0.8.0;

import "openzeppelin-solidity/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract HastenModProxy is TransparentUpgradeableProxy {
    constructor()
        TransparentUpgradeableProxy(
            address(0xC0DE00D0Fd0Af66d767D3dD13B01EeEa9Ef213AB), // logic
            address(0xC0FFEEaAd4F914eD5eC6c87DfCE1e453fC16646A), // admin
            new bytes(0)
        )
    {}
}
