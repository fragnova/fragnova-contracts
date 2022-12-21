/// SPDX-License-Identifier: BUSL-1.1
/// Copyright © 2022 Fragcolor Pte. Ltd.

pragma solidity ^0.8.0;

import "erc721a/contracts/ERC721A.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

abstract contract FragnovaCollection is Ownable, ERC721A {
    constructor() ERC721A("", "") {}

    /// @inheritdoc ERC721A
    function _startTokenId() internal pure override returns (uint256) {
        return 1;
    }

    function _getImmutableVariablesOffset()
    private
    pure
    returns (uint256 offset)
    {
        assembly {
            offset := sub(
            calldatasize(),
            add(shr(240, calldataload(sub(calldatasize(), 2))), 2)
            )
        }
    }

    function getImmutableVariable(uint256 hexy) private pure returns (bytes32) {
        uint256 offset = _getImmutableVariablesOffset();
        bytes32 immutableVariable;
        assembly {
            immutableVariable := calldataload(add(offset, hexy))
        }
        return immutableVariable;
    }

    function merkleRoot() public pure returns (bytes32) {
        return getImmutableVariable(0x00);
    }

    function owner() public pure override returns (address) {
        return address(bytes20(getImmutableVariable(0x20)));
    }

    function name() public pure override returns (string memory) {
        return string(abi.encodePacked(getImmutableVariable(0x40)));
    }

    function symbol() public pure override returns (string memory) {
        return string(abi.encodePacked(getImmutableVariable(0x60)));
    }
}

contract ProtoFragmentCollection is FragnovaCollection {
    /// @notice **Mapping** that maps a **minted Proto-Fragment** to its **Token ID**
    mapping(bytes32 => uint256) public mintedProtos;

    /// Proto-Fragment (whose ID is `protoHash`) was minted
    event Minted(bytes32 protoHash);

    /// @notice Mint the Proto-Fragment whose ID is `protoHash`
    function safeMint(bytes32[] calldata proof, bytes32 protoHash)
    external
    payable
    {
        require(mintedProtos[protoHash] != 0, "Proto-Fragment was already minted");

        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));

        require(
            MerkleProof.verify(proof, merkleRoot(), leaf),
            "Proto-Fragment is not a part of the Collection"
        );

        mintedProtos[protoHash] = _nextTokenId();
        _safeMint(msg.sender, 1);

        emit Minted(protoHash);
    }
}

contract FragmentInstanceCollection is FragnovaCollection {
    /// @notice **Mapping** that maps a **minted Fragment Instances** to its **Token ID**
    mapping(bytes => uint256) public mintedInstances;

    /// Fragment Instance (with Fragment Definition `definitionHash`, Edition ID `editionId` and Copy ID `copyId`) was minted
    event Minted(bytes32 definitionHash, uint64 editionId, uint64 copyId);

    /// @notice Mint the Fragment Instance whose Fragment Definition ID is `definitionHash`, Edition ID is `editionId` and Copy ID is `copyId`
    function safeMint(bytes32[] calldata proof, bytes16 definitionHash, uint64 editionId, uint64 copyId)
    external
    payable
    {

        bytes memory instanceId = abi.encodePacked(definitionHash, editionId, copyId);

        require(mintedInstances[instanceId] != 0, "Fragment Instance was already minted");

        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));

        require(
            MerkleProof.verify(proof, merkleRoot(), leaf),
            "Proto-Fragment is not a part of the Collection"
        );

        mintedInstances[instanceId] = _nextTokenId();
        _safeMint(msg.sender, 1);

        emit Minted(definitionHash, editionId, copyId);
    }
}
