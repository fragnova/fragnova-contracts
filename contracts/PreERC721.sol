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

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override
        returns (bool)
    {
        return
            _supportsInterface(interfaceId) ||
            super.supportsInterface(interfaceId);
    }

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
    /// @notice Returns the name of this ERC-721 Contract
    /// @dev ¿I am not sure what _getImmutableVariablesOffset does?
    function name() public pure override returns (string memory) {
        uint256 offset = _getImmutableVariablesOffset();
        bytes32 nameBytes;
        assembly {
            nameBytes := calldataload(offset)
        }
        return string(abi.encodePacked(nameBytes));
    }

    /// Overrides
    ///
    /// @notice Returns the symbol of this ERC-721 Contract
    /// @dev ¿I am not sure what _getImmutableVariablesOffset does?
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

    /// @notice Returns a JSON that represents the storefront-level metadata (for example a Collection in OpenSea) for your contract
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

    /// @notice Returns the tokenURI of the ERC-721 Token with ID `tokenId`. (Note: Every ERC-721 Contract must have this function)
    /// The tokenURI on an NFT is a unique identifier of what the token "looks" like. A URI could be an API call over HTTPS, an IPFS hash, or anything else unique. (https://www.freecodecamp.org/news/how-to-make-an-nft-and-render-on-opensea-marketplace/#:~:text=come%20into%20play.-,TokenURI,hash%2C%20or%20anything%20else%20unique.)
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

    /// @notice The de-facto Constructor of the PreER721 Smart Contract.
    ///         1. Stores the address of the Proxy of the `PreERC721Genesis` Contract
    ///         2. Calls the `genesisEvents()` function so that OpenSea and others will track/find our NFT contract
    ///         3. Sets the Royalties recipient of this contract (i.e of the `Fragment` contract) to `owner()`
    /// @param genesisState The address of the Proxy of the `PreERC721Genesis` Contract
    /// @dev The `initializer` modifier ensures this function is only called once
    function genesis(address genesisState) external onlyOwner initializer {
        _genesisState = IGenesisState(genesisState);
        _genesisState.generateEvents();
        setupRoyalties(payable(owner()), FRAGMENT_ROYALTIES_BPS);
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

    /// @notice Get the number of ERC-721 Tokens (of this contract) and the
    ///         Tokens of the `PreERC721Genesis` Contract that are held by the address `tokenOwner`
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

    /// @notice Returns the address of the owner of ERC-721 Token with ID `tokenID` in this Contract (i.e in PreERC721)
    ///         If an owner doesn't exist in this contract, it checks if it exists in the `PreERC721Genesis` contract (whose address is interface is `_genesisState`)
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
