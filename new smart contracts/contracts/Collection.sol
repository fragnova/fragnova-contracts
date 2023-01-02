/// SPDX-License-Identifier: BUSL-1.1
/// Copyright © 2022 Fragcolor Pte. Ltd.

pragma solidity ^0.8.13;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "./OwnableUpgradeable.sol";
import {UpdatableOperatorFilterer} from "operator-filter-registry/src/UpdatableOperatorFilterer.sol";
import {MerkleRootNFT} from "./MerkleRootNFT.sol";
import {ERC2981} from "@openzeppelin/contracts/token/common/ERC2981.sol";
import {IOperatorFilterRegistry} from "operator-filter-registry/src/IOperatorFilterRegistry.sol";
import {ERC721A} from "erc721a/contracts/ERC721A.sol";

/* Graph of inheritance (Note: "NFT" is short for "MerkleRootNFT")

OwnableUpgradeable    UpdatableOperatorFilterer
            \     \  /      /
             \    NFT     /
              \    |    /
               Collection

*/
/// @title A Fragnova Collection
/// @author Fragcolor Pte. Ltd.
/// @notice To sell a Fragnova Collection Smart Contract on OpenSea, the owner of the contract must register the contract on the OpenSea Registry (https://etherscan.io/address/0x000000000000AAeB6D7670E522A718067333cd4E#code) by either calling `register()`, `registerAndSubscribe()` or `registerAndCopyEntries()` .
/// @notice To stop selling on OpenSea, the owner of the contract must unregister the contract on the OpenSea Registry by calling `unregister()`.
/// @notice The OperatorFilter checks can be bypassed if you calls the function `updateOperatorFilterRegistryAddress()`.
contract Collection is
    Initializable,
    OwnableUpgradeable,
    UpdatableOperatorFilterer,
    MerkleRootNFT,
    ERC2981
{
    /// @notice OpenSea's Operator Filter Registry (https://github.com/ProjectOpenSea/operator-filter-registry#deployments)
    address constant OPENSEA_FILTER_REGISTRY =
        address(0x000000000000AAeB6D7670E522A718067333cd4E);
    /// @notice OpenSea's Curated Subscription Address (https://github.com/ProjectOpenSea/operator-filter-registry#deployments)
    address constant DEFAULT_OPENSEA_SUBSCRIPTION =
        address(0x3cc6CddA760b79bAfa08dF41ECFA224f810dCeB6);
    /// @notice Price of minting an element in the collection
    uint256 public mintPrice;

    /// @notice This should never run
    constructor()
        UpdatableOperatorFilterer(
            OPENSEA_FILTER_REGISTRY,
            DEFAULT_OPENSEA_SUBSCRIPTION,
            true
        )
        ERC721A("", "")
    {}

    /// @notice The de-factor constructor
    /// @dev This function has not been tested when `shouldRegisterWithOpenseaFilterRegistry` is true
    function initialize(
        address initialOwner,
        bool shouldRegisterWithOpenseaFilterRegistry
    ) external initializer {
        __Ownable_init(initialOwner);

        if (shouldRegisterWithOpenseaFilterRegistry) {
            // If a token contract is deployed to a network without the registry deployed, the modifier
            // will not revert, but the contract will need to be registered with the registry once it is deployed in
            // order for the modifier to filter addresses.
            if (OPENSEA_FILTER_REGISTRY.code.length > 0) {
                IOperatorFilterRegistry registry = IOperatorFilterRegistry(
                    OPENSEA_FILTER_REGISTRY
                );
                operatorFilterRegistry = registry;

                registry.registerAndSubscribe(
                    address(this),
                    DEFAULT_OPENSEA_SUBSCRIPTION
                );
            }
        }
    }

    /// @inheritdoc OwnableUpgradeable
    function owner()
        public
        view
        override(OwnableUpgradeable, UpdatableOperatorFilterer, MerkleRootNFT)
        returns (address)
    {
        return OwnableUpgradeable.owner();
    }

    /// @inheritdoc ERC2981
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

    /// @notice Set the Royalty Info of this ERC-721 Contract
    function setRoyaltyInfo(address receiver, uint96 feeInBips)
        external
        onlyOwner
    {
        _setDefaultRoyalty(receiver, feeInBips);
    }

    /// @notice Revert if mint price is not paid
    modifier paysMintPrice() {
        require(msg.value >= mintPrice, "Mint price not paid");
        _;
    }

    /// @notice Set the Mint Price
    function setMintPrice(uint256 mintPrice_) external onlyOwner {
        mintPrice = mintPrice_;
    }
}
