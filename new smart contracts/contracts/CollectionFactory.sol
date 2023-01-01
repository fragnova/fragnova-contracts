/// SPDX-License-Identifier: BUSL-1.1
/// Copyright © 2022 Fragcolor Pte. Ltd.

import {EnumerableSet} from "openzeppelin-solidity/contracts/utils/structs/EnumerableSet.sol";
import {ECDSA} from "openzeppelin-solidity/contracts/utils/cryptography/ECDSA.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {ProtoCollection} from "./ProtoCollection.sol";
import {InstanceCollection} from "./InstanceCollection.sol";
import {ClonesWithImmutableArgs} from "clones-with-immutable-args/ClonesWithImmutableArgs.sol";

import "hardhat/console.sol";

pragma solidity ^0.8.0;

/// @notice **Enum** represents the **different types** that a **Collection can be**.
enum CollectionType {
    ProtoFragment,
    FragmentInstance
}

contract CollectionFactory is Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;
    using ClonesWithImmutableArgs for address;

    /// @notice **Set of Public Account Addresses** that are **authorized** to **sign a detach-request message**
    EnumerableSet.AddressSet private authorities;
    /// @notice **Mapping** that maps a **Collection Type** to **a list of Collections of the Collection Type** that **exists on this Blockchain**
    mapping(CollectionType => address[]) private collections;
    /// @notice **Mapping** that maps a **Public Account Address** to its **Detach Nonce**
    mapping(address => uint256) private nonces;
    /// @notice Address of an `FragnovaCollection` contract that can be used as a template (for cloning new contracts of the same type)

    ProtoCollection public protoCollectionImplementation;
    InstanceCollection public instanceCollectionImplementation;

    /// @notice A new `FragnovaCollection` smart contract was deployed with address `newContract`
    event CollectionCreated(address indexed newContract);

    constructor(ProtoCollection protoCollectionImplementation_, InstanceCollection instanceCollectionImplementation_) {
        protoCollectionImplementation = protoCollectionImplementation_;
        instanceCollectionImplementation = instanceCollectionImplementation_;
    }

    function getAuthorities() external view returns (address[] memory) {
        return authorities.values();
    }

    /// @notice Converts a `CollectionType` enum to a string and returns the string.
    function getString(CollectionType collectionType)
    private
    pure
    returns (string memory)
    {
        if (collectionType == CollectionType.ProtoFragment) {
            return "Proto-Fragment";
        } else if (collectionType == CollectionType.FragmentInstance) {
            return "Fragment Instance";
        } else {
            revert("Systematic Error");
        }
    }

    /// @notice **Verify** that the **`signature` was signed by a Fragnova-authorized account** on a **detach-request message that
    /// requests that the collection `collectionMerkleRoot` be transferred to the caller of this function**
    modifier detachRequestSignedByAuthority(
        CollectionType collectionType,
        bytes32 collectionMerkleRoot,
        bytes calldata signature
    ) {
        uint256 nonce = nonces[msg.sender];

        address signer = ECDSA.recover(
            ECDSA.toEthSignedMessageHash(
                keccak256(
                    abi.encodePacked(
                        getString(collectionType),
                        collectionMerkleRoot,
                        block.chainid,
                        msg.sender,
                        nonce
                    )
                )
            ),
            signature
        );

        require(authorities.contains(signer), "Invalid Signature");

        _;
    }

    function addAuthority(address authority) external onlyOwner {
        authorities.add(authority);
    }
    function removeAuthority(address authority) external onlyOwner {
        authorities.remove(authority);
    }

    /// @notice Attaches a **Detached (detached from the Clamor Blockchain) Collection** to **this Blockchain**.
    /// This is done by **deploying a new `FragnovaCollection` smart contract onto this Blockchain** which will contain the **merkle root of the detached collection**
    /// and **assigning its ownership to the caller of this function**.
    /// @param signature **Signature that was signed by a Fragnova-authorized account** on a **detach-request message that requests that the collection `collectionMerkleRoot` be transferred to the caller of this function**.
    /// @param collectionType Type of the Collection
    /// @param collectionMerkleRoot Merkle Root of the Collection
    /// @param collectionName Name of the Collection
    /// @param collectionSymbol Symbol of the Collection
    function attachCollection(
        CollectionType collectionType,
        bytes32 collectionMerkleRoot,
        bytes32 collectionName,
        bytes32 collectionSymbol,
        bytes calldata signature
    )
    external
    detachRequestSignedByAuthority(
        collectionType,
        collectionMerkleRoot,
        signature
    )
    {
        nonces[msg.sender] += 1;

        bytes memory data = abi.encodePacked(collectionMerkleRoot, msg.sender, collectionName, collectionSymbol);

        address newContract;

        if (collectionType == CollectionType.ProtoFragment) {
            newContract = address(protoCollectionImplementation).clone(data);
        } else if (collectionType == CollectionType.FragmentInstance) {
            newContract = address(instanceCollectionImplementation).clone(data);
        } else {
            revert("Systematic Error");
        }

        collections[collectionType].push(newContract);

        emit CollectionCreated(newContract);
    }
}
