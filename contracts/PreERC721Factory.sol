pragma solidity ^0.8.7;

import "./ClonesWithCalldata.sol";

contract PreERC721Factory {
    event Created(address indexed newContract);

    /// @notice Create a New `PreERC721` Contract. The New Contract is a Clone of an existing `PreERC721` Contract (whose address is `implementation`)
    /// @param name - Name of the new contract
    /// @param symbol - Symbol of the new contract
    /// @param fragmentHash - The hash of a Proto-Fragment
    /// @param owner - The address of the owner of the new contract
    /// @param implementation - The Address of an existing `PreERC721` Contract to Clone
    /// @param ¿How does the `fragmentHash` pass to the new `PreERC721` Contract
    function create(
        bytes32 name,
        bytes32 symbol,
        bytes32 fragmentHash,
        address owner,
        address implementation
    ) public {
        bytes32 owner32 = bytes32(bytes20(owner));
        bytes memory ptr = new bytes(128);
        assembly {
            // Store `name` is Memory Slot `ptr + 24`
            mstore(add(ptr, 0x20), name)
            mstore(add(ptr, 0x40), symbol)
            mstore(add(ptr, 0x60), fragmentHash)
            mstore(add(ptr, 0x80), owner32)
        }
        address newContract = ClonesWithCallData.cloneWithCallDataProvision(
            implementation,
            ptr
        );
        emit Created(newContract);
    }
}
