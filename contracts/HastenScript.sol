pragma solidity ^0.7.4;

import "openzeppelin-solidity/contracts/token/ERC721/ERC721.sol";
import "./IHastenScript.sol";

contract HastenScript is IHastenScript, ERC721 {
    // mapping for scripts storage
    mapping(uint256 => bytes) private _scripts;
    mapping(uint256 => bytes) private _environments;

    constructor() ERC721("Hasten Script NFT", "HSTN") {}

    function script(uint256 scriptHash)
        public
        view
        override
        returns (bytes memory scriptBytes, bytes memory environment)
    {
        require(
            _exists(scriptHash),
            "HastenScript: script query for nonexistent token"
        );

        return (_scripts[scriptHash], _environments[scriptHash]);
    }

    function upload(
        string memory tokenURI,
        bytes memory scriptBytes
    ) public override {
        // mint a new token and upload it
        // but make scripts unique by hashing them
        // keccak256 seems the cheapest hashing function
        uint256 hash = uint256(keccak256(scriptBytes));
        _mint(msg.sender, hash);
        _scripts[hash] = scriptBytes;
        _setTokenURI(hash, tokenURI);
    }

    function uploadWithEnvironment(
        string memory tokenURI,
        bytes memory scriptBytes,
        bytes memory environment
    ) public override {
        // mint a new token and upload it
        // but make scripts unique by hashing them
        // keccak256 seems the cheapest hashing function
        uint256 hash = uint256(keccak256(scriptBytes));
        _mint(msg.sender, hash);
        _scripts[hash] = scriptBytes;
        _environments[hash] = environment;
        _setTokenURI(hash, tokenURI);
    }

    function update(uint256 scriptHash, bytes memory environment)
        public
        override
    {
        require(
            msg.sender == ownerOf(scriptHash),
            "Only the owner of the script can update its environment"
        );

        _environments[scriptHash] = environment;
    }
}
