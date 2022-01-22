pragma solidity ^0.8.7;

import "openzeppelin-solidity/contracts/token/ERC721/ERC721.sol";
import "openzeppelin-solidity/contracts/proxy/utils/Initializable.sol";
import "openzeppelin-solidity/contracts/access/Ownable.sol";
import "openzeppelin-solidity/contracts/utils/Strings.sol";
import "./RoyaltiesReceiver.sol";

contract PreERC721 is ERC721, Initializable, Ownable, RoyaltiesReceiver {
    using Strings for uint256;

    bytes constant GATEWAY_URL = "https://gateway.server.com/";

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

    function fragment() public pure returns (bytes32) {
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

    function toAsciiString(address x) internal pure returns (string memory) {
        bytes memory s = new bytes(40);
        for (uint256 i = 0; i < 20; i++) {
            bytes1 b = bytes1(uint8(uint256(uint160(x)) / (2**(8 * (19 - i)))));
            bytes1 hi = bytes1(uint8(b) / 16);
            bytes1 lo = bytes1(uint8(b) - 16 * uint8(hi));
            s[2 * i] = char(hi);
            s[2 * i + 1] = char(lo);
        }
        return string(s);
    }

    function char(bytes1 b) internal pure returns (bytes1 c) {
        if (uint8(b) < 10) return bytes1(uint8(b) + 0x30);
        else return bytes1(uint8(b) + 0x57);
    }

    function contractURI() public pure returns (string memory) {
        bytes memory url = abi.encodePacked(
            GATEWAY_URL,
            uint256(fragment()).toHexString(),
            "/"
        );
        bytes memory data = abi.encodePacked(
            'data:application/json,{"name":"',
            name(),
            '",',
            '"description":"",',
            '"seller_fee_basis_points":',
            FRAGMENT_ROYALTIES_BPS.toString(),
            ",",
            '"fee_recipient":"0x',
            toAsciiString(owner()),
            '",',
            '"image":"',
            abi.encodePacked(url, "logo"),
            '",',
            '"external_link":"',
            abi.encodePacked(url, "page"),
            '"}'
        );

        return string(data);
    }

    function tokenURI(uint256 tokenId)
        public
        pure
        override
        returns (string memory)
    {
        bytes memory url = abi.encodePacked(
            GATEWAY_URL,
            uint256(fragment()).toHexString(),
            "/metadata/",
            tokenId.toHexString()
        );
        return string(url);
    }

    function generate(address[] memory receivers) external initializer onlyOwner {
        for (uint256 i = 0; i < receivers.length; i++) {
            address to = receivers[i];
            uint256 tokenId = i + 1;
            _balances[to] += 1;
            _owners[tokenId] = to;
            emit Transfer(address(0), to, tokenId);
        }
    }
}
