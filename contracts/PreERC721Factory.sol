pragma solidity ^0.8.7;

import "./ClonesWithCallData.sol";

contract PreERC721Factory {
    event Created(address indexed newContract);

    function create(
        bytes32 name,
        bytes32 symbol,
        address implementation
    ) public {
        bytes memory ptr = new bytes(64);
        assembly {
            mstore(add(ptr, 0x20), name)
            mstore(add(ptr, 0x40), symbol)
        }
        address newContract = ClonesWithCallData.cloneWithCallDataProvision(
            implementation,
            ptr
        );
        emit Created(newContract);
    }
}
