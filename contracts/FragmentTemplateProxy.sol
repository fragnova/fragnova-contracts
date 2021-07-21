pragma solidity ^0.8.0;

import "openzeppelin-solidity/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract FragmentTemplateProxy is TransparentUpgradeableProxy {
    constructor()
        TransparentUpgradeableProxy(
            address(0xc2ea7e101363Fc9c6f04d55414F8c2f87B9a7981), // logic
            address(0xC0FFEEaAd4F914eD5eC6c87DfCE1e453fC16646A), // admin
            new bytes(0)
        )
    {}
}
