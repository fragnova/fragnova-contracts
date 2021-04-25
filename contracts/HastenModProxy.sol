pragma solidity ^0.8.0;

import "openzeppelin-solidity/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract HastenModProxy is TransparentUpgradeableProxy {
    constructor()
        TransparentUpgradeableProxy(
            address(0xc2ea7eb415Feb6E28544b729c9679bdB2d851024), // logic
            address(0xC0FFEEaAd4F914eD5eC6c87DfCE1e453fC16646A), // admin
            new bytes(0)
        )
    {}
}
