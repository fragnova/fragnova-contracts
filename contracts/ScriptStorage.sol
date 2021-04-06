pragma solidity ^0.8.0;

contract ScriptStorage {
    mapping(uint256 => bytes) internal _immutable;
    mapping(uint256 => bytes) internal _mutable;

    function reverse(uint8[] memory input)
        private
        pure
        returns (uint8[] memory)
    {
        uint8[] memory output = new uint8[](input.length);
        for (uint32 i = 0; i < input.length; i++) {
            output[i] = input[input.length - 1 - i];
        }
        return output;
    }

    bytes constant ALPHABET =
        "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz";

    function toAlphabet(uint8[] memory indices)
        private
        pure
        returns (bytes memory)
    {
        bytes memory output = new bytes(indices.length);
        for (uint32 i = 0; i < indices.length; i++) {
            output[i] = ALPHABET[indices[i]];
        }
        return output;
    }

    function toBase58(bytes memory source) private pure returns (bytes memory) {
        if (source.length == 0) return new bytes(0);
        uint8[] memory digits = new uint8[](46);
        digits[0] = 0;
        uint8 digitlength = 1;
        for (uint32 i = 0; i < source.length; ++i) {
            uint256 carry = uint8(source[i]);
            for (uint32 j = 0; j < digitlength; ++j) {
                carry += uint256(digits[j]) * 256;
                digits[j] = uint8(carry % 58);
                carry = carry / 58;
            }

            while (carry > 0) {
                digits[digitlength] = uint8(carry % 58);
                digitlength++;
                carry = carry / 58;
            }
        }
        return toAlphabet(reverse(digits));
    }

    function getUrl(uint256 tokenId, uint256 offset)
        internal
        view
        returns (string memory)
    {
        bytes memory ipfsCid = new bytes(32);
        bytes storage data = _mutable[tokenId];
        for (uint256 i = 0; i < 32; i++) {
            ipfsCid[i] = data[i + offset]; // skip 1 byte, version number
        }
        return
            string(
                abi.encodePacked(
                    "ipfs://",
                    toBase58(
                        abi.encodePacked(uint8(0x12), uint8(0x20), ipfsCid)
                    )
                )
            );
    }
}
