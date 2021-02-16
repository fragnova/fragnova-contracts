pragma solidity ^0.7.4;

import "openzeppelin-solidity/contracts/token/ERC721/ERC721.sol";
import "openzeppelin-solidity/contracts/utils/Counters.sol";

contract HastenScript is ERC721 {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    // mapping for scripts storage
    mapping(uint256 => uint256) private _hash2Idx;
    mapping(uint256 => bytes) private _scripts;
    mapping(uint256 => bytes) private _environments;

    constructor() ERC721("Hasten Script NFT", "HSTNsV1") {}

    function scriptFromHash(uint256 scriptHash)
        public
        view
        returns (bytes memory scriptBytes, bytes memory environment)
    {
        uint256 scriptIdx = _hash2Idx[scriptHash];
        require(
            scriptIdx != 0 && _exists(scriptIdx),
            "HastenScript: script query for nonexistent token"
        );

        return (_scripts[scriptIdx], _environments[scriptIdx]);
    }

    function scriptFromId(uint256 tokenId)
        public
        view
        returns (bytes memory scriptBytes, bytes memory environment)
    {
        require(
            _exists(tokenId),
            "HastenScript: script query for nonexistent token"
        );

        return (_scripts[tokenId], _environments[tokenId]);
    }

    function upload(string memory tokenURI, bytes memory scriptBytes) public {
        bytes memory empty = new bytes(0);
        uploadWithEnvironment(tokenURI, scriptBytes, empty);
    }

    function uploadWithEnvironment(
        string memory tokenURI,
        bytes memory scriptBytes,
        bytes memory environment
    ) public {
        // mint a new token and upload it
        // but make scripts unique by hashing them
        // keccak256 seems the cheapest hashing function
        uint256 hash = uint256(keccak256(scriptBytes));
        require(
            _hash2Idx[hash] == 0,
            "HastenScript: script hash already minted"
        );

        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();

        _mint(msg.sender, newItemId);

        _hash2Idx[hash] = newItemId;
        _scripts[newItemId] = scriptBytes;
        _environments[newItemId] = environment;
        _setTokenURI(newItemId, tokenURI);
    }

    function update(uint256 tokenId, bytes memory environment) public {
        require(
            _exists(tokenId) && msg.sender == ownerOf(tokenId),
            "Only the owner of the script can update its environment"
        );

        _environments[tokenId] = environment;
    }
}
