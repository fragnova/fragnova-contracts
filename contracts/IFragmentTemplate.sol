pragma solidity ^0.8.0;

import "openzeppelin-solidity/contracts/token/ERC721/IERC721.sol";

interface IFragmentTemplate is IERC721 {
    function dataOf(uint160 templateHash)
        external
        view
        returns (bytes memory immutableData, bytes memory mutableData);
}
