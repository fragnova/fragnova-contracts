/// SPDX-License-Identifier: BUSL-1.1
/// Copyright © 2022 Fragcolor Pte. Ltd.

pragma solidity ^0.8.13;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {ClonesWithImmutableArgs} from "clones-with-immutable-args/ClonesWithImmutableArgs.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {ProtoCollection} from "./ProtoCollection.sol";
import {InstanceCollection} from "./InstanceCollection.sol";

/// @notice **Enum** represents the **different types** that a **Collection can be**.
enum CollectionType {
    Proto,
    Instance
}

contract CollectionFactory is Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;
    using ClonesWithImmutableArgs for address;

    /// @notice **Set of Public Account Addresses** that are **authorized** to **sign a detach-request message**
    EnumerableSet.AddressSet private authorities;
    /// @notice **Mapping** that maps a **Collection Type** to **a list of Collections of the Collection Type** that **exists on this Blockchain**
    mapping(CollectionType => address[]) private collections;
    /// @notice **Mapping** that maps a **Public Account Address** to its **Detach Nonce**
    mapping(address => uint64) private nonces;
    /// @notice Address of a `ProtoCollection` contract that can be used as a template (for cloning new contracts of the same type)
    ProtoCollection public protoCollectionImplementation;
    /// @notice Address of an `InstanceCollection` contract that can be used as a template (for cloning new contracts of the same type)
    InstanceCollection public instanceCollectionImplementation;

    /// @notice A new `FragnovaCollection` smart contract was deployed with address `newContract`
    event CollectionCreated(address indexed newContract);

    constructor(
        ProtoCollection _protoCollectionImplementation,
        InstanceCollection _instanceCollectionImplementation
    ) {
        protoCollectionImplementation = _protoCollectionImplementation;
        instanceCollectionImplementation = _instanceCollectionImplementation;
    }

    function getAuthorities() external view returns (address[] memory) {
        return authorities.values();
    }

    /// @notice Converts a `CollectionType` enum to a string and returns it.
    function getString(CollectionType collectionType)
        private
        pure
        returns (string memory)
    {
        if (collectionType == CollectionType.Proto) {
            return "Proto-Fragment";
        } else if (collectionType == CollectionType.Instance) {
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

        address signer = ECDSA.recover(
            ECDSA.toEthSignedMessageHash(
                keccak256(
                    abi.encodePacked(
                        uint8(collectionType),
                        collectionMerkleRoot,
                        block.chainid,
                        msg.sender,
                        nonces[msg.sender] + 1
                    )
                )
            ),
            signature
        );

        require(authorities.contains(signer), "Invalid Signature");

        _;
    }

    /// @notice Update the Authorities
    /// @dev Inspired from https://github.com/ProjectOpenSea/operator-filter-registry/blob/main/src/OperatorFilterRegistry.sol#L226
    function updateAuthorities(address[] calldata _authorities, bool shouldAdd)
        external
        onlyOwner
    {
        uint256 _authoritiesLength = _authorities.length;
        unchecked {
            if (!shouldAdd) {
                for (uint256 i = 0; i < _authoritiesLength; ++i) {
                    address authority = _authorities[i];
                    authorities.remove(authority);
                }
            } else {
                for (uint256 i = 0; i < _authoritiesLength; ++i) {
                    address authority = _authorities[i];
                    authorities.add(authority);
                }
            }
        }
    }

    /// @notice Attaches a **Detached (detached from the Fragnova Blockchain) Collection** to **this Blockchain**.
    /// This is done by **deploying a new `FragnovaCollection` smart contract onto this Blockchain** which will contain the **merkle root of the detached collection**
    /// and **assigning its ownership to the caller of this function**.
    ///
    /// @param collectionType Type of the Collection
    /// @param collectionMerkleRoot Merkle Root of the Collection
    /// @param collectionName Name of the Collection
    /// @param collectionSymbol Symbol of the Collection
    /// @param shouldRegisterWithOpenseaFilterRegistry ???
    /// @param signature **Signature that was signed by a Fragnova-authorized account** on a **detach-request message that requests that the collection `collectionMerkleRoot` be transferred to the caller of this function**.
    /// @dev This function has not been tested when `shouldRegisterWithOpenseaFilterRegistry` is true
    function attachCollection(
        CollectionType collectionType,
        bytes32 collectionMerkleRoot,
        bytes32 collectionName,
        bytes32 collectionSymbol,
        bool shouldRegisterWithOpenseaFilterRegistry,
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

        bytes memory data = abi.encodePacked(
            collectionMerkleRoot,
            collectionName,
            collectionSymbol
        );

        address newContract;

        if (collectionType == CollectionType.Proto) {
            newContract = address(protoCollectionImplementation).clone(data);
            ProtoCollection(newContract).initialize(
                msg.sender,
                shouldRegisterWithOpenseaFilterRegistry
            );
        } else if (collectionType == CollectionType.Instance) {
            newContract = address(instanceCollectionImplementation).clone(data);
            InstanceCollection(newContract).initialize(
                msg.sender,
                shouldRegisterWithOpenseaFilterRegistry
            );
        } else {
            revert("Systematic Error");
        }

        collections[collectionType].push(newContract);

        emit CollectionCreated(newContract);
    }
}
