pragma solidity ^0.8.0;

import "openzeppelin-solidity/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract FragmentTemplateProxy is TransparentUpgradeableProxy {
    constructor()
        TransparentUpgradeableProxy(
            address(0xC0DE00ce4dc54b06BEa5EB116E4D6eF1e0A5Df49), // logic
            address(0xC0FFEEaAd4F914eD5eC6c87DfCE1e453fC16646A), // admin
            new bytes(0)
        )
    {}
}
