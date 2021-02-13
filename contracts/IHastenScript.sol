pragma solidity ^0.7.4;

import "openzeppelin-solidity/contracts/token/ERC721/IERC721.sol";

abstract contract IHastenScript is IERC721 {
    // returns a script and environment bytecode
    function script(uint256 scriptHash)
        public
        view
        virtual
        returns (bytes memory scriptBytes, bytes memory environment);

    // uploads a new script with an empty environment
    function upload(
        string memory tokenURI,
        bytes memory scriptBytes
    ) public virtual;

    // uploads a new script with an initial environment
    function uploadWithEnvironment(
        string memory tokenURI,
        bytes memory scriptBytes,
        bytes memory environment
    ) public virtual;

    // updates a script's environment
    // only the owner of the script can do this operation
    function update(uint256 scriptHash, bytes memory environment)
        public
        virtual;
}
