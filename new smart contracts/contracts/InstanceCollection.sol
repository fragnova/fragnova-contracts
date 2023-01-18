/// SPDX-License-Identifier: BUSL-1.1
/// Copyright © 2022 Fragcolor Pte. Ltd.

pragma solidity ^0.8.13;

// We import these contracts to `@inheritdoc`
import {ERC721A} from "erc721a/contracts/ERC721A.sol";

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {NotProofRead, Mask} from "./Libraries.sol";

import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {Collection} from "./Collection.sol";

contract InstanceCollection is Collection {
    using NotProofRead for bytes;
    using Mask for bytes;
    using Strings for uint256;

    /// @notice **Mapping** that maps a **minted Fragment Instances** to its **Token ID + 1**.
    /// @dev The reason we map it to **token ID + 1** (instead of just the **token ID**) is because the default/uninitialized value of a Solidity mapping is 0.
    mapping(bytes => uint256) public instance2token;

    /// @notice **Mapping** that maps a **Token ID** to its corresponding **Fragment Instance**.
    mapping(uint256 => bytes) public token2instance;

    /// Fragment Instance (with Fragment Definition `definitionHash`, Edition ID `editionId` and Copy ID `copyId`) was minted
    event Minted(bytes16 definitionHash, uint64 editionId, uint64 copyId);

    /// @inheritdoc ERC721A
    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        if (!_exists(tokenId)) revert URIQueryForNonexistentToken();

        bytes memory instanceId = token2instance[tokenId];
        bytes16 definitionHash = bytes16(instanceId.mask(0, 16));
        uint64 editionId = uint64(bytes8(instanceId.mask(16, 24)));
        uint64 copyId = uint64(bytes8(instanceId.mask(24, 32)));

        bytes memory definitionHashBytes = abi.encodePacked(definitionHash);

        return
            string(
                abi.encodePacked(
                    _baseURI(),
                    "/f/",
                    definitionHashBytes.toHexString(),
                    "-",
                    uint256(editionId).toString(),
                    "-",
                    uint256(copyId).toString()
                )
            );
    }

    /// @notice Get the ERC-721 Token ID of the Fragment Instance
    function tokenIdOfInstance(bytes16 definitionHash, uint64 editionId)
        external
        view
        returns (uint256)
    {
        uint64 copyId = 1;

        bytes memory instanceId = abi.encodePacked(
            definitionHash,
            editionId,
            copyId
        );

        require(instance2token[instanceId] != 0, "No Token ID found");

        return instance2token[instanceId] - 1;
    }

    /// @notice Mint the Fragment Instance whose Fragment Definition ID is `definitionHash`, Edition ID is `editionId` and Copy ID is `copyId`
    function safeMint(
        bytes32[] calldata proof,
        bytes16 definitionHash,
        uint64 editionId
    ) external payable paysMintPrice {
        uint64 copyId = 1;

        bytes memory instanceId = abi.encodePacked(
            definitionHash,
            editionId,
            copyId
        );

        require(
            instance2token[instanceId] == 0,
            "Fragment Instance was already minted"
        );

        bytes32 leaf = keccak256(instanceId);

        require(
            MerkleProof.verify(proof, merkleRoot(), leaf),
            "Fragment Instance is not a part of the Collection"
        );

        uint256 nextTokenId = _nextTokenId(); // Note: `_nextTokenId()` thinks that Token IDs start at 0
        instance2token[instanceId] = nextTokenId + 1; // The reason we map it to **token ID + 1** (instead of just the **token ID**) is because the default/uninitialized value of a Solidity mapping is 0.
        token2instance[nextTokenId] = instanceId;
        _safeMint(msg.sender, 1);

        emit Minted(definitionHash, editionId, copyId);
    }
}
