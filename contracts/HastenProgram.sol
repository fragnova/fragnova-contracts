pragma solidity ^0.7.4;

import "openzeppelin-solidity/contracts/token/ERC721/ERC721.sol";

contract HastenProgram is ERC721 {
    // mapping for programs storage
    mapping(uint256 => bytes) private _programs;

    constructor() ERC721("Hasten Program NFT", "HSTN") {}

    function program(uint256 programHash) public view returns (bytes memory) {
        require(
            _exists(programHash),
            "HastenProgram: program query for nonexistent token"
        );
        return _programs[programHash];
    }

    function upload(address uploader, bytes memory programBytes) public {
        // mint a new token and upload it
        // but make programs unique by hashing them
        // keccak256 seems the cheapest hashing function
        uint256 hash = uint256(keccak256(programBytes));
        _mint(uploader, hash);
        _programs[hash] = programBytes;
    }
}
