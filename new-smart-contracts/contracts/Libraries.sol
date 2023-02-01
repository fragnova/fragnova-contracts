/// SPDX-License-Identifier: BUSL-1.1
/// Copyright © 2022 Fragcolor Pte. Ltd.

pragma solidity ^0.8.13;

library NotProofRead {
    // Source: https://ethereum.stackexchange.com/questions/126899/convert-bytes-to-hexadecimal-string-in-solidity
    function toHexString(bytes memory buffer)
        internal
        pure
        returns (string memory)
    {
        // Fixed buffer size for hexadecimal conversion
        bytes memory converted = new bytes(buffer.length * 2);

        bytes memory _base = "0123456789abcdef";

        for (uint256 i = 0; i < buffer.length; i++) {
            converted[i * 2] = _base[uint8(buffer[i]) / _base.length];
            converted[i * 2 + 1] = _base[uint8(buffer[i]) % _base.length];
        }

        return string(abi.encodePacked("0x", converted));
    }

}

library Mask {
    function mask(
        bytes memory data,
        uint256 start,
        uint256 end
    ) internal pure returns (bytes memory) {
        bytes memory output = new bytes(end - start);

        for (uint256 i = 0; i < end - start; i++) {
            output[i] = data[start + i];
        }

        return output;
    }
}