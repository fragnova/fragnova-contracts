/// SPDX-License-Identifier: BUSL-1.1
/// Copyright © 2022 Fragcolor Pte. Ltd.

pragma solidity ^0.8.13;

import {ERC721A} from "erc721a/contracts/ERC721A.sol";
import {OwnableUpgradeable} from "./OwnableUpgradeable.sol";
import {UpdatableOperatorFilterer} from "operator-filter-registry/src/UpdatableOperatorFilterer.sol";
import {Clone} from "clones-with-immutable-args/Clone.sol";
import {FragnovaBaseUri} from "./FragnovaBaseUri.sol";

abstract contract MerkleRootNFT is ERC721A, OwnableUpgradeable, UpdatableOperatorFilterer, Clone {
    /// @dev This is not `constant` only for testing purposes
    FragnovaBaseUri public baseUriProxy;

    /// @inheritdoc OwnableUpgradeable
    function owner() public view
    virtual
    override(OwnableUpgradeable, UpdatableOperatorFilterer)
    returns (address)
    {
        return OwnableUpgradeable.owner();
    }

    /// @dev `baseUriProxy` is not `constant` only for testing purposes
    function setBaseUriProxy(FragnovaBaseUri _baseUriProxy) external onlyOwner {
        baseUriProxy = _baseUriProxy;
    }

    /// @inheritdoc ERC721A
    function _baseURI() internal view override returns (string memory) {
        return baseUriProxy.baseUri();
    }

    /// @notice Reads an immutable arg with type bytes32
    /// @param argOffset The offset of the arg in the packed data
    /// @return arg The arg value
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

    /// @notice Get the Merkle Root of this Fragnova Collection
    function merkleRoot() public pure returns (bytes32) {
        return _getArgBytes32(0);
    }

    /// @inheritdoc ERC721A
    function name() public pure override returns (string memory) {
        return string(abi.encodePacked(_getArgBytes32(32)));
    }

    /// @inheritdoc ERC721A
    function symbol() public pure override returns (string memory) {
        return string(abi.encodePacked(_getArgBytes32(64)));
    }

    /// @inheritdoc ERC721A
    function setApprovalForAll(address operator, bool approved)
        public
        override
        onlyAllowedOperatorApproval(operator)
    {
        super.setApprovalForAll(operator, approved);
    }

    /// @inheritdoc ERC721A
    function approve(address operator, uint256 tokenId)
        public
        payable
        override
        onlyAllowedOperatorApproval(operator)
    {
        super.approve(operator, tokenId);
    }

    /// @inheritdoc ERC721A
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public payable override onlyAllowedOperator(from) {
        super.transferFrom(from, to, tokenId);
    }

    /// @inheritdoc ERC721A
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public payable override onlyAllowedOperator(from) {
        super.safeTransferFrom(from, to, tokenId);
    }

    /// @inheritdoc ERC721A
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public payable override onlyAllowedOperator(from) {
        super.safeTransferFrom(from, to, tokenId, data);
    }
}
