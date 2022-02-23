/* SPDX-License-Identifier: BUSL-1.1 */
/* Copyright © 2021 Fragcolor Pte. Ltd. */

pragma solidity ^0.8.7;

import "./RezProxy.sol";
import "openzeppelin-solidity/contracts/utils/Strings.sol";

contract Utility {
    using Strings for uint256;

    bytes private constant METADATA_URI = "https://meta-proxy.fragnova.com/";

    bytes private constant IMG_URI = "https://img-proxy.fragnova.com/";

    // This flag is used in rezzed contracts to determine the owner() call result
    // for now NFT marketplaces are a wildwest and we need to override it with our addresses in order to be able to ensure royalties distribution
    bool private constant _overrideOwner = true;

    function overrideOwner() external pure returns (bool) {
        return _overrideOwner;
    }

    function toAsciiString(address x) internal pure returns (string memory) {
        bytes memory s = new bytes(40);
        for (uint256 i = 0; i < 20; i++) {
            bytes1 b = bytes1(uint8(uint256(uint160(x)) / (2**(8 * (19 - i)))));
            bytes1 hi = bytes1(uint8(b) / 16);
            bytes1 lo = bytes1(uint8(b) - 16 * uint8(hi));
            s[2 * i] = char(hi);
            s[2 * i + 1] = char(lo);
        }
        return string(s);
    }

    function char(bytes1 b) internal pure returns (bytes1 c) {
        if (uint8(b) < 10) return bytes1(uint8(b) + 0x30);
        else return bytes1(uint8(b) + 0x57);
    }

    function _getChainId() private view returns (uint256) {
        uint256 id;
        assembly {
            id := chainid()
        }
        return id;
    }

    /// @notice Build and return the metadata URI for Proto-Fragment whose hash is `fragmentHash`
    function buildFragmentMetadata(bytes32 fragmentHash)
        public
        pure
        returns (string memory metadata)
    {
        bytes memory query = abi.encodePacked(
            METADATA_URI,
            "?f=",
            uint256(fragmentHash).toHexString()
        );

        return string(query);
    }

    function buildFragmentRootMetadata(
        address vaultAddress,
        uint256 feeBasisPoints
    ) public pure returns (string memory metadata) {
        bytes memory data = abi.encodePacked(
            'data:application/json,{"name":"Fragments%20Asset%20Store",',
            '"description":"Fragments%20Asset%20Store",',
            '"seller_fee_basis_points":',
            feeBasisPoints.toString(),
            ",",
            '"fee_recipient":"0x',
            toAsciiString(vaultAddress),
            '",',
            '"image":"',
            IMG_URI,
            'fragments-logo.png",',
            '"external_link":"https://fragnova.com"}'
        );

        return string(data);
    }

    /// @notice Build and return the metadata URI for the Entity/Fragment whose Token ID is `id`
    /// @param id - The Token ID of the Entity/Fragment
    /// @param mutableHash - ¿
    /// @param entityID - The Entity Contract Address
    /// @param dataBlock - The block number where the Entity was last modified
    /// @dev Returns a string in the following format "{METADATA_URI}?ch={_getChainId().toHexString()}&id={id.toHexString()}
    ///         &e=0x{toAsciiString(entityId)}&m={uint256(mutableHash).toHexString()}&d={dataBlock.toHexString()}"
    function buildEntityMetadata(
        uint256 id,
        bytes32 mutableHash,
        address entityId,
        uint256 dataBlock
    ) public view returns (string memory metadata) {
        bytes memory query = abi.encodePacked(
            METADATA_URI,
            "?ch=",
            _getChainId().toHexString(),
            "&id=",
            id.toHexString(),
            "&e=0x",
            toAsciiString(entityId),
            "&m=",
            uint256(mutableHash).toHexString(),
            "&d=",
            dataBlock.toHexString()
        );

        return string(query);
    }

    /// @notice Returns a JSON containing the paramater names and values
    /// @param name Entity/Fragment Contract's Name
    /// @param desc Entity/Fragment Contract's Description
    /// @param url Entity/Fragment Contract's URL
    /// @param vaultAddress The Address of the Vault Contract that corresponds to the Entity/Fragment Contract
    /// @param feeBasisPoints The Royalty Rate (in basis points)
    function buildEntityRootMetadata(
        string memory name,
        string memory desc,
        string memory url,
        address vaultAddress,
        uint256 feeBasisPoints
    ) public pure returns (string memory metadata) {
        bytes memory data = abi.encodePacked(
            'data:application/json,{"name":"',
            name,
            '",',
            '"description":"',
            desc,
            '",',
            '"seller_fee_basis_points":',
            feeBasisPoints.toString(),
            ",",
            '"fee_recipient":"0x',
            toAsciiString(vaultAddress),
            '",',
            '"image":"',
            abi.encodePacked(url, "/entity-logo.png"),
            '",',
            '"external_link":"',
            url,
            '"}'
        );

        return string(data);
    }
}
