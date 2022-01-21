pragma solidity ^0.8.7;

import "openzeppelin-solidity/contracts/token/ERC721/ERC721.sol";
import "openzeppelin-solidity/contracts/proxy/utils/Initializable.sol";

contract PreERC721 is ERC721, Initializable {
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

    function generate(uint256[] memory tokens) external initializer {
        for (uint256 i = 0; i < tokens.length; i++) {
            address to = address(uint160(tokens[i]));
            uint256 tokenId = i + 1;
            _balances[to] += 1;
            _owners[tokenId] = to;
            emit Transfer(address(0), to, tokenId);
        }
    }
}
