pragma solidity ^0.8.7;

import "openzeppelin-solidity/contracts/token/ERC721/ERC721.sol";
import "openzeppelin-solidity/contracts/proxy/utils/Initializable.sol";
import "openzeppelin-solidity/contracts/access/Ownable.sol";

contract PreERC721 is ERC721, Initializable, Ownable {
    constructor() ERC721("", "") {}

    /// Immutable calls
    ///
    function _getImmutableVariablesOffset()
        internal
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

    /// Overrides
    ///
    function name() public pure override returns (string memory) {
        uint256 offset = _getImmutableVariablesOffset();
        bytes32 nameBytes;
        assembly {
            nameBytes := calldataload(offset)
        }
        return string(abi.encodePacked(nameBytes));
    }

    function symbol() public pure override returns (string memory) {
        uint256 offset = _getImmutableVariablesOffset();
        bytes32 symbolBytes;
        assembly {
            symbolBytes := calldataload(add(offset, 0x20))
        }
        return string(abi.encodePacked(symbolBytes));
    }

    function fragment() external pure returns (bytes32) {
        uint256 offset = _getImmutableVariablesOffset();
        bytes32 fragmentHash;
        assembly {
            fragmentHash := calldataload(add(offset, 0x40))
        }
        return fragmentHash;
    }

    function owner() public pure override returns (address) {
        uint256 offset = _getImmutableVariablesOffset();
        bytes32 ownerBytes;
        assembly {
            ownerBytes := calldataload(add(offset, 0x60))
        }
        return address(bytes20(ownerBytes));
    }

    function tokenURI(uint256 tokenId)
        public
        pure
        override
        returns (string memory)
    {
        // TODO: #2 Implement tokenURI
        // We fetch data from our Clamor nodes IPFS server mode
        // The best efficient way to do this is to use the IPFS CID in base32 format like:
        // base32 - cidv1 - raw - (blake2b-256 : 256 : 953F867F5E7AF34B031D2689EA1486420571DFAC0CD4043B173B0035E621C0DD)
        // Actual cid: bafk2bzaceckt7bt7lz5pgsyddutit2quqzbak4o7vqgnibb3c45qanpgehan2
        // TODO exactly:
        // Ignore/Don't use super.tokenURI(tokenId)
        // Append to this hardcoded prefix `0x0155a0e40220` the 32 bytes of `fragment()` call and convert to base32
        // Prepend to this string `b` to flag base32 encoding
        // Futhermore prepend to this string `https://ipfs.io/api/v0/block/get/`
        // Add a few tests to make sure the base32 encoder is solid
    }

    function generate(uint256[] memory tokens) external initializer onlyOwner {
        for (uint256 i = 0; i < tokens.length; i++) {
            address to = address(uint160(tokens[i]));
            uint256 tokenId = i + 1;
            _balances[to] += 1;
            _owners[tokenId] = to;
            emit Transfer(address(0), to, tokenId);
        }
    }
}
