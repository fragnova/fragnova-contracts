/* SPDX-License-Identifier: BUSL-1.1 */
/* Copyright © 2021 Fragcolor Pte. Ltd. */

import "./Ownable.sol";

contract UnstructuredStorage is Ownable {
    function getUint(bytes32 slot) public view returns (uint256 value) {
        assembly {
            value := sload(slot)
        }
    }

    function _setUint(bytes32 slot, uint256 value) internal {
        assembly {
            sstore(slot, value)
        }
    }

    function setUint(bytes32 slot, uint256 value) external onlyOwner {
        _setUint(slot, value);
    }

    /// @dev Gets the address stored in storage slot `slot`
    function getAddress(bytes32 slot) public view returns (address value) {
        assembly {
            value := sload(slot)
        }
    }

    function _setAddress(bytes32 slot, address value) internal {
        assembly {
            sstore(slot, value)
        }
    }

    function setAddress(bytes32 slot, address value) external onlyOwner {
        _setAddress(slot, value);
    }
}
