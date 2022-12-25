/// SPDX-License-Identifier: BUSL-1.1
/// Copyright © 2022 Fragcolor Pte. Ltd.

pragma solidity ^0.8.0;

import {ERC721A} from "erc721a/contracts/ERC721A.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {Clone} from "clones-with-immutable-args/Clone.sol";

import "hardhat/console.sol";

contract Collection is Clone, Ownable, ERC721A {
    /// @notice Price of minting an element in the collection
    uint256 public mintPrice;

    /// @inheritdoc ERC721A
    function _startTokenId() internal view override returns (uint256) {
        return 1;
    }

    constructor() ERC721A("", "") {}

    modifier paysMintPrice() {
        require(msg.value >= mintPrice, "Mint price not paid");
        _;
    }

    /// @notice Set the Mint-Price
    function setMintPrice(uint256 mintPrice_) external onlyOwner {
        mintPrice = mintPrice_;
    }

    function _getArgBytes32(uint256 argOffset) internal pure returns (bytes32 arg) {
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
}

contract ProtoCollection is Collection {
    /// @notice **Mapping** that maps a **minted Proto-Fragment** to its **Token ID**
    mapping(bytes32 => uint256) public mintedProtos;

    /// Proto-Fragment (whose ID is `protoHash`) was minted
    event Minted(bytes32 protoHash);

    /// @notice Mint the Proto-Fragment whose ID is `protoHash`
    function safeMint(bytes32[] calldata proof, bytes32 protoHash)
    external
    payable
    paysMintPrice
    {
        require(
            mintedProtos[protoHash] == 0,
            "Proto-Fragment was already minted"
        );

        bytes32 leaf = keccak256(abi.encodePacked(protoHash));

        require(
            MerkleProof.verify(proof, merkleRoot(), leaf),
            "Proto-Fragment is not a part of the Collection"
        );

//        console.log("next token id is", _startTokenId(), _nextTokenId());
        mintedProtos[protoHash] = _nextTokenId();
        _safeMint(msg.sender, 1);

        emit Minted(protoHash);
    }
}

contract InstanceCollection is Collection {
    /// @notice **Mapping** that maps a **minted Fragment Instances** to its **Token ID**
    mapping(bytes => uint256) public mintedInstances;

    /// Fragment Instance (with Fragment Definition `definitionHash`, Edition ID `editionId` and Copy ID `copyId`) was minted
    event Minted(bytes32 definitionHash, uint64 editionId, uint64 copyId);

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
            mintedInstances[instanceId] == 0,
            "Fragment Instance was already minted"
        );

        bytes32 leaf = keccak256(instanceId);

        require(
            MerkleProof.verify(proof, merkleRoot(), leaf),
            "Fragment Instance is not a part of the Collection"
        );

        mintedInstances[instanceId] = _nextTokenId();
        _safeMint(msg.sender, 1);

        emit Minted(definitionHash, editionId, copyId);
    }
}
