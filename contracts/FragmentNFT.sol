pragma solidity ^0.8.0;

import "openzeppelin-solidity/contracts/token/ERC721/ERC721.sol";
import "openzeppelin-solidity/contracts/token/ERC20/utils/SafeERC20.sol";
import "./Ownable.sol";

abstract contract FragmentNFT is ERC721, Ownable {
    // rewards related
    uint256 internal _reward = 1 * (10**16);
    mapping(address => uint256) internal _rewardBlocks;
    IERC20 internal _daoToken = IERC20(address(0));

    function setDAOToken(address addr) public onlyOwner {
        _daoToken = IERC20(addr);
    }

    function getDAOToken() public view returns (address) {
        return address(_daoToken);
    }

    string internal _metatataBase = "https://meta.fragcolor.xyz/";

    function setMetadataBase(string calldata base) public onlyOwner {
        _metatataBase = base;
    }
}
