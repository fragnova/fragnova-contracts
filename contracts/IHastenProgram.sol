pragma solidity ^0.7.4;

import "openzeppelin-solidity/contracts/token/ERC721/IERC721.sol";

abstract contract IHastenProgram is IERC721 {
    // returns a program and environment bytecode
    function program(uint256 programHash)
        public
        view
        virtual
        returns (bytes memory programBytes, bytes memory environment);

    // uploads a new program with an empty environment
    function upload(
        address uploader,
        string memory tokenURI,
        bytes memory programBytes
    ) public virtual;

    // uploads a new program with an initial environment
    function upload(
        address uploader,
        string memory tokenURI,
        bytes memory programBytes,
        bytes memory environment
    ) public virtual;

    // updates a program's environment
    // only the owner of the program can do this operation
    function update(uint256 programHash, bytes memory environment)
        public
        virtual;
}
