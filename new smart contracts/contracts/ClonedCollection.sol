/// SPDX-License-Identifier: BUSL-1.1
/// Copyright © 2022 Fragcolor Pte. Ltd.

pragma solidity ^0.8.13;

import {Clone} from "clones-with-immutable-args/Clone.sol";
import {Collection} from "./Collection.sol";

/// @title A Fragnova Collection
/// @notice To sell a Fragnova Collection Smart Contract on OpenSea, the owner of the contract must register the contract on the OpenSea Registry (https://etherscan.io/address/0x000000000000AAeB6D7670E522A718067333cd4E#code) by either calling `register()`, `registerAndSubscribe()` or `registerAndCopyEntries()` .
/// @notice To stop selling on OpenSea, the owner of the contract must unregister the contract on the OpenSea Registry by calling `unregister()`.
/// @notice The OperatorFilter checks can be bypassed if you calls the function `updateOperatorFilterRegistryAddress()`.
contract ClonedCollection is Collection, Clone {
    function _getArgBytes32(uint256 argOffset)
        internal
        pure
        returns (bytes32 arg)
    {
        uint256 offset = _getImmutableArgsOffset();
        // solhint-disable-next-line no-inline-assembly
        assembly {
            arg := calldataload(add(offset, argOffset))
        }
    }

    function merkleRoot() public pure returns (bytes32) {
        return _getArgBytes32(0);
    }

    function owner() public pure override returns (address) {
        return _getArgAddress(32);
    }

    function name() public pure override returns (string memory) {
        return string(abi.encodePacked(_getArgBytes32(52)));
    }

    function symbol() public pure override returns (string memory) {
        return string(abi.encodePacked(_getArgBytes32(84)));
    }

    function transferOwnership(address) public pure override {
        revert("A Fragnova Collection's ownership can never be transferred");
    }

    function renounceOwnership() public pure override {
        revert("A Fragnova Collection's ownership can not be renounced");
    }
}
