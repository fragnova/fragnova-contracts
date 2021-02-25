pragma solidity ^0.7.4;

import "openzeppelin-solidity/contracts/token/ERC721/ERC721.sol";
import "openzeppelin-solidity/contracts/utils/Counters.sol";

contract HastenScript is ERC721 {
    // mapping for scripts storage
    mapping(uint160 => bytes) private _scripts;
    mapping(uint160 => bytes) private _environments;

    constructor() ERC721("Hasten Script NFT", "HSTNsV0") {}

    function script(uint160 scriptHash)
        public
        view
        returns (bytes memory scriptBytes, bytes memory environment)
    {
        return (_scripts[scriptHash], _environments[scriptHash]);
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
        uint160 hash = uint160(uint256(keccak256(scriptBytes)));
        require(!_exists(hash), "HastenScript: script already minted");

        _mint(msg.sender, hash);

        _scripts[hash] = scriptBytes;
        _environments[hash] = environment;
        _setTokenURI(hash, tokenURI);
    }

    function update(uint160 scriptHash, bytes memory environment) public {
        require(
            _exists(scriptHash) && msg.sender == ownerOf(scriptHash),
            "Only the owner of the script can update its environment"
        );
        _environments[scriptHash] = environment;
    }
}
