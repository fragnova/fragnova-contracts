pragma solidity ^0.8.7;

import "./ClonesWithCalldata.sol";

contract PreERC721Factory {
    event Created(address indexed newContract);

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
