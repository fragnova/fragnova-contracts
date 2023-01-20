/// SPDX-License-Identifier: BUSL-1.1
/// Copyright © 2022 Fragcolor Pte. Ltd.

pragma solidity ^0.8.13;

// We import these contracts to `@inheritdoc`
import {ERC721A} from "erc721a/contracts/ERC721A.sol";

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {NotProofRead} from "./Libraries.sol";

import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {Collection} from "./Collection.sol";

contract ProtoCollection is Collection {
    using NotProofRead for bytes;
    using Strings for uint256;

    /// @notice **Mapping** that maps a **minted Proto-Fragment** to its **Token ID + 1**.
    /// @dev The reason we map it to **token ID + 1** (instead of just the **token ID**) is because the default/uninitialized value of a Solidity mapping is 0.
    mapping(bytes32 => uint256) public proto2token;
    /// @notice **Mapping** that maps a **Token ID** to its corresponding **Proto-Fragment**.
    mapping(uint256 => bytes32) public token2proto;

    /// Proto-Fragment (whose ID is `protoHash`) was minted
    event Minted(bytes32 protoHash);

    /// @inheritdoc ERC721A
    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        if (!_exists(tokenId)) revert URIQueryForNonexistentToken();

        bytes32 protoHash = token2proto[tokenId];

        bytes memory protoHashBytes = abi.encodePacked(protoHash);

        return
            string(
                abi.encodePacked(
                    _baseURI(),
                    "/p/",
                    protoHashBytes.toHexString()
                )
            );
    }

    /// @notice Get the ERC-721 Token ID of the Proto-Fragment
    function tokenIdOfProto(bytes32 protoHash) external view returns (uint256) {
        require(proto2token[protoHash] != 0, "No Token ID found");

        return proto2token[protoHash] - 1;
    }

    /// @notice Mint the Proto-Fragment whose ID is `protoHash`
    function safeMint(bytes32[] calldata proof, bytes32 protoHash)
        external
        payable
        paysMintPrice
    {
        require(
            proto2token[protoHash] == 0,
            "Proto-Fragment was already minted"
        );

        bytes32 leaf = keccak256(abi.encodePacked(protoHash));

        require(
            MerkleProof.verify(proof, merkleRoot(), leaf),
            "Proto-Fragment is not a part of the Collection"
        );

        uint256 nextTokenId = _nextTokenId();
        proto2token[protoHash] = _nextTokenId() + 1; // The reason we map it to **token ID + 1** (instead of just the **token ID**) is because the default/uninitialized value of a Solidity mapping is 0.
        token2proto[nextTokenId] = protoHash;
        _safeMint(msg.sender, 1);

        emit Minted(protoHash);
    }
}
