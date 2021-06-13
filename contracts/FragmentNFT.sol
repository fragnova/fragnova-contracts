pragma solidity ^0.8.0;

import "openzeppelin-solidity/contracts/token/ERC721/ERC721.sol";
import "openzeppelin-solidity/contracts/token/ERC20/utils/SafeERC20.sol";
import "./Ownable.sol";

abstract contract FragmentNFT is ERC721, Ownable {
     using SafeERC20 for IERC20;

    // rewards related
    uint256 internal _reward = 1 * (10**16);
    mapping(address => uint256) internal _rewardBlocks;
    IERC20 internal _utilityToken = IERC20(address(0));
    string internal _metatataBase = "https://meta.fragcolor.xyz/";

    function setUtilityToken(address addr) public onlyOwner {
        _utilityToken = IERC20(addr);
    }

    function getUtilityToken() public view returns (address) {
        return address(_utilityToken);
    }

    function setMetadataBase(string calldata base) public onlyOwner {
        _metatataBase = base;
    }

    function recoverERC20(address tokenAddress, uint256 tokenAmount) public onlyOwner {
        require(tokenAddress != address(_utilityToken), "Cannot withdraw the staking token");
        IERC20(tokenAddress).safeTransfer(owner(), tokenAmount);
    }

    function recoverETH(uint256 amount) public onlyOwner {
        payable(owner()).transfer(amount);
    }
}
