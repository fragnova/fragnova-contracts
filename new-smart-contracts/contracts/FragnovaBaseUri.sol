/// SPDX-License-Identifier: BUSL-1.1
/// Copyright © 2022 Fragcolor Pte. Ltd.

pragma solidity ^0.8.0;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract FragnovaBaseUri is Initializable, UUPSUpgradeable, OwnableUpgradeable {

    /// @notice Base URI for retrieving Metadata Information
    string public baseUri;

    /// @dev TIP: To avoid leaving the proxy in an uninitialized state, the initializer function should be called as early as possible by providing the encoded function call as the `_data` argument to {ERC1967Proxy-constructor}.
    function initialize() external initializer {
        __Ownable_init();
    }

    /// @inheritdoc UUPSUpgradeable
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {

    }

    /// @notice **Set** the **Base URI for retrieving Metadata Information**
    function setBaseUri(string memory baseUri_) external {
        baseUri = baseUri_;
    }

}
