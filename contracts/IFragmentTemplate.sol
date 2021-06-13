pragma solidity ^0.8.0;

import "openzeppelin-solidity/contracts/token/ERC721/IERC721.sol";

interface IFragmentTemplate is IERC721 {
    function getVault() external view returns (address payable);
}
