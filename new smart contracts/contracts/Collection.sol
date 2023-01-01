/// SPDX-License-Identifier: BUSL-1.1
/// Copyright © 2022 Fragcolor Pte. Ltd.

pragma solidity ^0.8.13;

import {ERC721A} from "erc721a/contracts/ERC721A.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {FragnovaBaseUri} from "./FragnovaBaseUri.sol";
import {UpdatableOperatorFilterer} from "operator-filter-registry/src/UpdatableOperatorFilterer.sol";
import {ERC2981} from "@openzeppelin/contracts/token/common/ERC2981.sol";
import "hardhat/console.sol";

address constant OPENSEA_REGISTRY = address(
    0x000000000000AAeB6D7670E522A718067333cd4E
);
address constant DEFAULT_OPENSEA_SUBSCRIPTION = address(
    0x3cc6CddA760b79bAfa08dF41ECFA224f810dCeB6
);

contract Collection is
    Ownable,
    ERC721A("", ""),
    UpdatableOperatorFilterer(
        OPENSEA_REGISTRY,
        DEFAULT_OPENSEA_SUBSCRIPTION,
        true
    ),
    ERC2981
{
    /// @notice Price of minting an element in the collection
    uint256 public mintPrice;

    /// @dev This is non-`constant` only for testing purposes
    FragnovaBaseUri public baseUriProxy;

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721A, ERC2981)
        returns (bool)
    {
        return
            ERC721A.supportsInterface(interfaceId) ||
            ERC2981.supportsInterface(interfaceId);
    }

    /// @inheritdoc Ownable
    function owner()
        public
        view
        virtual
        override(Ownable, UpdatableOperatorFilterer)
        returns (address)
    {
        return Ownable.owner();
    }

    /// @dev `baseUriProxy` is non-`constant` only for testing purposes
    function setBaseUriProxy(FragnovaBaseUri baseUriProxy_) external onlyOwner {
        baseUriProxy = baseUriProxy_;
    }

    modifier paysMintPrice() {
        require(msg.value >= mintPrice, "Mint price not paid");
        _;
    }

    /// @notice Set the Mint-Price
    function setMintPrice(uint256 mintPrice_) external onlyOwner {
        mintPrice = mintPrice_;
    }

    /// @inheritdoc ERC721A
    function _baseURI() internal view override returns (string memory) {
        return baseUriProxy.baseUri();
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

    /// @notice Set the Royalty Info of this ERC-721 Contract
    function setRoyaltyInfo(address receiver, uint96 feeInBips)
        external
        onlyOwner
    {
        _setDefaultRoyalty(receiver, feeInBips);
    }
}
