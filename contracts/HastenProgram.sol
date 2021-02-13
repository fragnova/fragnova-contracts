pragma solidity ^0.7.4;

import "openzeppelin-solidity/contracts/token/ERC721/ERC721.sol";
import "./IHastenProgram.sol";

contract HastenProgram is IHastenProgram, ERC721 {
    // mapping for programs storage
    mapping(uint256 => bytes) private _programs;
    mapping(uint256 => bytes) private _environments;

    constructor() ERC721("Hasten Program NFT", "HSTN") {}

    function program(uint256 programHash)
        public
        view
        override
        returns (bytes memory programBytes, bytes memory environment)
    {
        require(
            _exists(programHash),
            "HastenProgram: program query for nonexistent token"
        );
        return (_programs[programHash], _environments[programHash]);
    }

    function upload(
        address uploader,
        string memory tokenURI,
        bytes memory programBytes
    ) public override {
        // mint a new token and upload it
        // but make programs unique by hashing them
        // keccak256 seems the cheapest hashing function
        uint256 hash = uint256(keccak256(programBytes));
        _mint(uploader, hash);
        _programs[hash] = programBytes;
        _setTokenURI(hash, tokenURI);
    }

    function upload(
        address uploader,
        string memory tokenURI,
        bytes memory programBytes,
        bytes memory environment
    ) public override {
        // mint a new token and upload it
        // but make programs unique by hashing them
        // keccak256 seems the cheapest hashing function
        uint256 hash = uint256(keccak256(programBytes));
        _mint(uploader, hash);
        _programs[hash] = programBytes;
        _environments[hash] = environment;
        _setTokenURI(hash, tokenURI);
    }

    function update(uint256 programHash, bytes memory environment)
        public
        override
    {
        require(
            msg.sender == ownerOf(programHash),
            "Only the owner of the program can update its environment"
        );
        _environments[programHash] = environment;
    }
}
