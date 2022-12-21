/// SPDX-License-Identifier: BUSL-1.1
/// Copyright © 2022 Fragcolor Pte. Ltd.

import "openzeppelin-solidity/contracts/utils/structs/EnumerableSet.sol";
import "openzeppelin-solidity/contracts/utils/cryptography/ECDSA.sol";
import "clones-with-immutable-args/ClonesWithImmutableArgs.sol";

pragma solidity ^0.8.0;

/// @notice **Enum** represents the **different types** that a **Collection can be**.
enum CollectionType {
    ProtoFragment,
    FragmentInstance
}

contract FragnovaCollectionFactory {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @notice **Set of Public Account Addresses** that are **authorized** to **sign a detach-request message**
    EnumerableSet.AddressSet private authorities;
    /// @notice **Mapping** that maps a **Collection Type** to **a list of Collections of the Collection Type** that **exists on this Blockchain**
    mapping(CollectionType => address[]) private collections;
    /// @notice **Mapping** that maps a **Public Account Address** to its **Detach Nonce**
    mapping(address => uint256) private nonces;
    /// @notice Address of an `FragnovaCollection` contract that can be used as a template (for cloning new contracts of the same type)

    address private constant protoFragmentCollectionContract =
    0x1111111111111111111111111111111111111111;
    address private constant fragmentInstanceCollectionContract =
    0x2222222222222222222222222222222222222222;

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
            return "";
        }
    }

    /// @notice A new `FragnovaCollection` smart contract was deployed with address `newContract`
    event CollectionCreated(address indexed newContract);

    /// @notice **Verify** that the **`signature` was signed by a Fragnova-authorized account** on a **detach-request message that
    /// requests that the collection `collectionMerkleRoot` be transferred to the caller of this function**
    modifier detachRequestSignedByAuthority(
        bytes calldata signature,
        CollectionType collectionType,
        bytes32 collectionMerkleRoot
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

    /// @notice Attaches a **Detached (detached from the Clamor Blockchain) Collection** to **this Blockchain**.
    /// This is done by **deploying a new `FragnovaCollection` smart contract onto this Blockchain** which will contain the **merkle root of the detached collection**
    /// and **assigning its ownership to the caller of this function**.
    /// @param signature **Signature that was signed by a Fragnova-authorized account** on a **detach-request message that requests that the collection `collectionMerkleRoot` be transferred to the caller of this function**.
    /// @param collectionType Type of the Collection
    /// @param collectionMerkleRoot Merkle Root of the Collection
    /// @param collectionName Name of the Collection
    /// @param collectionSymbol Symbol of the Collection
    function attachCollection(
        bytes calldata signature,
        CollectionType collectionType,
        bytes32 collectionMerkleRoot,
        bytes32 collectionName,
        bytes32 collectionSymbol
    )
    external
    detachRequestSignedByAuthority(
        signature,
        collectionType,
        collectionMerkleRoot
    )
    {
        nonces[msg.sender] += 1;

        bytes32 collectionOwnerBytes32 = bytes32(bytes20(msg.sender));
        bytes memory encodedImmutableArgs = new bytes(128);
        assembly {
            mstore(add(encodedImmutableArgs, 0x20), collectionMerkleRoot)
            mstore(add(encodedImmutableArgs, 0x40), collectionOwnerBytes32)
            mstore(add(encodedImmutableArgs, 0x60), collectionName)
            mstore(add(encodedImmutableArgs, 0x80), collectionSymbol)
        }

        address newContract;

        if (collectionType == CollectionType.ProtoFragment) {
            newContract = ClonesWithImmutableArgs.clone(
                protoFragmentCollectionContract,
                encodedImmutableArgs
            );
        } else if (collectionType == CollectionType.FragmentInstance) {
            newContract = ClonesWithImmutableArgs.clone(
                fragmentInstanceCollectionContract,
                encodedImmutableArgs
            );
        } else {
            require(false, "Systematic Error!");
        }

        collections[collectionType].push(newContract);

        emit CollectionCreated(newContract);
    }
}
