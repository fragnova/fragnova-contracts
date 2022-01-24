pragma solidity ^0.8.7;

import "openzeppelin-solidity/contracts/token/ERC721/ERC721.sol";
import "openzeppelin-solidity/contracts/proxy/utils/Initializable.sol";
import "openzeppelin-solidity/contracts/access/Ownable.sol";
import "openzeppelin-solidity/contracts/utils/Strings.sol";
import "./RoyaltiesReceiver.sol";

interface IGenesisState {
    function getGenesisOwner(uint256 tokenId) external view returns (address);

    function isGenesisToken(uint256 tokenId) external view returns (bool);

    function getGenesisBalance(address owner) external view returns (uint256);

    function exclude(uint256 tokenId, address owner) external;

    function generateEvents() external;

    function getCid(uint256 tokenId) external view returns (bytes32);
}

contract PreERC721 is ERC721, Initializable, Ownable, RoyaltiesReceiver {
    using Strings for uint256;

    bytes constant GATEWAY_URL = "https://gateway.server.com/";

    mapping(uint256 => bytes32) private _cids;

    IGenesisState private _genesisState;

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

    function genesis(address genesisState) external onlyOwner initializer {
        _genesisState = IGenesisState(genesisState);
        _genesisState.generateEvents();
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override {
        // make sure to fix lazy genesis tokens transfering out of genesis owners
        address genesisOwner = _genesisState.getGenesisOwner(tokenId);
        if (genesisOwner != address(0) && from == genesisOwner) {
            // Ok we did not process this token yet
            _balances[genesisOwner] += 1;
            _owners[tokenId] = genesisOwner;
            _cids[tokenId] = _genesisState.getCid(tokenId);
            _genesisState.exclude(tokenId, genesisOwner);
        }
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function balanceOf(address tokenOwner)
        public
        view
        virtual
        override
        returns (uint256)
    {
        require(
            tokenOwner != address(0),
            "ERC721: balance query for the zero address"
        );
        uint256 balance = _balances[tokenOwner];
        balance += _genesisState.getGenesisBalance(tokenOwner);
        return balance;
    }

    function ownerOf(uint256 tokenId)
        public
        view
        virtual
        override
        returns (address)
    {
        address towner = _owners[tokenId];
        if (towner == address(0)) {
            towner = _genesisState.getGenesisOwner(tokenId);
        }
        require(
            towner != address(0),
            "ERC721: owner query for nonexistent token"
        );
        return towner;
    }

    function _exists(uint256 tokenId) internal view override returns (bool) {
        bool exists = _owners[tokenId] != address(0);
        if (!exists) {
            exists = _genesisState.getGenesisOwner(tokenId) != address(0);
        }
        return exists;
    }
}
